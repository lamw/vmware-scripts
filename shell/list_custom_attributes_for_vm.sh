VC='vcsa.primp-industries.local'
VC_USERNAME='administrator@vsphere.local'
VC_PASSWORD='VMware1!'
VC_API_RELEASE='8.0.1.0'
VM_NAME="esx-1.0"

# vCenter REST API

VCREST_API_SESSION_ID=$(curl -k -s -u "${VC_USERNAME}:${VC_PASSWORD}" -X POST "https://${VC}/api/session" | jq -j)
VM_MOREF=$(curl -s -H "vmware-api-session-id: ${VCREST_API_SESSION_ID}" -X GET "https://${VC}/api/vcenter/vm?names=${VM_NAME}" | jq -r '.[0].vm')

# vCenter VI JSON API

SESSION_MANAGER_MOID=$(curl -k -s https://$VC/sdk/vim25/${VC_API_RELEASE}/ServiceInstance/ServiceInstance/content | jq -j .sessionManager.value)
VIJSON_API_SESSION_ID=$(curl -k -s -o /dev/null -D - "https://$VC/sdk/vim25/${VC_API_RELEASE}/SessionManager/$SESSION_MANAGER_MOID/Login" -H 'Content-Type: application/json' -d "{\"userName\":\"${VC_USERNAME}\", \"password\": \"${VC_PASSWORD}\"}" | awk 'BEGIN {FS=": "}/^vmware-api-session-id/{print $2}')

CUSTOM_FIELDS_MANAGER_MOID=$(curl -k -s https://$VC/sdk/vim25/${VC_API_RELEASE}/ServiceInstance/ServiceInstance/content | jq -j .customFieldsManager.value)

# Retrieve Custom Field Key/Name for VirtualMachine definitions
curl -k -s -H "vmware-api-session-id: ${VIJSON_API_SESSION_ID}" -X GET "https://$VC/sdk/vim25/${VC_API_RELEASE}/CustomFieldsManager/${CUSTOM_FIELDS_MANAGER_MOID}/field" | jq -r '.[] | select(.managedObjectType == "VirtualMachine") | {key, name}'

curl -s -H "vmware-api-session-id: ${VIJSON_API_SESSION_ID}" -X GET "https://$VC/sdk/vim25/${VC_API_RELEASE}/VirtualMachine/${VM_MOREF}/value"
