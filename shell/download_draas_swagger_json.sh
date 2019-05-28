#!/bin/bash

if [ ${#} -ne 1 ]; then
    echo -e "Usage: \n\t$0 [REFRESH_TOKEN]\n"
    exit 1
fi

REFRESH_TOKEN=$1

CSP_URL="console.cloud.vmware.com"
DRAAS_SWAGGER_URL="https://vmc.vmware.com/vmc/draas/swagger/swagger.json"

RESULTS=$(curl -s -X POST -H "application/x-www-form-urlencoded" "https://${CSP_URL}/csp/gateway/am/api/auth/api-tokens/authorize" -d "refresh_token=${REFRESH_TOKEN}")
CSP_ACCESS_TOKEN=$(echo $RESULTS | jq -r .access_token)

curl -X GET -H "Content-Type: application/json" -H "csp-auth-token: ${CSP_ACCESS_TOKEN}" ${DRAAS_SWAGGER_URL} -o draas.json