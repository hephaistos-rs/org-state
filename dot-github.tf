# Desired state of hephaistos-rs/.github.
#
# Imported, not created: values were read from the live repository.
#
# The file is named dot-github.tf, not .github.tf: OpenTofu skips files
# whose names start with a dot, so .github.tf would silently never load.

resource "github_repository" "dot_github" {
  name        = ".github"
  description = "Hephaistos-rs org profile and shared files"
  visibility  = "public"

  topics = [] # not a product: no hephaistos-rs topic (see AGENTS.md "Topics convention")

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

resource "github_branch_default" "dot_github" {
  repository = github_repository.dot_github.name
  branch     = "main"
}

# No pull-request rule here: .github's update-projects workflow commits the
# profile README straight to main, which a PR requirement would block.
resource "github_repository_ruleset" "dot_github_default_branch" {
  name        = "default-branch"
  repository  = github_repository.dot_github.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true
  }
}
