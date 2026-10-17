# How many approvals a PR needs, by repository, worked out from the people
# in members.tf and teams.tf.
#
# GitHub only counts approvals from people with write access, and the
# org's base permission is read (an org setting this repo doesn't manage),
# so plain members' approvals don't count. Owners' do (they're admin on
# every repository), and so do those of anyone granted push or more on a
# repository, directly or through a team.
#
# Nobody can approve their own PR. So while one person is the only
# possible reviewer, PRs need no approval, and once someone else could
# approve, they need one. No ruleset has a bypass: nobody has to skip a
# rule to merge, and an approval that's required can't be skipped.

locals {
  owners = setunion(
    [github_membership.damianko135.username],
    [for username, role in local.members : username if role == "admin"],
  )

  # repository name => people granted push or more on it.
  writers = {
    for grant in concat(
      flatten([
        for repo, people in local.collaborators : [
          for username, permission in people : { repository = repo, username = username, permission = permission }
        ]
      ]),
      flatten([
        for t in values(local.teams) : [
          for repo, permission in t.repositories : [
            for username in keys(t.members) : { repository = repo, username = username, permission = permission }
          ]
        ]
      ]),
    ) : grant.repository => grant.username... if contains(["push", "maintain", "admin"], grant.permission)
  }

  # repository name => approvals required. A repository with no grants of
  # its own has only the owners: use local.owner_reviews for it.
  reviews = {
    for repo, people in local.writers : repo => length(setunion(local.owners, people)) > 1 ? 1 : 0
  }
  owner_reviews = length(local.owners) > 1 ? 1 : 0
}
