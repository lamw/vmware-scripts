#!/bin/bash

if [ ${#} -ne 3 ]; then
    echo -e "Usage: \n\t$0 [REFRESH_TOKEN] [ORGID] [SDDCID]\n"
    exit 1
fi

type jq > /dev/null 2>&1
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

SDDC_NAME=$(cat SDDC_RESULTS|jq -r .name)
SDDC_VERSION=$(cat SDDC_RESULTS|jq -r .resource_config.sddc_manifest.vmc_version)
CREATE_DATE=$(cat SDDC_RESULTS|jq -r .created)
DEPLOYMENT_TYPE=$(cat SDDC_RESULTS|jq -r .resource_config.deployment_type)
REGION=$(cat SDDC_RESULTS|jq -r .resource_config.region)
AVAILABILITY_ZONE=$(cat SDDC_RESULTS|jq -r .resource_config.availability_zones)
INSTANCE_TYPE=$(cat SDDC_RESULTS|jq -r .resource_config.sddc_manifest.esx_ami.instance_type)
VPC_CIDR=$(cat SDDC_RESULTS|jq -r .resource_config.vpc_info.vpc_cidr)
NSXT=$(cat SDDC_RESULTS|jq -r .resource_config.nsxt)
EXPIRATION_DATE=$(cat SDDC_RESULTS|jq -r .expiration_date)
POP_IPADDRESS=$(cat SDDC_RESULTS|jq -r .resource_config.agent.internal_ip)

cat << EOF

SDDCName: ${SDDC_NAME}
Version: ${SDDC_VERSION}
CreateDate: ${CREATE_DATE}
ExpirationDate: ${EXPIRATION_DATE}
DeploymentType: ${DEPLOYMENT_TYPE}
Region: ${REGION}
AvaiabilityZone: ${AVAILABILITY_ZONE}
InstanceType: ${INSTANCE_TYPE}
VpcCIDR: ${VPC_CIDR}
PoPIP: ${POP_IPADDRESS}
NSXT: ${NSXT}

EOF