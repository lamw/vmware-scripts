#!/bin/bash
# Author: William Lam (@lamw)
# Description: Using cURL to list all NSX-T VM/Tags in VMC

if [ ${#} -ne 3 ]; then
    echo -e "Usage: \n\t$0 [REFRESH_TOKEN] [ORGID] [SDDCID]\n"
    exit 1
fi

type jq > /dev/null 2&>1
if [ $? -eq 1 ]; then
    echo "It does not look like you have jq installed. This script uses jq to parse the JSON output"
    exit 1
fi

REFRESH_TOKEN=$1
ORGID=$2
SDDCID=$3

RESULTS=$(curl -s -X POST -H "application/x-www-form-urlencoded" "https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize" -d "refresh_token=$REFRESH_TOKEN")
CSP_ACCESS_TOKEN=$(echo $RESULTS | jq -r .access_token)

curl -s -X GET -H "Content-Type: application/json" -H "csp-auth-token: ${CSP_ACCESS_TOKEN}" -o SDDC_RESULTS "https://vmc.vmware.com/vmc/api/orgs/${ORGID}/sddcs/${SDDCID}"

NSXT_PROXY_URL=$(cat SDDC_RESULTS|jq -r .resource_config.nsx_api_public_endpoint_url)
NSXT_TAGS_URL="${NSXT_PROXY_URL}/policy/api/v1/infra/realized-state/enforcement-points/vmc-enforcementpoint/virtual-machines?page_size=50&sort_by=display_name&sort_ascending=true&query="

curl -s -X GET -H "Content-Type: application/json" -H "csp-auth-token: ${CSP_ACCESS_TOKEN}" "${NSXT_TAGS_URL}" | jq '.results[] | .display_name,.external_id,.tags'