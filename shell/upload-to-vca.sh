#!/bin/bash
# Author: William Lam
# Website: www.williamlam.com
# Reference: http://www.williamlam.com/2015/05/quick-tip-how-to-upload-files-to-vcloud-air-on-demand-using-ovftool.html

# Path to ovftool binary
OVFTOOL='/Applications/VMware OVF Tool/ovftool'

# vCloud Air On-Demand VCD URL
VCA_URL='us-california-1-3.vchs.vmware.com'

# VCD Org Name
VCA_ORG_NAME='b51b26c4-7c13-44a7-a1d9-07607a9d6dd6'

# VCD VDC Name
VCA_ORG_VDC_NAME='vGhetto-VDC'

# VCD Catalog Name
VCA_CATALOG_NAME='default-catalog'

### Example of uploading ISO to vCloud Air On-Demand ###

FILE_TO_UPLOAD='/Volumes/Storage/Images/Current/VMware-VMvisor-Installer-6.0.0-2494585.x86_64.iso'
FILE_FILENAME_IN_VCA='ESXi-6.0.iso'

"${OVFTOOL}" --X:logFile=vcd-upload.log --X:logLevel=verbose \
"${FILE_TO_UPLOAD}" \
"vcloud://${VCA_URL}?org=${VCA_ORG_NAME}&vdc=${VCA_ORG_VDC_NAME}&catalog=${VCA_CATALOG_NAME}&media=${FILE_FILENAME_IN_VCA}"

### Example of uplaoding OVF to vCloud Air On-Demand ###

#FILE_TO_UPLOAD='/Volumes/Storage/Images/Current/Nested-ESXi-VM-Template/Nested-ESXi-VM.ovf'
#FILE_FILENAME_IN_VCA='Nested-ESXi-VM-Template'

#"${OVFTOOL}" --acceptAllEulas --skipManifestCheck --vCloudTemplate=true --allowExtraConfig --X:logFile=vcd-upload.log --X:logLevel=verbose \
#"${FILE_TO_UPLOAD}" \
#"vcloud://${VCA_URL}?org=${VCA_ORG_NAME}&vdc=${VCA_ORG_VDC_NAME}&catalog=${VCA_CATALOG_NAME}&vappTemplate=${FILE_FILENAME_IN_VCA}"
