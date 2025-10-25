variable "oidc_client_id" {
  description = "OIDC Clien ID"
  type        = string
}

variable "oidc_client_secret" {
  description = "OIDC Client Secret"
  type        = string
}

variable "oidc_client_well_known_url" {
  description = "OIDC Well Known URL"
  type        = string
}

variable "oidc_client_scopes" {
  description = "OIDC Scopes"
  type        = set(string)
}

variable "rsa_key1_filename" {
  description = "Filename of JWKS Public Key 1"
  type        = string
}

variable "rsa_key1_id" {
  description = "ID of JWKS Public Key 1"
  type        = string
}

variable "rsa_key2_filename" {
  description = "Filename of JWKS Public Key 2"
  type        = string
}

variable "rsa_key2_id" {
  description = "ID of JWKS Public Key 2"
  type        = string
}