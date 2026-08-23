# Desired state of hephaistos-rs/edda.
#
# edda already exists; it's imported here, not created, so these values
# describe its actual current settings rather than a template. If `tofu
# plan` ever shows a diff against this file, fix the file to match GitHub —
# not the other way around.

import {
  to = github_repository.edda
  id = "edda"
}

resource "github_repository" "edda" {
  name        = "edda"
  description = "Edda, the story behind your code."
  visibility  = "public"

  topics = ["git", "hephaistos-rs", "hosting"]

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
  to = github_branch_default.edda
  id = "edda"
}

resource "github_branch_default" "edda" {
  repository = github_repository.edda.name
  branch     = "main"
}
