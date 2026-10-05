# AGENTS.md

Guidance for AI agents (and anyone else) making changes in this repository.
Read `README.md` first for what this repo is and does — this file is about
*how* to work in it safely.

This repository declares the desired state of the `hephaistos-rs` GitHub
organization's repositories using OpenTofu. Every change here can mutate
real, public infrastructure other people depend on. Treat it accordingly.

## Non-negotiable rules

1. **Never run `tofu apply` without showing the plan output first and
   getting it reviewed.** A clean plan you generated yourself is not a
   substitute for review — paste it, don't summarize it.
2. **Never guess a value.** Before writing or editing any attribute in a
   `.tf` file, read the repository's actual current setting:
   ```bash
   gh api repos/hephaistos-rs/<repo> --jq '{visibility, topics, description, ...}'
   ```
   If you can't verify a value, say so — don't fill it in with a plausible
   default.
3. **State is local-only and must never be committed.** `.gitignore`
   already covers `*.tfstate`, `*.tfstate.*`, and `*.plan`/`*.tfplan`. If a
   git status shows one of these staged, stop and figure out why before
   committing.
4. **No credentials in committed files.** Not in `.tf`, not in `.tfvars`,
   not in workflow YAML, not in comments. Authentication comes from the
   environment (`GITHUB_TOKEN`) or an already-authenticated `gh` CLI —
   never hardcoded.
5. **This repo never touches other repos' working trees.** Don't edit files
   in other repositories' own clones from here — this repo only describes
   their GitHub *settings*, never their source code.

## Structure: flat `.tf` files at the root, no subdirectories

Every repository gets one file at the repo root: `klotho.tf`, `lemnos.tf`,
`org-state.tf`, and so on. The exception is `.github`, declared in
`dot-github.tf`: OpenTofu ignores files whose names start with a dot. **Do not move these into a subdirectory** (e.g.
`repositories/`), even for organization — OpenTofu's root module only loads
`.tf` files that sit directly in the working directory. It does not
recurse into subdirectories unless one is declared as a module with a
`module` block, and this repo deliberately has no modules (see README.md).

A subdirectory of loose `.tf` files is silently ignored: no error, no
warning — `tofu plan` will just report "No changes" forever, because
there's nothing loaded to compare against reality. This exact mistake
happened once already during initial setup and went undetected until a
deliberate syntax-error test proved the files weren't being read. If you're
ever unsure whether OpenTofu is really seeing a resource, don't trust "No
changes" alone — check `tofu show -json <planfile>` and confirm the
resource actually appears under `configuration.root_module.resources`.

Do not introduce a module for convenience or "tidiness." Add one only when
the number of repositories makes the repeated resource blocks genuinely
tedious to maintain — not before.

## The standard change workflow

For any edit to a `.tf` file:

```bash
tofu fmt -recursive       # formatting only, no semantic effect
tofu validate              # syntax + internal consistency
tofu plan                  # compare declared config against live GitHub
```

Read the full plan output, not just the summary line. Two kinds of "change"
show up and they mean very different things:

- **Real GitHub-visible changes** (e.g. `visibility`, `topics`,
  `description`) — these are actual API mutations. Confirm they're
  intentional before applying.
- **Client-side-only bookkeeping fields** (`archive_on_destroy`,
  `ignore_vulnerability_alerts_during_read`) — these have no corresponding
  GitHub API field and never cause a live mutation; they only update what
  OpenTofu itself remembers. Safe to apply on sight, but still worth
  knowing which is which rather than assuming.

Only apply a plan you generated and reviewed in the same sitting
(`tofu apply <planfile>` against a saved plan, not a fresh unreviewed
`tofu apply`), so what gets applied is exactly what was reviewed.

## Adding a new repository

Copy `repo.tf.example` to `<repo-name>.tf` and follow the numbered
steps in its header comment — it covers both adopting an existing repository
and creating a brand-new one, and already carries the shared defaults
(merge-method settings, lifecycle guards) that the existing
`.tf` files all agree on. Its `.tf.example` extension is deliberate: it
keeps OpenTofu from ever loading it as live config (see "Structure" above).

## Adopting a repository that already exists

Use an `import` block, never create a duplicate resource:

```hcl
import {
  to = github_repository.example
  id = "example"
}
```

Then write the resource block to match the repository's **actual** current
settings (verified per rule 2 above), not a clean-slate template. The bar
for a successful adoption is `tofu plan` reporting no real (GitHub-visible)
changes — if it doesn't, fix the `.tf` file to match GitHub, not the other
way around. Don't use an adoption commit as an opportunity to also
"improve" or redesign the repository's settings; that's a separate,
deliberate follow-up change.

## Lifecycle safety

Every `github_repository` resource carries:

```hcl
archive_on_destroy = true

lifecycle {
  prevent_destroy = true
}
```

Keep both on every resource unless a human explicitly asks you to remove
one, with a reason. Don't add a repository resource without them.

## Topics convention

The `hephaistos-rs` topic is load-bearing: `.github`'s `update-projects`
workflow uses it to find repositories for the org profile's public
"Projects" showcase. Software products should carry it. Infrastructure
repositories describing the org itself — like this one — deliberately do
not, since they aren't products. When adding a new repository, decide
which category it's in rather than copying topics from the nearest example.

## Out of scope

Don't add configuration for: teams, org-wide permissions, branch protection
rules/rulesets, GitHub Apps/installations, billing, or general org
governance. This repo manages repository-level metadata only. If a real
need for one of these comes up, that's a decision for a human to make
explicitly — not something to add speculatively while working on something
else.

## Also out of scope, permanently, per project philosophy

Do not introduce a custom Rust tool, a custom state backend, or any
alternative to plain OpenTofu + the `integrations/github` provider for this
job. This is infrastructure configuration, not a software product — see
README.md.
