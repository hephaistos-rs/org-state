# Desired state of hephaistos-rs/kedalion.
#
# Imported, not created: values were read from the live repository.

resource "github_repository" "kedalion" {
  name        = "kedalion"
  description = "Hyper-V host agent that guides Lemnos"
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

resource "github_branch_default" "kedalion" {
  repository = github_repository.kedalion.name
  branch     = "main"
}

resource "github_repository_ruleset" "kedalion_default_branch" {
  name        = "default-branch"
  repository  = github_repository.kedalion.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Org owners may merge a PR without an approval (nobody can approve their
  # own PR), but nobody, owners included, can push to the branch directly.
  bypass_actors {
    actor_type  = "OrganizationAdmin"
    actor_id    = 1
    bypass_mode = "pull_request"
  }

  rules {
    deletion         = true
    non_fast_forward = true
    pull_request {
      required_approving_review_count = 1
      require_code_owner_review       = false
      dismiss_stale_reviews_on_push   = true
      require_last_push_approval      = true
    }
  }
}
