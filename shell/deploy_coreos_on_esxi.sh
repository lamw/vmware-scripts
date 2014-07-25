#!/bin/sh
# William Lam
# www.virtuallyghetto.com
# Simple script to pull down CoreOS image & run on ESXi

# CoreOS ZIP URL
CORE_OS_DOWNLOAD_URL=http://alpha.release.core-os.net/amd64-usr/current/coreos_production_vmware_insecure.zip

# Path of Datastore to store CoreOS
DATASTORE_PATH=/vmfs/volumes/mini-local-datastore-2

# VM Network to connect CoreOS to
VM_NETWORK="VM Network"

# Name of VM
VM_NAME=CoreOS

## DOT NOT EDIE BYOND HERE ##

# Creates CoreOS VM Directory and change into it
mkdir -p ${DATASTORE_PATH}/${VM_NAME}
cd ${DATASTORE_PATH}/${VM_NAME}

# Download CoreOS 
wget ${CORE_OS_DOWNLOAD_URL}

# Unzip CoreOS & remove file
unzip coreos_production_vmware_insecure.zip
rm -f coreos_production_vmware_insecure.zip

# Convert VMDK from 2gbsparse from hosted products to Thin
vmkfstools -i coreos_production_vmware_insecure_image.vmdk -d thin coreos.vmdk

# Remove the original 2gbsparse VMDKs
rm coreos_production_vmware_insecure_image*.vmdk

# Update CoreOS VMX to reference new VMDK
sed -i 's/coreos_production_vmware_insecure_image.vmdk/coreos.vmdk/g' coreos_production_vmware_insecure.vmx

# Update CoreOS VMX w/new VM Name
sed -i "s/displayName.*/displayName = \"${VM_NAME}\"/g" coreos_production_vmware_insecure.vmx

# Update CoreOS VMX to map to VM Network
echo "ethernet0.networkName = \"${VM_NETWORK}\"" >> coreos_production_vmware_insecure.vmx

# Register CoreOS VM which returns VM ID
VM_ID=$(vim-cmd solo/register ${DATASTORE_PATH}/${VM_NAME}/coreos_production_vmware_insecure.vmx)

# Upgrade CoreOS Virtual Hardware from 4 to 9
vim-cmd vmsvc/upgrade ${VM_ID} vmx-09

# PowerOn CoreOS VM
vim-cmd vmsvc/power.on ${VM_ID}

# Reset CoreOS VM to quickly get DHCP address
vim-cmd vmsvc/power.reset ${VM_ID}
