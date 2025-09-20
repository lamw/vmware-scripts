#!/bin/bash -e
# Author: William Lam
# Website: williamlam.com
# Description: Download License Registration File from VCF Operations 9.0

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

echo -e "\nDownloading VCF Ops Registration File ..."
RESULTS=$(curl -s -X POST "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/extension/vcf-license-cloud-integration/registration/offline/request" \
-H 'accept: application/json' \
-H 'content-type: application/json' \
-H "Authorization: OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}" \
-H 'X-Ops-API-use-unsupported: true' \
--insecure)

VCFO_REG_DATA=$(echo $RESULTS | jq -r .jwsEncodedData)
VCFO_REG_FILENAME=$(echo $RESULTS | jq -r .fileName)

echo -e "\nSaving VCF Ops Registration File: ${VCFO_REG_FILENAME} ..."
echo ${VCFO_REG_DATA} > ${VCFO_REG_FILENAME}