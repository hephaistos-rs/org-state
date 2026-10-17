# Organization members and single-repository collaborators. Teams go in
# teams.tf.
#
# Adding someone here invites them; they join once they accept. Role
# "admin" makes them an org owner: they can approve PRs on every
# repository, and can change or remove rulesets in the GitHub UI (see
# README.md "People and access"), so review those PRs with that in mind.
#
# Who is declared here also sets how many approvals PRs need: see
# reviewers.tf.

locals {
  # username => "member" or "admin". The founding owner is declared on its
  # own below, so it can keep prevent_destroy.
  members = {
    # "<username>" = "member"
  }

  # repository name => { username => permission }. Permission is pull,
  # triage, push, maintain or admin.
  collaborators = {
    # "<repo-name>" = { "<username>" = "push" }
  }
}

resource "github_membership" "damianko135" {
  username = "Damianko135"
  role     = "admin"

  lifecycle {
    prevent_destroy = true # never let a config edit remove the org's owner
  }
}

resource "github_membership" "member" {
  for_each = local.members

  username = each.key
  role     = each.value
}

resource "github_repository_collaborator" "collaborator" {
  for_each = merge([
    for repo, people in local.collaborators : {
      for username, permission in people : "${repo}/${username}" => {
        repository = repo
        username   = username
        permission = permission
      }
    }
  ]...)

  repository = each.value.repository
  username   = each.value.username
  permission = each.value.permission
}
