#!/bin/bash -e
# Author: William Lam
# Website: williamlam.com
# Description: Manually Sync VCF SSO Active Directory over LDAP in VCF Operations 9.0

VCF_OPERATIONS_HOSTNAME="FILL_ME"
VCF_OPERATIONS_USERNAME="FILL_ME"
VCF_OPERATIONS_PASSWORD='FILL_ME'

RESULTS=$(curl -s -k -X POST "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/api/auth/token/acquire" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-d "$(printf '{"username":"%s","password":"%s","authSource":"local"}' \
        "$VCF_OPERATIONS_USERNAME" \
        "$VCF_OPERATIONS_PASSWORD")")

VCF_OPERATIONS_AUTH_TOKEN=$(echo ${RESULTS} | jq -r .token)

RESULTS=$(curl -s -X GET "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/vidb/identityproviders" \
-H 'accept: application/json' \
-H 'content-type: application/json' \
-H "Authorization: OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}" \
-H 'X-Ops-API-use-unsupported: true' \
--insecure)

VCF_OPERATIONS_IDP_ID=$(echo ${RESULTS} | jq -r .identityProviderInfoList[0].id)

RESULTS=$(curl -s -X GET "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/vidb/identityproviders/${VCF_OPERATIONS_IDP_ID}/ldapdirectories" \
-H 'accept: application/json' \
-H 'content-type: application/json' \
-H "Authorization: OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}" \
-H 'X-Ops-API-use-unsupported: true' \
--insecure)

VCF_OPERATIONS_LDAP_ID=$(echo ${RESULTS} | jq -r .items[0].id)

LDAP_SSO_SYNC_URL="https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/vidb/identityproviders/${VCF_OPERATIONS_IDP_ID}/ldapdirectories/${VCF_OPERATIONS_LDAP_ID}/sync"

echo -e "\nSync'ing LDAP SSO Directory ..."
RESULTS=$(curl -s -X PUT ${LDAP_SSO_SYNC_URL} \
-H 'accept: application/json' \
-H 'content-type: application/json' \
-H "Authorization: OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}" \
-H 'X-Ops-API-use-unsupported: true' \
--data-raw '{}' \
--insecure)

