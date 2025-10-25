terraform {
  required_providers {
    vcfa = {
      source  = "vmware/vcfa"
      version = "~> 1.0.0"
    }
  }
}

# Configure the VMware Cloud Foundation Automation Provider
provider "vcfa" {
  user                 = var.username
  password             = var.password
  auth_type            = "integrated"
  org                  = var.org
  url                  = var.url
  allow_unverified_ssl = true
  logging              = true
  logging_file         = "vcfa.log"
}

# Fetch VCF Org
data "vcfa_org" "org" {
  name = var.org
}

# Create OIDC IdP Connection
resource "vcfa_org_oidc" "oidc" {
  org_id                      = data.vcfa_org.org.id
  enabled                     = true
  prefer_id_token             = false
  client_id                   = var.oidc_client_id
  client_secret               = var.oidc_client_secret
  max_clock_skew_seconds      = 60
  wellknown_endpoint          = var.oidc_client_well_known_url
  scopes                      = var.oidc_client_scopes
  claims_mapping {
    email      = "email"
    subject    = "email"
    last_name  = "family_name"
    first_name = "given_name"
    full_name  = "name"
  }
  ui_button_label = "${var.org} SSO"
  /*
  key {
    id              = var.rsa_key1_id
    algorithm       = "RSA"
    certificate     = file(var.rsa_key1_filename)
  }
  key {
    id              = var.rsa_key2_id
    algorithm       = "RSA"
    certificate     = file(var.rsa_key2_filename)
  }
  */
}
