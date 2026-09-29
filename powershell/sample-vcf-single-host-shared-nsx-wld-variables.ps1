# ============================================================================
# VCF 9.1.1 - Single ESXi Host Workload Domain (Shared/Existing NSX Manager)
# Sample configuration file - copy & fill in for your environment
# ============================================================================

# SDDC Manager (already deployed Management Domain)
$sddcManagerFQDN     = "sddcm01.vcf.lab"
$sddcManagerUsername = "administrator@vsphere.local"
$sddcManagerPassword = "VMware1!VMware1!"

# New Workload Domain identity
$VCFWorkloadDomainName    = "vcf-w01"
$VCFWorkloadDomainOrgName = "vcf-w01"

# vCenter datacenter name to create inside the new Workload Domain's vCenter
$VCFDatacenterName = "$VCFWorkloadDomainName-dc01"

# Sharing the Management Domain's NSX Manager requires this to be created as
# an Isolated Domain (its own SSO domain, not joined to Management's SSO ring)
$SSODomainName     = "vsphere.local"
$SSODomainPassword = "VMware1!VMware1!"

# vLCM Image to use for cluster lifecycle management (required in VCF 9.1 -
# baseline-based clusters are rejected during validation). Must match a name
# under SDDC Manager -> Lifecycle Management -> Image Management
$VLCMImageName = "Management-Domain-ESXi-Personality"

# The single ESXi host to use for the new Workload Domain.
# Must already be commissioned in SDDC Manager and show as UNASSIGNED_USEABLE
# (Inventory -> Hosts). This script looks it up by FQDN, it does not commission it.
$ESXiHostFQDN        = "esx04.vcf.lab"
$ESXiHostStorageType = "VSAN_ESA"   # VSAN | VSAN_ESA | VMFS_FC | NFS_V3 | VVOL (single host tested with VSAN)

# vCenter Server to be deployed for the new Workload Domain
$VCSAHostname     = "vc02"
$VCSAIP           = "172.30.0.91"
$VCSARootPassword = "VMware1!VMware1!"

# General networking used by vCenter + cluster port groups
$VMNetmask = "255.255.255.0"
$VMGateway = "172.30.0.1"
$VMDomain  = "vcf.lab"

# ----------------------------------------------------------------------------
# EXISTING / SHARED NSX Manager details
# This MUST exactly match the NSX Manager instance that is ALREADY deployed
# and registered in SDDC Manager (e.g. from the Management Domain or another
# Workload Domain) that you want this new Workload Domain to share/join.
# Do NOT invent new hostnames/IPs here - these must be the live, existing
# NSX Manager appliance(s). See KB 401167 for background on this mechanism.
# ----------------------------------------------------------------------------
$NSXManagerVIPHostname   = "nsx01"
$NSXManagerVIPIP         = "172.30.0.48"
$NSXManagerNode1Hostname = "nsx01a"
$NSXManagerNode1IP       = "172.30.0.49"
# Add Node2/Node3 below only if the existing cluster has more than 1 node
$NSXManagerNode2Hostname = ""
$NSXManagerNode2IP       = ""
$NSXManagerNode3Hostname = ""
$NSXManagerNode3IP       = ""

$NSXManagerAdminPassword = "VMware1!VMware1!"   # the EXISTING admin password, not a new one
$NSXLicense              = ""

# Per-cluster NSX transport/overlay configuration (still required even when
# sharing an existing NSX Manager, since this is unique to the new cluster)
$GeneveVlanId    = 60
$NSXIpPoolName   = "vcf-w01-cl01-tep01"
$NSXIpPoolCidr   = "172.30.60.0/24"
$NSXIpPoolGateway = "172.30.60.1"
$NSXIpPoolRangeStart = "172.30.60.30"
$NSXIpPoolRangeEnd   = "172.30.60.40"
