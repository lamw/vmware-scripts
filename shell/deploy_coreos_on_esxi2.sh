#!/bin/bash
# William Lam
# www.virtuallyghetto.com
# New version of script to automate the deployment of CoreOS image w/VMware Tools onto ESXi

# CoreOS VMX URL
CORE_OS_VMX_URL=http://alpha.release.core-os.net/amd64-usr/current/coreos_production_vmware.vmx

# CoreSO VMDK URL
CORE_OS_VMDK_URL=http://alpha.release.core-os.net/amd64-usr/current/coreos_production_vmware_image.vmdk.bz2

# IP or Hostname of ESXI host
ESXI_HOST=192.168.1.200

# ESXi Username
ESXI_USERNAME=root

# ESXi Password
ESXI_PASSWORD=vmware123

# Name of vSphere Datastore to upload CoreOS VM
ESXI_DATASTORE=mini-local-datastore-1

# Name of the VM Network to connect CoreOS VM
VM_NETWORK="VM Network"

# Name of the CoreOS VM
VM_NAME=CoreOS

# Hostname of CoreOS Instance
CORE_OS_HOSTNAME=coreos01.primp-industries.com

# IP Address of CoreOS Instance
CORE_OS_IP_ADDRESS=192.168.1.50

# Username to enable on CoreOS Instance
CORE_OS_USERNAME=vghetto

# Password hash of CoreOS Instance
CORE_OS_PASSWORD_HASH='$69sWzVthtg/w'

# Name of the CoreOS Cloud Config ISO
CLOUD_CONFIG_ISO=${CORE_OS_HOSTNAME}-config.iso

##### DO NOT EDIT BEYOND HERE #####

CORE_OS_DATASTORE_PATH=/vmfs/volumes/${ESXI_DATASTORE}/${VM_NAME}
MKDIR_COMMAND=$(eval echo mkdir -p ${CORE_OS_DATASTORE_PATH})
CORE_OS_ESXI_SETUP_SCRIPT=setup_core_os_on_esxi.sh

echo "Download CoreOS VMX Configuration File ..."
curl -O "${CORE_OS_VMX_URL}"

echo "Downloading CoreOS VMDK Disk File ..."
curl -O "${CORE_OS_VMDK_URL}"

echo "Checking if bunzip2 exists ..."
if ! which bunzip2 > /dev/null 2>&1; then
	echo "Error: bunzip2 does not exists on your system"
	exit 1
fi

echo "Checking if mkisofs exists ..."
if ! which mkisofs > /dev/null 2>&1; then
	echo "Error: mkisofs does not exists on your system"
	exit 1
fi

echo "Extracting CoreOS VMDK ..."
bunzip2 $(ls | grep ".bz2")

CORE_OS_VMDK_FILE=$(ls | grep ".vmdk")
CORE_OS_VMX_FILE=$(ls | grep ".vmx")

# ghetto way of creating VM directory
echo "Creating ${CORE_OS_DATASTORE_PATH} ..."
VAR=$(expect -c "
spawn ssh -o StrictHostKeyChecking=no ${ESXI_USERNAME}@${ESXI_HOST} $MKDIR_COMMAND
match_max 100000
expect \"*?assword:*\"
send -- \"$ESXI_PASSWORD\r\"
send -- \"\r\"
expect eof
")

TMP_CLOUD_CONFIG_DIR=/tmp/new-drive

echo "Build Cloud Config Settings ..."
mkdir -p ${TMP_CLOUD_CONFIG_DIR}/openstack/latest

cat > ${TMP_CLOUD_CONFIG_DIR}/openstack/latest/user_data << __CLOUD_CONFIG__
#cloud-config

hostname: ${COREOS_HOSTNAME}

coreos:
  update:
    reboot-strategy: etcd-lock
  etcd:
    #discovery: https://discovery.etcd.io/<token>
    addr: ${CORE_OS_IP_ADDRESS}:4001
    peer-addr: ${CORE_OS_IP_ADDRESS}:7001

  fleet:
    public-ip: ${CORE_OS_IP_ADDRESS}

  units:
    - name: etcd.service
      command: start
    - name: fleet.service
      command: start
    - name: docker-tcp.socket
      command: start
      enable: true
      content: |
        [Unit]
        Description=Docker Socket for the API

        [Socket]
        ListenStream=2375
        Service=docker.service
        BindIPv6Only=both

        [Install]
        WantedBy=sockets.target

users:
  - name: ${CORE_OS_USERNAME}
    passwd: ${CORE_OS_PASSWORD_HASH}
    primary-group: wheel
    groups:
      - sudo
      - docker
__CLOUD_CONFIG__

echo "Creating Cloud Config ISO ..."
mkisofs -R -V config-2 -o ${CLOUD_CONFIG_ISO} ${TMP_CLOUD_CONFIG_DIR}

# Using HTTP put API to upload both VMX/VMDK
echo "Uploading CoreOS Cloud-Config ISO file to ${ESXI_DATASTORE} ..."
curl -H "Content-Type: application/octet-stream" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}" --data-binary "@${CLOUD_CONFIG_ISO}" -X PUT "https://${ESXI_HOST}/folder/${VM_NAME}/${CLOUD_CONFIG_ISO}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

