# Organization members. Teams go in teams.tf, single-repository
# collaborators in that repository's own file.
#
# Adding someone here invites them; they join once they accept. Role
# "admin" makes them an org owner, which includes the org-owner bypass on
# every ruleset (see README.md "People and access"), so review those PRs
# with that in mind.
#
#   resource "github_membership" "<username>" {
#     username = "<username>"
#     role     = "member"
#   }

import {
  to = github_membership.damianko135
  id = "hephaistos-rs:Damianko135"
}

resource "github_membership" "damianko135" {
  username = "Damianko135"
  role     = "admin"

  lifecycle {
    prevent_destroy = true # never let a config edit remove the org's owner
  }
}
