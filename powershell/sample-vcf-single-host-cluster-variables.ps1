# ============================================================================
# VCF 9.1.1 - Single ESXi Host Cluster (added to an EXISTING Workload Domain)
# Sample configuration file - copy & fill in for your environment
# ============================================================================

# SDDC Manager (already deployed Management Domain)
$sddcManagerFQDN     = "sddcm01.vcf.lab"
$sddcManagerUsername = "administrator@vsphere.local"
$sddcManagerPassword = "VMware1!VMware1!"

# The EXISTING Workload Domain to add this cluster to (must already exist -
# this script does not create a Workload Domain, see the sibling
# vcf-single-host-shared-nsx-wld-deployment.ps1 script for that)
$VCFWorkloadDomainName = "vcf-m01"

# The existing vCenter datacenter (inside that Workload Domain) to place the
# new cluster into - this is the datacenter created when the domain was
# originally deployed, not a new one
$VCFDatacenterName = "VCF-Datacenter"

# New cluster identity
$VCFClusterName = "VCF-Workload-Cluster"

# vLCM Image to use for cluster lifecycle management (required in VCF 9.1 -
# baseline-based clusters are rejected during validation). Must match a name
# under SDDC Manager -> Lifecycle Management -> Image Management
$VLCMImageName = "Management-Domain-ESXi-Personality"

# The single ESXi host to use for the new cluster.
# Must already be commissioned in SDDC Manager and show as UNASSIGNED_USEABLE
# (Inventory -> Hosts). This script looks it up by FQDN, it does not commission it.
$ESXiHostFQDN        = "esx04.vcf.lab"
$ESXiHostStorageType = "VSAN_ESA"   # VSAN | VSAN_ESA | VMFS_FC | NFS_V3 | VVOL (single host tested with VSAN)

# General networking used by the cluster's port groups
$VMNetmask = "255.255.255.0"
$VMGateway = "172.30.0.1"
$VMDomain  = "vcf.lab"

# Per-cluster NSX transport/overlay configuration. The domain's NSX Manager
# already exists (it was set up when the Workload Domain was created) - this
# is just the new cluster's own VLAN + TEP IP pool for it.
$GeneveVlanId        = 60
$NSXIpPoolName       = "$VCFClusterName-tep01"
$NSXIpPoolCidr       = "172.30.60.0/24"
$NSXIpPoolGateway    = "172.30.60.1"
$NSXIpPoolRangeStart = "172.30.60.50"
$NSXIpPoolRangeEnd   = "172.30.60.60"
