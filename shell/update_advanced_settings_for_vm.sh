#!/bin/bash
# VI JSON API example for Updating VM Advanced Setting

VC='vcsa.primp-industries.local'
VC_USERNAME='administrator@vsphere.local'
VC_PASSWORD='VMware1!'
VC_API_RELEASE='9.0.0.0'
VM_NAME='MyVM'

# vCenter REST API
VCREST_API_SESSION_ID=$(curl -k -s -u "${VC_USERNAME}:${VC_PASSWORD}" -X POST "https://${VC}/api/session" | jq -j)
VM_MOREF=$(curl -k -s -H "vmware-api-session-id: ${VCREST_API_SESSION_ID}" -X GET "https://${VC}/api/vcenter/vm?names=${VM_NAME}" | jq -r '.[0].vm')

# Update disk.EnableUUID & svga.present
# Add blog
cat > extra-config-spec.json <<EOF
{
   "spec": {
      "_typeName": "VirtualMachineConfigSpec",
      "extraConfig": [
         {
	    "_typeName": "OptionValue",
            "key": "disk.EnableUUID",
            "value": {
               "_typeName": "string",
               "_value": "FALSE"
            }
         },
         {
            "_typeName": "OptionValue",
            "key": "svga.present",
            "value": {
               "_typeName": "string",
               "_value": "FALSE"
            }
         },
         {
            "_typeName": "OptionValue",
            "key": "blog",
            "value": {
               "_typeName": "string",
               "_value": "williamlam.com"
            }
         }
      ]
   }
}
EOF

# Reconfigure VM's Advanced Setting
curl -k -s -H "vmware-api-session-id: ${VCREST_API_SESSION_ID}" -H "Content-Type: application/json" -X POST "https://$VC/sdk/vim25/${VC_API_RELEASE}/VirtualMachine/${VM_MOREF}/ReconfigVM_Task" -d@extra-config-spec.json

# List VM Advanced Settings that we had just modified
curl -k -s -H "vmware-api-session-id: ${VCREST_API_SESSION_ID}" -H "Content-Type: application/json" -X GET "https://$VC/sdk/vim25/${VC_API_RELEASE}/VirtualMachine/${VM_MOREF}/config" | jq -r '.extraConfig[] | select(.key == "svga.present" or .key == "disk.EnableUUID" or .key == "blog")'
