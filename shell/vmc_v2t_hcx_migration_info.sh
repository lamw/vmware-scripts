#!/bin/bash
# Author: William Lam (@lamw)
# Description: Script to help extract NSX-V and NSX-T SDDC Information for HCX V2T Migration (Cloud2Cloud)

if [ ${#} -lt 6 ]; then
    echo -e "Usage: \n\t$0 [NSXV_REFRESH_TOKEN] [NSXV_ORGID] [NSXV_SDDCID] [NSXT_REFRESH_TOKEN] [NSXT_ORGID] [NSXT_SDDCID] <SHOW_CLOUD_ADMIN_CREDS>\n"
    exit 1
fi

type jq > /dev/null 2&>1
if [ $? -eq 1 ]; then
    echo "It does not look like you have jq installed. This script uses jq to parse the JSON output"
    exit 1
fi

NSXV_REFRESH_TOKEN=$1
NSXV_ORGID=$2
NSXV_SDDCID=$3
NSXT_REFRESH_TOKEN=$4
NSXT_ORGID=$5
NSXT_SDDCID=$6
SHOW_CREDS=$7

RESULTS=$(curl -s -X POST -H "application/x-www-form-urlencoded" "https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize" -d "refresh_token=$NSXV_REFRESH_TOKEN")
NSXV_CSP_ACCESS_TOKEN=$(echo $RESULTS | jq -r .access_token)
RESULTS=$(curl -s -X POST -H "application/x-www-form-urlencoded" "https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize" -d "refresh_token=$NSXT_REFRESH_TOKEN")
NSXT_CSP_ACCESS_TOKEN=$(echo $RESULTS | jq -r .access_token)

VSDDC_RESULTS="VSDDC_RESULTS"
TSDDC_RESULTS="TSDDC_RESULTS"

# NSX-V SDDC Info
curl -s -X GET -H "Content-Type: application/json" -H "csp-auth-token: ${NSXV_CSP_ACCESS_TOKEN}" -o ${VSDDC_RESULTS} "https://vmc.vmware.com/vmc/api/orgs/${NSXV_ORGID}/sddcs/${NSXV_SDDCID}"
# NSX-T SDDC Info
curl -s -X GET -H "Content-Type: application/json" -H "csp-auth-token: ${NSXT_CSP_ACCESS_TOKEN}" -o ${TSDDC_RESULTS} "https://vmc.vmware.com/vmc/api/orgs/${NSXT_ORGID}/sddcs/${NSXT_SDDCID}"


VSDDC_CREDS="<hidden>"
TSDDC_CREDS="<hidden>"
if [[ ! -z ${SHOW_CREDS} ]] && [[ ${SHOW_CREDS} -eq 1 ]]; then
    VSDDC_CREDS=$(cat ${VSDDC_RESULTS} | jq -r .resource_config.cloud_password)
    TSDDC_CREDS=$(cat ${TSDDC_RESULTS} | jq -r .resource_config.cloud_password)
fi

cat << EOF

NSX-V SDDC (Source):
    Name: $(cat ${VSDDC_RESULTS} | jq -r .name)
    VC: $(cat ${VSDDC_RESULTS} | jq -r .resource_config.vc_url)
    HCX: $(cat ${VSDDC_RESULTS} | jq -r .resource_config.vc_url | sed 's/vcenter/hcx/g')
    CloudAdminPassword: ${VSDDC_CREDS}
    PoPIP: $(cat ${VSDDC_RESULTS}|jq -r .resource_config.agent.internal_ip)

NSX-T SDDC (Destination):
    Name: $(cat ${TSDDC_RESULTS} | jq -r .name)
    vCenter: $(cat ${TSDDC_RESULTS} | jq -r .resource_config.vc_url)
    HCX: $(cat ${TSDDC_RESULTS} | jq -r .resource_config.vc_url | sed 's/vcenter/hcx/g')
    CloudAdminPassword: ${TSDDC_CREDS}

EOF

rm -f ${VSDDC_RESULTS}
rm -f ${TSDDC_RESULTS}
