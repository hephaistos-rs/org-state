# Desired state of hephaistos-rs/terra.
#
# terra already exists; it's imported here, not created. It's public and
# carries the `hephaistos-rs` topic so .github's update-projects workflow
# picks it up for the org profile's project showcase, same as edda.

import {
  to = github_repository.terra
  id = "terra"
}

resource "github_repository" "terra" {
  name        = "terra"
  description = "Terra, let your software take root"
  visibility  = "public"

  topics = ["hephaistos-rs"]

  has_issues      = true
  has_projects    = true
  has_wiki        = false
  has_discussions = false

  allow_forking               = true # public repos are always forkable; matches edda's convention
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
  archive_on_destroy = true # if this resource is ever destroyed, archive rather than delete

  lifecycle {
    prevent_destroy = true # see README.md "Lifecycle safety policy" before removing
  }
}

import {
  to = github_branch_default.terra
  id = "terra"
}

resource "github_branch_default" "terra" {
  repository = github_repository.terra.name
  branch     = "main"
}
