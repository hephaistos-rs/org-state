# org-state

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

## What this does not manage

Out of scope for now: organization-wide permissions, team membership,
billing, GitHub Apps/installations, branch protection rules/rulesets, and
general org governance. None of these are needed for the current goal
(reproducible repository metadata), and adding them isn't planned unless a
real need shows up.

## Repository structure

```text
org-state/
├── .github/workflows/plan.yml   # fmt/validate/plan CI (see below) — no apply yet
├── repositories/
│   ├── edda.tf                   # desired state of hephaistos-rs/edda
│   ├── terra.tf                  # desired state of hephaistos-rs/terra
│   └── org-state.tf              # desired state of hephaistos-rs/org-state (this repo)
├── providers.tf                  # github provider configuration (no credentials)
├── versions.tf                   # pinned OpenTofu + provider versions
└── .gitignore
```

One file per repository under `repositories/` — opening `edda.tf` tells you
everything this project declares about `hephaistos-rs/edda`, nothing more.
There's no module: with two repositories, a module would be pure indirection.
Add one when repeating the same block for a third or fourth repository
actually gets tedious, not before.

## Existing repository adoption

`edda` and `terra` already existed on GitHub before this repository did.
They were **imported**, not created: each `repositories/*.tf` file starts
with an `import` block that brought the existing repository into OpenTofu's
state without creating, deleting, or modifying it. Every attribute value in
those files was captured from the repositories' actual live GitHub settings
(via an authenticated read), not guessed or copied from a template.

The adoption is only considered successful because `tofu plan` reports
**no changes** against both files — see "Current status" below.

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
managed exactly like `edda` and `terra`: changes go through `org-state.tf`,
reviewed the same way.

Settings `gh repo create` can't set at creation time (merge methods, commit
title/message defaults, `delete_branch_on_merge`, `allow_update_branch`)
came out as GitHub's standard defaults — the same defaults `edda` and
`terra` both already carry, confirming they're account-wide defaults rather
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
(`gh auth login`, needs at least the `repo` scope to read `terra`, which is
private) is enough — nothing else to configure.

In CI, the `fmt`/`validate` job needs no credentials at all. The `plan` job
needs a maintainer to add a repo secret named `GH_READ_TOKEN` — a
fine-grained PAT or GitHub App installation token scoped to read the org's
repositories — before it can produce real plan output. See the comment in
`.github/workflows/plan.yml` for why this is a separate secret and not the
Actions-provided `secrets.GITHUB_TOKEN`.

### What CI can and can't do with local-only state

CI's `plan` job runs in a fresh runner every time, with no state file of its
own and no access to whatever state file happens to be on a maintainer's
laptop — state is never uploaded to, or read from, GitHub Actions. This
still produces a **real, meaningful plan**: every resource here has a
stable, human-chosen import ID (the repository name), so each `import`
block can be re-resolved against live GitHub on every run, with no state to
carry over. CI's plan is therefore always a comparison of `repositories/*.tf`
against actual current GitHub — exactly as trustworthy as a local plan,
just computed independently each time rather than reused.

What this arrangement genuinely can't do — the actual limitation, not just
"no state file" — is provide locking or any cross-run coordination: nothing
stops two `tofu apply` runs (from two laptops, or a laptop and a future CI
apply job) from racing. That's fine while there's a single operator; it's
the reason a shared backend becomes necessary once collaboration starts,
not before. There is deliberately no automated `apply` job yet, and none of
this should be read as CI having, or needing, "the same state" a human
happens to have locally — that assumption doesn't hold here, by design.

## Working with this repository

```bash
tofu init      # download the provider
tofu fmt       # format .tf files
tofu validate  # check syntax/internal consistency
tofu plan      # show what would change, without changing anything
tofu apply     # apply an approved plan
```

Changes should normally go through a pull request: open a PR editing the
relevant `repositories/*.tf` file, let CI post the plan, get it reviewed,
then merge. There is currently no automated `apply` step (see "Roadmap")
— applying a change is a manual, deliberate action by whoever is maintaining
this repository, run locally with `tofu apply` after reviewing the plan.

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

As of 2026-08-23, covering all three managed repositories (`edda`, `terra`,
`org-state`):

```text
tofu fmt -check   → clean (no diff)
tofu validate     → Success! The configuration is valid.
tofu plan         → No changes. Your infrastructure matches the configuration.
```

### State

OpenTofu state is currently stored **locally**, as a temporary bootstrap
arrangement — there is one operator, so there is nothing to coordinate. The
state file is intentionally excluded from version control (`.gitignore`
covers `*.tfstate` and `*.tfstate.*`) and is never pushed to GitHub. A
shared remote backend will be introduced when collaborative operation
actually requires it — see "Roadmap." Until then, every `tofu plan`/`tofu
apply` run re-imports `edda`, `terra`, and `org-state` from live GitHub if
no local state file is present, which is expected and fine (see "What CI
can and can't do with local-only state" above).

## Roadmap

Not part of this initial setup, deliberately deferred until there's a real
need:

1. **Shared/remote state** — once more than one person operates this repo,
   introduce a backend with locking so concurrent `apply` runs can't race.
   Which backend is a decision for that point, not this one.
2. **Controlled apply** — a CI job that applies an approved plan on merge to
   `main`, gated by required reviewers.
3. **Drift detection** — a scheduled `tofu plan -detailed-exitcode` that
   opens an issue on drift instead of applying automatically.
4. **Broader repository settings** as real needs come up (e.g. GitHub Pages
   configuration, security-and-analysis toggles) — not added speculatively.

## Known gap

`terra` currently has no topics on GitHub — notably, it's missing the
`hephaistos-rs` topic that `.github`'s `update-projects` workflow uses to
discover organization projects for the profile README. `repositories/terra.tf`
declares `topics = []` to match terra's actual current state rather than
silently "fixing" this as part of the adoption commit (this repo's job right
now is describing reality, not redesigning it). Adding the topic is a good
candidate for a small, separate, deliberate follow-up PR.
