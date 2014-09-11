#!/bin/bash
# William Lam
# www.virtuallyghetto.com
# Script to build cusotm ESXi ISO to handle Mac Mini 6,2 Known Issues

if [ $# -eq 0 ]; then
	echo -e "\n\tUsage: [ESXi-ISO]\n"
	exit 1
fi

if [ ! -e custom.tgz ]; then
	echo "It does not look like you have the custom.tgz in the current working directory!"
	exit 1
fi

which mkisofs > /dev/null 2>&1
if [ $? -eq 1 ]; then
	echo "It does not look like this system has "mkisofs" installed which is required for ISO creation!"
	exit 1
fi

ISO=$1
ESXI_ISO_DIR=${ISO%%.iso}-EXTRACTED
ESXI_NEW_ISO=${ISO%%.iso}-NEW.iso

echo "Creating mount directory /mnt/esxi ..."
mkdir -p /mnt/esxi

echo "Loop mounting ${ISO} to /mnt/esxi ..."
mount -o loop ${ISO} /mnt/esxi

echo "Copying ESXi contents to ${ESXI_ISO_DIR} ..."
cp -rf /mnt/esxi ${ESXI_ISO_DIR}

echo "Umounting /mnt/esxi ..."
umount /mnt/esxi

echo "Copying custom.tgz to ${ESXI_ISO_DIR} ..."
cp custom.tgz ${ESXI_ISO_DIR}

echo "Appending custom.tgz to ${ESXI_ISO_DIR}/boot.cfg ..."
sed -i 's/\/imgpayld.tgz/\/imgpayld.tgz --- \/custom.tgz/g' ${ESXI_ISO_DIR}/boot.cfg

echo "Appending custom.tgz to ${ESXI_ISO_DIR}/efi/boot/boot.cfg ..."
sed -i 's/\/imgpayld.tgz/\/imgpayld.tgz --- \/custom.tgz/g' ${ESXI_ISO_DIR}/efi/boot/boot.cfg

echo "Appending iovDisableIR=TRUE to ${ESXI_ISO_DIR}/boot.cfg ..."
sed -i 's/kernelopt.*/kernelopt=runweasel iovDisableIR=TRUE/g' ${ESXI_ISO_DIR}/boot.cfg

echo "Appending iovDisableIR=TRUE to ${ESXI_ISO_DIR}/efi/boot/boot.cfg ..."
sed -i 's/kernelopt.*/kernelopt=runweasel iovDisableIR=TRUE/g' ${ESXI_ISO_DIR}/efi/boot/boot.cfg

echo "Remastering ESXi ISO to ${ESXI_NEW_ISO} ..."
mkisofs -relaxed-filenames -J -R -o ${ESXI_NEW_ISO} -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table ${ESXI_ISO_DIR}

echo "Cleaning up and removing ${ESXI_ISO_DIR} ..."
rm -rf ${ESXI_ISO_DIR}