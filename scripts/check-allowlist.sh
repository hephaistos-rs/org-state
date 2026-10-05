#!/usr/bin/env bash
# Fails if the configuration uses anything beyond what org-state manages.
#
# CI applies every merge to main with a token that can change repository
# settings and org membership. This keeps what a merged PR can do to the
# resources this repo is meant to manage: no other resource types (Actions
# secrets, org settings, ...), no data sources, no other providers, no
# modules. Who gets access is decided by review, not by this script. Two modes:
#
#   check-allowlist.sh            scan the source; runs before `tofu init`,
#                                 so a rejected config never executes
#   check-allowlist.sh PLANFILE   check the saved plan's resource types and
#                                 providers; runs before `tofu apply`, and
#                                 doesn't depend on parsing HCL text
set -euo pipefail
shopt -s nullglob

allowed_resources='github_membership|github_team|github_team_membership|github_team_repository|github_repository_collaborator|github_repository|github_branch_default|github_repository_ruleset|github_repository_environment|github_repository_environment_deployment_policy'

if [ $# -eq 1 ]; then
  json=$(tofu show -json "$1")
  bad=$(jq -r --arg re "^($allowed_resources)$" '
    [.resource_changes[]? | select(.mode != "managed" or (.type | test($re) | not)) | "\(.mode) \(.type)"]
    + [.configuration.provider_config // {} | keys[] | select(. != "github") | "provider \(.)"]
    + [.configuration.root_module.module_calls // {} | keys[] | "module \(.)"]
    | unique[]' <<<"$json")
  if [ -n "$bad" ]; then
    while IFS= read -r line; do echo "::error::plan uses something not allowed: $line"; done <<<"$bad"
    exit 1
  fi
  exit 0
fi

fail=0

# Prints "<keyword> <first label>" for a block header line.
header() {
  sed -E 's/^[[:space:]]*([a-z_]+)[[:space:]]*"?([A-Za-z0-9_-]*)"?.*/\1 \2/' <<<"$1"
}

# OpenTofu loads *.tf, *.tofu and their .json forms, plus override files.
# Only plain .tf and .tofu are scanned below; anything else is refused.
odd=()
for f in *.tf.json *.tofu.json *_override.tf *_override.tofu override.tf override.tofu; do
  if [ -e "$f" ]; then odd+=("$f"); fi
done
if [ ${#odd[@]} -gt 0 ]; then
  echo "::error::JSON and override files aren't allowed; they would bypass this check: ${odd[*]}"
  fail=1
fi

for f in *.tf *.tofu; do
  while IFS= read -r line; do
    read -r kind type <<<"$(header "$line")"
    case "$kind" in
      resource) [[ "$type" =~ ^($allowed_resources)$ ]] && continue ;;
      provider) [ "$type" = github ] && continue ;;
    esac
    echo "::error file=$f::not allowed: $kind \"$type\""
    fail=1
  done < <(grep -E '^[[:space:]]*(resource|data|ephemeral|module|provider|provisioner|connection)([[:space:]]|"|\{|$)' "$f" || true)

  # State encryption: only the passphrase key provider and AES-GCM. Others,
  # such as the `external` key provider, run commands with CI's secrets.
  while IFS= read -r line; do
    read -r kind type <<<"$(header "$line")"
    case "$kind:$type" in
      key_provider:pbkdf2 | method:aes_gcm) continue ;;
    esac
    echo "::error file=$f::not allowed: $kind \"$type\""
    fail=1
  done < <(grep -E '^[[:space:]]*(key_provider|method)[[:space:]]*"' "$f" || true)
done

exit "$fail"
