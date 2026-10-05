# State lives in a Cloudflare R2 bucket (S3-compatible), so CI applies
# remember what they created. Nothing secret is committed here:
#
#   AWS_ENDPOINT_URL_S3    https://<account-id>.r2.cloudflarestorage.com
#   AWS_ACCESS_KEY_ID      R2 API token access key
#   AWS_SECRET_ACCESS_KEY  R2 API token secret
#
# PR plans use a read-only R2 token with -lock=false; only the apply job
# holds the read-write token. use_lockfile stops two applies from racing.

terraform {
  backend "s3" {
    bucket       = "hephaistos-tofu-state"
    key          = "org-state.tfstate"
    region       = "auto"
    use_lockfile = true

    # R2 is not AWS: skip the AWS-only checks and use path-style URLs.
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
