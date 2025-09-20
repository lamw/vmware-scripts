#!/bin/bash -e
# Author: William Lam
# Website: williamlam.com
# Description: Download License Usage File from VCF Operations 9.0

VCF_OPERATIONS_HOSTNAME="vcf01.vcf.lab"
VCF_OPERATIONS_USERNAME="admin"
VCF_OPERATIONS_PASSWORD='VMware1!VMware1!'

echo -e "\nAcquiring auth token from VCF Ops: ${VCF_OPERATIONS_HOSTNAME} ..."
RESULTS=$(curl -s -k -X POST "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/api/auth/token/acquire" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-d "$(printf '{"username":"%s","password":"%s","authSource":"local"}' \
        "$VCF_OPERATIONS_USERNAME" \
        "$VCF_OPERATIONS_PASSWORD")")

VCF_OPERATIONS_AUTH_TOKEN=$(echo ${RESULTS} | jq -r .token)

if date --version >/dev/null 2>&1; then
        # GNU date (Linux)
        STARTDATE=$(date -d "now +1 day" +%s)000
        ENDDATE=$(date -d "now +1 month" +%s)000
else
        # BSD date (macOS)
        STARTDATE=$(date -v+1d +%s)000
        ENDDATE=$(date -v+3m +%s)000
fi

echo -e "\nGenerating VCF Ops Usage File ..."
RESULTS=$(curl -s -X POST "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/extension/vcf-license-cloud-integration/usage/offline/report?startDate=${STARTDATE}&endDate=${ENDDATE}" \
-H 'accept: application/json' \
-H 'content-type: application/json' \
-H "Authorization: OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}" \
-H 'X-Ops-API-use-unsupported: true' \
--insecure)

VCFO_USAGE_DATA=$(echo $RESULTS | jq -r .gzipJwsEncodedData)
VCFO_USAGE_FILENAME=$(echo $RESULTS | jq -r .fileName)

echo -e "\nSaving VCF Ops Usage File: ${VCFO_USAGE_FILENAME} ..."
echo ${VCFO_USAGE_DATA} | base64 -d > ${VCFO_USAGE_FILENAME}

