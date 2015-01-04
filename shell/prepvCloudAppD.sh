#!/bin/bash
# Author: William Lam
# Website: www.virtuallyghetto.com
# Product: VMware vCloud Application Director
# Description: Script to disable firstboot configs to allow for unattended installs & configures AppD license
# Reference: http://www.virtuallyghetto.com/2014/01/automating-vcloud-application-director.html

APPD_LICENSE=1234567
APPD_VMDK_MOUNT_HOME=/mnt

### DO NOT EDIT BEYOND HERE ###

APPD_LICENSE_FILE=/home/darwin/tcserver/darwin/appd-license.properties
APPD_FIRSTBOOT_FILE=/opt/vmware/etc/isv/firstboot

MOUNTED_APPD_LICENSE_FILE=${APPD_VMDK_MOUNT_HOME}${APPD_LICENSE_FILE}
MOUNTED_APPD_FIRSTBOOT_FILE=${APPD_VMDK_MOUNT_HOME}${APPD_FIRSTBOOT_FILE}

echo "Creating AppD license file ${MOUNTED_APPD_LICENSE_FILE} ..."
cat > ${MOUNTED_APPD_LICENSE_FILE} << __APPD_LICENSE__
serial.number=${APPD_LICENSE}
license.dir=/home/darwin/license
__APPD_LICENSE__

echo "Commenting out AppD firstboot script ..."
cp "${MOUNTED_APPD_FIRSTBOOT_FILE}" "${MOUNTED_APPD_FIRSTBOOT_FILE}.bak"
sed -i '75,102s/^/#/g' "${MOUNTED_APPD_FIRSTBOOT_FILE}"
sed -i '287,289s/^/#/g' "${MOUNTED_APPD_FIRSTBOOT_FILE}"