# Using HTTP put API to upload both VMX/VMDK
echo "Uploading CoreOS VMDK file to ${ESXI_DATASTORE} ..."
curl -H "Content-Type: application/octet-stream" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}" --data-binary "@${CORE_OS_VMDK_FILE}" -X PUT "https://${ESXI_HOST}/folder/${VM_NAME}/${CORE_OS_VMDK_FILE}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

echo "Uploading CoreOS VMX file to ${ESXI_DATASTORE} ..."
curl -H "Content-Type: application/octet-stream" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}" --data-binary "@${CORE_OS_VMX_FILE}" -X PUT "https://${ESXI_HOST}/folder/${VM_NAME}/${CORE_OS_VMX_FILE}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

# Creates script to convert VMDK & register on ESXi host
echo "Creating script to convert and register CoreOS VM on ESXi ..."
cat > ${CORE_OS_ESXI_SETUP_SCRIPT} << __CORE_OS_ON_ESXi__
#!/bin/sh
# William Lam
# www.virtuallyghetto.com
# Auto Geneated script to automate the conversion of VMDK & regiration of CoreOS VM

# Change to CoreOS directory
cd ${CORE_OS_DATASTORE_PATH}

# Convert VMDK from 2gbsparse from hosted products to Thin
vmkfstools -i ${CORE_OS_VMDK_FILE} -d thin coreos.vmdk

# Remove the original 2gbsparse VMDKs
rm ${CORE_OS_VMDK_FILE}

# Update CoreOS VMX to reference new VMDK
sed -i 's/${CORE_OS_VMDK_FILE}/coreos.vmdk/g' ${CORE_OS_VMX_FILE}

# Update CoreOS VMX w/new VM Name
sed -i "s/displayName.*/displayName = \"${VM_NAME}\"/g" ${CORE_OS_VMX_FILE}

# Update CoreOS VMX to map to VM Network
echo "ethernet0.networkName = \"${VM_NETWORK}\"" >> ${CORE_OS_VMX_FILE}

# Update CoreOS VMX to include CD-ROM & mount cloud-config ISO
cat >> ${CORE_OS_VMX_FILE} << __CLOUD_CONFIG_ISO__
ide0:0.deviceType = "cdrom-image"
ide0:0.fileName = "${CLOUD_CONFIG_ISO}"
ide0:0.present = "TRUE"
__CLOUD_CONFIG_ISO__

# Register CoreOS VM which returns VM ID
VM_ID=\$(vim-cmd solo/register ${CORE_OS_DATASTORE_PATH}/${CORE_OS_VMX_FILE})

# Upgrade CoreOS Virtual Hardware from 4 to 9
vim-cmd vmsvc/upgrade \${VM_ID} vmx-09

# PowerOn CoreOS VM
vim-cmd vmsvc/power.on \${VM_ID}

__CORE_OS_ON_ESXi__
chmod +x ${CORE_OS_ESXI_SETUP_SCRIPT}

echo "Running ${CORE_OS_ESXI_SETUP_SCRIPT} script against ESXi host ..."
ssh -o ConnectTimeout=300 ${ESXI_USERNAME}@${ESXI_HOST} < ${CORE_OS_ESXI_SETUP_SCRIPT}

echo "Cleaning up ..."
rm -f ${CORE_OS_ESXI_SETUP_SCRIPT}
rm -f ${CORE_OS_VMDK_FILE}
rm -f ${CORE_OS_VMX_FILE}
rm -f ${CLOUD_CONFIG_ISO}
rm -rf ${TMP_CLOUD_CONFIG_DIR}

