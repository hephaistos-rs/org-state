# Desired state of hephaistos-rs/org-state — this repository.
#
# Bootstrap note: OpenTofu cannot create the repository that its own
# configuration lives in (nothing exists yet for it to push config to). So
# unlike edda.tf/terra.tf, this repository was NOT imported after being
# created out-of-band by a human — it was created directly via `gh repo
# create` (plus one `gh api` call for topics, which `repo create` can't set),
# using values chosen to match this file, then imported here. The one thing
# that didn't match on the first try was topic order — GitHub stores/returns
# topics alphabetically regardless of submission order — corrected below
# before treating the adoption as done. Every value below is real, either
# passed at creation time or read back from the live repository afterward —
# none of it is guessed. See README.md "Bootstrapping org-state itself".
#
# Settings not controllable via `gh repo create` (merge methods, commit
# title/message defaults, delete_branch_on_merge, allow_update_branch) take
# GitHub's/the org's standard defaults — the same defaults edda and terra
# both already have, confirming these are account-wide defaults rather than
# a per-repo choice, so they're declared here to match that established
# convention rather than invented.
#
# Topics deliberately do NOT include `hephaistos-rs`: that topic drives
# .github's update-projects workflow, which curates the org profile's public
# "Projects" showcase of actual software products. org-state is
# infrastructure configuration, not a product, so including it there would
# misrepresent it.

import {
  to = github_repository.org_state
  id = "org-state"
}

resource "github_repository" "org_state" {
  name        = "org-state"
  description = "Infrastructure as code for the hephaistos-rs GitHub organization's repositories (OpenTofu)."
  visibility  = "public"

  topics = ["github", "infrastructure-as-code", "opentofu"] # GitHub returns/stores topics alphabetically

  has_issues      = true
  has_projects    = true
  has_wiki        = false # config lives in code + README, not a wiki
  has_discussions = false

  allow_forking               = true
  web_commit_signoff_required = false

  allow_merge_commit = true
  allow_squash_merge = true
  allow_rebase_merge = true
  allow_auto_merge   = false

  squash_merge_commit_title   = "COMMIT_OR_PR_TITLE"
  squash_merge_commit_message = "COMMIT_MESSAGES"
  merge_commit_title          = "MERGE_MESSAGE"
  merge_commit_message        = "PR_TITLE"

  delete_branch_on_merge = false
  allow_update_branch    = false

  archived           = false
  archive_on_destroy = true

  lifecycle {
    prevent_destroy = true # see README.md "Lifecycle safety policy"
  }
}

import {
  to = github_branch_default.org_state
  id = "org-state"
}

resource "github_branch_default" "org_state" {
  repository = github_repository.org_state.name
  branch     = "main"
}
