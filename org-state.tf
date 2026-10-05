# Desired state of hephaistos-rs/org-state — this repository.
#
# OpenTofu can't create the repository its own config lives in, so unlike
# the other repositories this one was created directly via `gh repo create` and then
# imported here — see README.md "Bootstrapping org-state itself".
#
# Merge-method settings (allow_merge_commit, commit title/message defaults,
# delete_branch_on_merge, allow_update_branch) match GitHub's/the org's
# standard defaults, same as the other repositories, rather than inventing
# different values.
#
# Topics deliberately do NOT include `hephaistos-rs`: that topic drives
# .github's update-projects workflow, which curates the org profile's
# "Projects" showcase of software products. org-state is infrastructure
# configuration, not a product.

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
