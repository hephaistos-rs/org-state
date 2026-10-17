# Teams, their members, and their repository access.
#
# Who is declared here also sets how many approvals PRs need: see
# reviewers.tf.

locals {
  # team key => its name, members (username => "member" or "maintainer")
  # and repositories (repository name => pull, triage, push, maintain or
  # admin).
  teams = {
    # Every repository's code owners (its .github/CODEOWNERS). Whoever
    # should review changes goes here: only their approval counts.
    maintainers = {
      name    = "Maintainers"
      members = { "Damianko135" = "maintainer" }
      repositories = {
        "atropos"   = "push"
        "kedalion"  = "push"
        "klotho"    = "push"
        "lachesis"  = "push"
        "lemnos"    = "push"
        "org-state" = "push"
      }
    }
  }

  team_members = merge([
    for team, t in local.teams : {
      for username, role in t.members : "${team}/${username}" => {
        team     = team
        username = username
        role     = role
      }
    }
  ]...)

  team_repositories = merge([
    for team, t in local.teams : {
      for repo, permission in t.repositories : "${team}/${repo}" => {
        team       = team
        repository = repo
        permission = permission
      }
    }
  ]...)
}

resource "github_team" "team" {
  for_each = local.teams

  name    = each.value.name
  privacy = "closed"
}

resource "github_team_membership" "team" {
  for_each = local.team_members

  team_id  = github_team.team[each.value.team].id
  username = each.value.username
  role     = each.value.role
}

resource "github_team_repository" "team" {
  for_each = local.team_repositories

  team_id    = github_team.team[each.value.team].id
  repository = each.value.repository
  permission = each.value.permission
}
