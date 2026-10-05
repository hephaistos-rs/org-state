# org-state
**The org's GitHub repos, declared in OpenTofu**

Infrastructure-as-code definition of the `hephaistos-rs` GitHub organization's
repositories, using [OpenTofu](https://opentofu.org/) and the
[`integrations/github`](https://registry.opentofu.org/provider/integrations/github/latest)
provider.

This is infrastructure configuration, not a software product. It exists so
the org's GitHub repositories are reproducible, reviewable, and drift-checked
through git rather than changed by hand in the GitHub UI.

## What this manages

Currently, per-repository configuration:

- name, description, homepage
- visibility (public/private/internal)
- topics
- default branch
- repository features (issues, projects, wiki, discussions)
- merge behavior (allowed merge methods, commit title/message defaults,
  branch deletion and update-branch suggestions)
- lifecycle (archived state, and what happens if a resource is ever
  destroyed)
- a `default-branch` ruleset per repository: nobody pushes to the default
  branch directly, and others' PRs need an org owner's approval (see
  "Branch protection" below)
- `org-state`'s own `apply` environment, which holds CI's write credentials
- people: org members (`members.tf`), teams and their repository access
  (`teams.tf`), and single-repository collaborators (in that repository's
  file); see "People and access" below

## What this does not manage

Out of scope for now: organization-wide settings, billing, GitHub
Apps/installations, Actions secrets and variables, and general org
governance. CI enforces this: `scripts/check-allowlist.sh` rejects any
resource type outside the ones listed above. None of these are needed for the current goal
(reproducible repository metadata), and adding them isn't planned unless a
real need shows up.

## Repository structure

```text
org-state/
├── .github/CODEOWNERS            # every change needs an org owner's review
├── .github/workflows/plan.yml   # PR checks: allowlist, fmt/validate, plan
├── .github/workflows/apply.yml  # applies main to GitHub after every merge
├── backend.tf                    # remote state in Cloudflare R2
├── encryption.tf                 # state and plan encryption (passphrase from env)
├── members.tf                    # org members and their roles
├── teams.tf                      # teams, team members, team repository access
├── scripts/check-allowlist.sh    # rejects resource types this repo doesn't manage
├── atropos.tf                    # desired state of hephaistos-rs/atropos
├── dot-github.tf                 # desired state of hephaistos-rs/.github (see below for the name)
├── kedalion.tf                   # desired state of hephaistos-rs/kedalion
├── klotho.tf                     # desired state of hephaistos-rs/klotho
├── lachesis.tf                   # desired state of hephaistos-rs/lachesis
├── lemnos.tf                     # desired state of hephaistos-rs/lemnos
├── org-state.tf                  # desired state of hephaistos-rs/org-state (this repo)
├── repo.tf.example      # copy-and-fill template for adding a new repository
├── providers.tf                  # github provider configuration (no credentials)
├── versions.tf                   # pinned OpenTofu + provider versions
└── .gitignore
```

One file per repository, all at the repository root — opening `klotho.tf`
tells you everything this project declares about `hephaistos-rs/klotho`,
nothing more. The one naming exception is `.github`, declared in
`dot-github.tf`: OpenTofu ignores files whose names start with a dot, so a
`.github.tf` would silently never load. There's no module: with a handful
of repositories, a module would be pure indirection. Add one when repeating the same block for a repository
actually gets tedious, not before.

These files are flat at the root **on purpose, not by accident**: OpenTofu's
root module only loads `.tf` files that sit directly in the working
directory — it does not recurse into subdirectories unless they're declared
as a module. An earlier version of this repository grouped these files
under a `repositories/` subdirectory, which meant OpenTofu silently loaded
zero resources from them; every `tofu plan` run reported "No changes"
because there was nothing loaded to compare, not because reality matched
the files. That was caught and fixed before anything was applied — see
"Known issues found during setup" below for the full account, including a
second, unrelated authoring mistake it also caught.

## Existing repository adoption

Every repository in the organization is managed by this repository:
`klotho`, `lachesis`, `atropos`, `lemnos`, `kedalion`, `.github`, and
`org-state`. (`edda` and `terra`, the first two repositories adopted here,
have since been deleted from GitHub and their files removed.) All of them
except `org-state` already existed on GitHub before being added here.
They were **imported**, not created: each file starts with an `import`
block that brought the existing repository into OpenTofu's state without
creating or deleting it. Every attribute value was captured from the
repositories' actual live GitHub settings (via an authenticated read), not
guessed or copied from a template — with one deliberate, explicitly
requested exception: see "Known issues found during setup."

The adoption is only considered successful because `tofu plan` reports
**no real (GitHub-visible) changes** against these files — see "Current status" below.

### Bootstrapping org-state itself

`org-state.tf` describes `hephaistos-rs/org-state` — the repository you're
reading right now. This has an unavoidable chicken-and-egg problem: OpenTofu
can't create the repository its own configuration is pushed to, because
until that repository exists there's nowhere to push the config that would
create it.

This was resolved as a one-time, explicit bootstrap step, not a Rust tool or
any other custom machinery: `hephaistos-rs/org-state` was created directly
with `gh repo create --public --description "..." --disable-wiki`, topics
were set with one follow-up `gh api` call (repo creation has no topics
flag), then this repository's initial commit (including `org-state.tf`'s
`import` block) was pushed to it. The very first `tofu plan` afterward
found one mismatch — GitHub stores/returns topics alphabetically, not in
the order they were submitted — so `org-state.tf`'s topic order was
corrected to match before considering the adoption done; every other
declared value matched real GitHub state on the first try. See "Current
status" for the now-clean result. From this point on, `org-state` is
managed exactly like the other repositories: changes go through `org-state.tf`,
reviewed the same way.

Settings `gh repo create` can't set at creation time (merge methods, commit
title/message defaults, `delete_branch_on_merge`, `allow_update_branch`)
came out as GitHub's standard defaults — the same defaults `edda` and
`terra` both carried at the time, confirming they're account-wide defaults rather
than a per-repo choice someone made. `org-state.tf` declares those same
values to match, rather than inventing different ones.

