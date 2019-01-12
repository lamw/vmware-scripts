#!/bin/bash

if [ ${#} -ne 4 ]; then
    echo -e "Usage: \n\t$0 [REFRESH_TOKEN] [ORGID] [SDDCID] [NEW_SDDC_NAME]\n"
    exit 1
fi

REFRESH_TOKEN=$1
ORGID=$2
SDDCID=$3
NEW_SDDC_NAME=$4

RESULTS=$(curl -s -X POST -H "application/x-www-form-urlencoded" "https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize" -d "refresh_token=$REFRESH_TOKEN")
CSP_ACCESS_TOKEN=$(echo $RESULTS | jq -r .access_token)

echo -e "\nRenaming SDDC (${SDDCID}) to ${NEW_SDDC_NAME}\n"
RESULTS=$(curl -s -X PATCH -H "Content-Type: application/json" -H "csp-auth-token: ${CSP_ACCESS_TOKEN}" "https://vmc.vmware.com/vmc/api/orgs/${ORGID}/sddcs/${SDDCID}" -d "{\"name\":\"$NEW_SDDC_NAME\"}")