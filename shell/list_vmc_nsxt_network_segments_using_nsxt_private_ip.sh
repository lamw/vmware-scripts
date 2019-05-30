#!/bin/bash
# Author: William Lam (@lamw)
# Description: Using cURL to inteact with the new NSX-T Policy API in VMC using NSX-T Private IP

if [ ${#} -ne 2 ]; then
    echo -e "Usage: \n\t$0 [REFRESH_TOKEN] [NSXT_PRIVATE_IP\n"
    exit 1
fi

type jq > /dev/null 2&>1
if [ $? -eq 1 ]; then
    echo "It does not look like you have jq installed. This script uses jq to parse the JSON output"
    exit 1
fi

REFRESH_TOKEN=$1
NSXT_PRIVATE_IP=$2

RESULTS=$(curl -s -X POST -H "application/x-www-form-urlencoded" "https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize" -d "refresh_token=$REFRESH_TOKEN")
CSP_ACCESS_TOKEN=$(echo $RESULTS | jq -r .access_token)

curl -s -X GET -H "Content-Type: application/json" -H "csp-auth-token: ${CSP_ACCESS_TOKEN}" -o SDDC_RESULTS "https://vmc.vmware.com/vmc/api/orgs/${ORGID}/sddcs/${SDDCID}"

NSXT_SEGMENTS_URL="https://${NSXT_PRIVATE_IP}/policy/api/v1/infra/tier-1s/cgw/segments"

RESULTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${CSP_ACCESS_TOKEN}" ${NSXT_SEGMENTS_URL})
echo ${RESULTS} | jq