## Authentication

The provider takes no credentials from committed configuration
(`providers.tf` only sets `owner = "hephaistos-rs"`). It resolves a token in
this order (see the
[provider docs](https://registry.opentofu.org/provider/integrations/github/latest/docs)):

1. `GITHUB_TOKEN` environment variable (or the provider's `token` argument,
   which we don't set)
2. a `GITHUB_APP_*`-configured GitHub App installation
3. `gh auth token`, if the GitHub CLI is installed and logged in
4. anonymous, read-only access

For local development, having `gh` installed and authenticated
(`gh auth login`, with at least the `repo` scope so private repositories
can be read if any are added) is enough — nothing else to configure.

Locally you also need R2 credentials for the state backend (see
`backend.tf` for the three environment variables) and the state
passphrase in `TF_VAR_state_passphrase` (see `encryption.tf`).

In CI, the `fmt`/`validate` job needs no credentials at all. The others use
these secrets (none of them can be the Actions-provided
`secrets.GITHUB_TOKEN`, which only reaches this one repository):

| Secret | Where | What |
|---|---|---|
| `GH_READ_TOKEN` | repo | fine-grained PAT, all org repos: Administration **read**, Metadata read; org: Members **read** |
| `TOFU_STATE_PASSPHRASE` | repo | state and plan encryption passphrase, 16+ characters; keep a copy in a password manager |
| `R2_ENDPOINT` | repo | `https://<account-id>.r2.cloudflarestorage.com` |
| `R2_READ_ACCESS_KEY_ID`, `R2_READ_SECRET_ACCESS_KEY` | repo | R2 token, **Object Read** on the state bucket |
| `GH_APPLY_TOKEN` | `apply` environment | fine-grained PAT, all org repos: Administration **read & write**, Metadata read; org: Members **read & write** |
| `R2_WRITE_ACCESS_KEY_ID`, `R2_WRITE_SECRET_ACCESS_KEY` | `apply` environment | R2 token, **Object Read & Write** on the state bucket |

The apply token can change who has access, org owners included, so the
review on every PR is what decides access (see "People and access"). The
write credentials are environment secrets, and only `main` can deploy to the `apply` environment,
so a PR branch can't reach them even by editing a workflow.

### Branch protection

Every repository has a `default-branch` ruleset:

- nobody, org owners included, can push to the default branch directly,
  force-push it, or delete it;
- changes arrive by pull request, and need one approval (on `org-state`, a
  code owner's: see `.github/CODEOWNERS`);
- org owners can merge their own PRs without that approval (nobody can
  approve their own PR), but only through a PR, never by pushing.

On `org-state`, both CI checks must also pass, and only runs of the GitHub
Actions app count (`integration_id = 15368`). `.github` is the exception:
its ruleset only blocks force-pushes and deletion, because its
`update-projects` workflow commits the profile README straight to `main`.

### People and access

Members, teams and collaborators are managed here like everything else:
open a PR, merge, and CI applies it. Adding someone to `members.tf` sends
an org invitation; they're a member once they accept.

Admin grants go through PRs too, so review them as what they are. An org
owner (`role = "admin"` in `members.tf`) gets the org-owner bypass on
every ruleset: they can merge their own PRs without approval, and change
or remove rulesets in the GitHub UI. Nothing in this repository can limit
an org owner, so only make someone one if you'd trust them with the whole
org.

The founding owner's own membership has `prevent_destroy`, so deleting it
from `members.tf` gives a blocked plan, not a removal from the org.

## Working with this repository

```bash
tofu init             # download the provider, connect to the R2 state
tofu fmt              # format .tf files
tofu validate         # check syntax/internal consistency
tofu plan -lock=false # show what would change, without changing anything
```

Every change goes through a pull request: edit the relevant repository's
`.tf` file, open a PR, and CI posts the plan as a comment. Review that
plan; merging is approving it. On merge, `apply.yml` plans `main` again and
applies that saved plan, with the plan in the run summary. Applies queue
behind each other and never cancel, and the R2 lock file stops a local
`tofu apply` from racing one.

Don't `tofu apply` locally except to recover from a broken CI apply.

## Lifecycle safety policy

Every `github_repository` resource sets:

```hcl
archive_on_destroy = true

lifecycle {
  prevent_destroy = true
}
```

`prevent_destroy` means removing a repository's resource block (or renaming
it) produces a **blocked** plan, not a deletion — OpenTofu refuses to
proceed. This is intentionally conservative for the initial adoption: the
goal right now is proving the model works, not giving a config-file edit the
power to delete a real repository.

This is a starting policy, not a permanent one. The intended long-term
behavior is:

```text
configuration removal → destructive plan → explicit human review → intentional action
```

not silent, automatic deletion. If `prevent_destroy` is ever loosened later,
`archive_on_destroy = true` stays as a second guard — GitHub's API doesn't
support unarchiving via this provider, so archival is treated as the correct
"remove a repository from active management" action, not deletion.

## Current status

As of 2026-10-05, covering all seven managed repositories, from a fresh
checkout with no local state:

```text
tofu fmt -check   → clean (no diff)
tofu validate     → Success! The configuration is valid.
tofu plan         → 14 to import, 0 to add, 7 to change, 0 to destroy.
```

The 7 "changes" are only the client-side bookkeeping fields
`archive_on_destroy` and `ignore_vulnerability_alerts_during_read` on each
`github_repository` (see AGENTS.md); no GitHub-visible attribute differs.
Resource counts were checked directly with `tofu show -json` (14
resources: one `github_repository` and one `github_branch_default` per
repository), not just the summary line.

### State

State lives in the `hephaistos-rs-org-state` R2 bucket (`backend.tf`),
encrypted with OpenTofu's built-in AES-GCM encryption (`encryption.tf`), with
OpenTofu's S3 lock file, so CI applies remember what they created: adding a
new repository is a single PR, with no `import` block. The `import` blocks
already in the files are left in place; once a resource is in state,
they're no-ops.

Encryption is enforced: OpenTofu refuses to write state or a saved plan
unencrypted, and without the passphrase it can't read either. The
passphrase is a repo secret because PR plans read the state too, so
encryption protects the state at rest in R2, not from someone who can
already run this repo's workflows. If the passphrase is lost, the state is
gone; repositories and memberships can be re-imported by name, rulesets by
their ID (`gh api repos/hephaistos-rs/<repo>/rulesets`).

## Roadmap

Not part of this initial setup, deliberately deferred until there's a real
need:

Done since the initial setup: remote state (R2) and apply on merge to
`main`, gated by rulesets.

1. **Drift detection** — a scheduled `tofu plan -detailed-exitcode` that
   opens an issue on drift instead of applying automatically.
2. **Broader repository settings** as real needs come up (e.g. GitHub Pages
   configuration, security-and-analysis toggles) — not added speculatively.

## Known issues found during setup

Two real mistakes were made and caught while first standing this repository
up, before anything was applied to GitHub. Recorded here rather than
quietly fixed, since both are the kind of thing worth a future maintainer
knowing about:

1. **All three `.tf` files were originally under a `repositories/`
   subdirectory.** OpenTofu's root module doesn't load `.tf` files from
   subdirectories — only ones directly in the working directory. Every
   `tofu plan` run reported "No changes" the entire time, but it was
   comparing an empty configuration to nothing; it was never actually
   evaluating `edda`, `terra`, or `org-state` against live GitHub.
   Confirmed by deliberately introducing a syntax error into one of the
   files and observing `tofu validate` still report success — proof the
   file wasn't being read at all. Fixed by moving the files to the
   repository root (see "Repository structure").
2. **`terra.tf` initially declared `visibility = "public"`**, despite the
   authenticated read used to write it showing `terra` as `private` at the
   time. A real authoring mistake, unrelated to the subdirectory issue —
   it went uncaught for the same reason: the file wasn't actually being
   evaluated. Had it been applied as originally written, it would have made
   a private repository public by accident. Caught during the same
   investigation, before any apply ran.

Separately, and not a mistake: `terra` originally had no topics on GitHub,
notably missing the `hephaistos-rs` topic that `.github`'s
`update-projects` workflow uses to discover organization projects for the
profile README. The org's operator explicitly requested `terra` be made
public with that topic restored; `terra.tf` was updated accordingly and
`tofu apply` made that real, intentional change to GitHub — see git log for
the corresponding commits.

`edda` and `terra` were later deleted from GitHub, and on 2026-10-05
`edda.tf` and `terra.tf` were removed. Because the repositories no longer
exist, the provider drops them from any existing local state on refresh,
so removing their resource blocks doesn't trip `prevent_destroy`.
