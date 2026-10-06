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
  allow_auto_merge   = true # PRs merge once checks (and review) pass; see the ruleset below

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

resource "github_branch_default" "org_state" {
  repository = github_repository.org_state.name
  branch     = "main"
}

resource "github_repository_ruleset" "org_state_default_branch" {
  name        = "default-branch"
  repository  = github_repository.org_state.name
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
  # Every merge to main is applied to GitHub, so this is the gate.
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
      require_code_owner_review       = true # .github/CODEOWNERS
      dismiss_stale_reviews_on_push   = true
      require_last_push_approval      = true
    }

    required_status_checks {
      # 15368 is the GitHub Actions app: only real workflow runs can
      # satisfy these checks, not a status posted by some other token.
      required_check {
        context        = "fmt & validate"
        integration_id = 15368
      }
      required_check {
        context        = "plan (same-repo PRs only)"
        integration_id = 15368
      }
    }
  }
}

# The apply workflow runs in this environment, and its write credentials
# are environment secrets. Only main may deploy to it, so a PR branch can
# never reach those secrets, even by editing the workflow.
resource "github_repository_environment" "org_state_apply" {
  repository  = github_repository.org_state.name
  environment = "apply"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "org_state_apply_main" {
  repository     = github_repository.org_state.name
  environment    = github_repository_environment.org_state_apply.environment
  branch_pattern = "main"
}
