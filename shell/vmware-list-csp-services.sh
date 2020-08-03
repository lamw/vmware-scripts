#!/bin/bash

if [ ${#} -ne 1 ]; then
    echo -e "Usage: \n\t$0 [REFRESH_TOKEN]\n"
    exit 1
fi

type jq > /dev/null 2>&1
if [ $? -eq 1 ]; then
    echo "It does not look like you have jq installed. This script uses jq to parse the JSON output"
    exit 1
fi

REFRESH_TOKEN=$1

RESULTS=$(curl -s -X POST -H "Content-Type: application/json" -H "csp-auth-token: ${REFRESH_TOKEN}" "https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize?refresh_token=${REFRESH_TOKEN}")
CSP_ACCESS_TOKEN=$(echo $RESULTS | jq -r .access_token)

RESULTS=$(curl -s -X GET -H "Content-Type: application/json" -H "csp-auth-token: ${CSP_ACCESS_TOKEN}"  "https://console.cloud.vmware.com/csp/gateway/slc/api/definitions?expand=1")

echo ${RESULTS}| jq -r '.results[] | select(.visible == true) | .displayName'

