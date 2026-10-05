# Teams, their members, and their repository access. None exist yet.
#
#   resource "github_team" "<team>" {
#     name    = "<Team Name>"
#     privacy = "closed"
#   }
#
#   resource "github_team_membership" "<team>_<username>" {
#     team_id  = github_team.<team>.id
#     username = "<username>"
#     role     = "member" # or "maintainer"
#   }
#
#   resource "github_team_repository" "<team>_<repo>" {
#     team_id    = github_team.<team>.id
#     repository = github_repository.<repo>.name
#     permission = "push" # pull, triage, push, maintain or admin
#   }
