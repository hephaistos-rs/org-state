#!/usr/bin/env bash
# Fails if the configuration uses anything beyond what org-state manages.
#
# CI applies every merge to main, so a PR that slipped in, say, a
# github_repository_collaborator with admin rights would grant it. This runs
# before `tofu init`, so a rejected config never executes at all.
set -euo pipefail

allowed_resources='github_repository|github_branch_default|github_repository_ruleset|github_repository_environment|github_repository_environment_deployment_policy'
fail=0

if compgen -G '*.tf.json' >/dev/null || compgen -G '*_override.tf' >/dev/null || [ -e override.tf ]; then
  echo "::error::JSON and override .tf files aren't allowed; they would bypass this check."
  fail=1
fi

for f in *.tf; do
  while IFS= read -r line; do
    kind=$(awk '{print $1}' <<<"$line")
    type=$(sed -E 's/^[[:space:]]*[a-z]+[[:space:]]+"?([A-Za-z0-9_-]+)"?.*/\1/' <<<"$line")
    case "$kind" in
      resource) [[ "$type" =~ ^($allowed_resources)$ ]] && continue ;;
      provider) [ "$type" = github ] && continue ;;
    esac
    echo "::error file=$f::not allowed: $kind \"$type\""
    fail=1
  done < <(grep -E '^[[:space:]]*(resource|data|ephemeral|module|provider|provisioner|connection)[[:space:]]' "$f" || true)
done

exit "$fail"
