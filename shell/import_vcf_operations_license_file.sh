#!/bin/bash -e
# Author: William Lam
# Website: williamlam.com
# Description: Import license file into VCF Operations 9.0

VCF_OPERATIONS_HOSTNAME="vcf01.vcf.lab"
VCF_OPERATIONS_USERNAME="admin"
VCF_OPERATIONS_PASSWORD='VMware1!VMware1!'
VCF_OPERATIONS_LICENSE_FILE=$1

# Check if it's a valid file
if [[ ! -f "$VCF_OPERATIONS_LICENSE_FILE" ]]; then
        echo "Error: '$VCF_OPERATIONS_LICENSE_FILE' is not a valid file."
        exit 1
fi

echo -e "\nAcquiring auth token from VCF Ops: ${VCF_OPERATIONS_HOSTNAME} ..."
RESULTS=$(curl -s -k -X POST "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/api/auth/token/acquire" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-d "$(printf '{"username":"%s","password":"%s","authSource":"local"}' \
        "$VCF_OPERATIONS_USERNAME" \
        "$VCF_OPERATIONS_PASSWORD")")

VCF_OPERATIONS_AUTH_TOKEN=$(echo ${RESULTS} | jq -r .token)

echo -e "\nUploading License File to VCF Ops ..."
RESULTS=$(curl -s -X POST "https://${VCF_OPERATIONS_HOSTNAME}/suite-api/internal/extension/vcf-license-cloud-integration/registration/offline/response" \
-H 'accept: application/json' \
-H 'content-type: multipart/form-data' \
-H "Authorization: OpsToken ${VCF_OPERATIONS_AUTH_TOKEN}" \
-H 'X-Ops-API-use-unsupported: true' \
-F "file=@${VCF_OPERATIONS_LICENSE_FILE}" \
--insecure)


