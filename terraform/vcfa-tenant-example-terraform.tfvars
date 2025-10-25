url = "https://auto01.vcf.lab"

username    = "admin"
password    = "VMware1!VMware1!"
org         = "Legal"
region_name = "west"

storage_class = "vcf-vsan-esa-policy"

supervisor_zone = "vz-01"

#### --- Start Custom Variables from William Lam --- ####

oidc_client_id = "vcfa-legal"
oidc_client_secret = "XXX"
oidc_client_well_known_url = "https://auth.vcf.lab:8443/realms/it/.well-known/openid-configuration"
oidc_client_scopes = ["openid", "profile", "email"]

/*
rsa_key1_filename = "rsa-key1.pub.pem"
rsa_key1_id = "vKzob1blphOoku-LCMUHQQ0R80NMa3pgxQQF-vDXd5Y"

rsa_key2_filename = "rsa-key2.pub.pem"
rsa_key2_id = "YPC-UzCfw3ub1icQ4T_40gUOeswNCNGj5pgBue9bo0Q"
*/