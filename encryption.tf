# State and plan files are encrypted with OpenTofu's built-in encryption,
# so the R2 bucket (and any saved plan) holds only ciphertext. enforced
# means OpenTofu refuses to write either one unencrypted.
#
# The passphrase is never committed: set TF_VAR_state_passphrase (CI reads
# it from the TOFU_STATE_PASSPHRASE secret). Lose it and the state can't be
# read, so keep a copy in a password manager.

variable "state_passphrase" {
  type        = string
  sensitive   = true
  description = "Passphrase for state and plan encryption (at least 16 characters)."
}

terraform {
  encryption {
    key_provider "pbkdf2" "main" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "main" {
      keys = key_provider.pbkdf2.main
    }

    state {
      method   = method.aes_gcm.main
      enforced = true
    }

    plan {
      method   = method.aes_gcm.main
      enforced = true
    }
  }
}
