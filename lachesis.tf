# Desired state of hephaistos-rs/lachesis.
#
# Imported, not created: values were read from the live repository.

import {
  to = github_repository.lachesis
  id = "lachesis"
}

resource "github_repository" "lachesis" {
  name        = "lachesis"
  description = "Self-hosted CI, measuring each build stage"
  visibility  = "public"

  topics = ["hephaistos-rs"]

  has_issues      = true
  has_projects    = true
  has_wiki        = true
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
  archive_on_destroy = true # if this resource is ever destroyed, archive rather than delete

  lifecycle {
    prevent_destroy = true # see README.md "Lifecycle safety policy" before removing
  }
}

import {
  to = github_branch_default.lachesis
  id = "lachesis"
}

resource "github_branch_default" "lachesis" {
  repository = github_repository.lachesis.name
  branch     = "main"
}
