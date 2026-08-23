# Desired state of hephaistos-rs/terra.
#
# terra already existed on GitHub before this repository was created. The
# import block below brought it under OpenTofu management without creating,
# deleting, or modifying it — every value below was captured from terra's
# live GitHub settings (via an authenticated `gh api` read) on 2026-08-23,
# not guessed or copied from a template. `tofu plan` must show no changes
# against this file; if it doesn't, fix this file to match GitHub, not the
# other way around.
#
# NOTE: terra currently has no topics — notably it is missing the
# `hephaistos-rs` topic that .github's update-projects workflow uses to
# discover org projects for the profile README (see .github/.github/workflows
# /update-projects.yml). topics = [] below matches terra's actual current
# state; this is intentionally NOT "fixed" here, because doing so would make
# this adoption commit change real GitHub state instead of just describing
# it. Adding the topic is a good candidate for a small, separate, deliberate
# follow-up PR once this baseline is merged.

import {
  to = github_repository.terra
  id = "terra"
}

resource "github_repository" "terra" {
  name        = "terra"
  description = "Terra, let your software take root"
  visibility  = "public"

  topics = [] # see NOTE above — does not currently carry the hephaistos-rs topic

  has_issues      = true
  has_projects    = true
  has_wiki        = false
  has_discussions = false

  allow_forking               = false
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
