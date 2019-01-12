#!/bin/bash

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

RESULTS=$(curl -s -X GET -H "Content-Type: application/json" -H "csp-auth-token: ${CSP_ACCESS_TOKEN}" "https://vmc.vmware.com/vmc/api/orgs/${ORGID}/sddcs/${SDDCID}")

SDDC_VERSION=$(echo ${RESULTS}|jq .resource_config.sddc_manifest.vmc_version)
CREATE_DATE=$(echo ${RESULTS}|jq .created)
DEPLOYMENT_TYPE=$(echo ${RESULTS}|jq .resource_config.deployment_type)
REGION=$(echo ${RESULTS}|jq .resource_config.region)
AVAILABILITY_ZONE=$(echo ${RESULTS}|jq .resource_config.availability_zones)
INSTANCE_TYPE=$(echo ${RESULTS}|jq .resource_config.sddc_manifest.esx_ami.instance_type)
VPC_CIDR=$(echo ${RESULTS}|jq .resource_config.vpc_info.vpc_cidr)
NSXT=$(echo ${RESULTS}|jq .resource_config.nsxt)
EXPIRATION_DATE=$(echo ${RESULTS}|jq .expiration_date)

cat << EOF

Version: ${SDDC_VERSION}
CreateDate: ${CREATE_DATE}
ExpirationDate: ${EXPIRATION_DATE}
DeploymentType: ${DEPLOYMENT_TYPE}
Region: ${REGION}
AvaiabilityZone: ${AVAILABILITY_ZONE}
InstanceType: ${INSTANCE_TYPE}
VpcCIDR: ${VPC_CIDR}
NSXT: ${NSXT}

EOF