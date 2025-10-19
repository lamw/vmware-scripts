# VCF Automation Information
url      = "https://auto01.vcf.lab"
username = "admin"
password = "VMware1!VMware1!"

# vCenter Server Information
vcenter_url          = "https://vc01.vcf.lab"
vcenter_username     = "administrator@vsphere.local"
vcenter_password     = "VMware1!VMware1!"
vcenter_storage_policy_names = ["vcf-vsan-esa-policy"]

# NSX Manager Inforation
nsx_manager_url      = "https://nsx01.vcf.lab"
nsx_manager_username = "admin"
nsx_manager_password = "VMware1!VMware1!"
tier0_gateway_name = "transit-gw"
nsx_edge_cluster_name = "ec-01"

# vSphere Supervisor Information
supervisor_name = "sv-01"
supervisor_zone_name = "vz-01"

# Region Configuration
region_storage_policy_names = ["vcf-vsan-esa-policy"]
region_vm_class_names = ["best-effort-large", "best-effort-medium", "best-effort-small", "best-effort-xsmall"]

#### --- Start Custom Variables from William Lam --- ####

# Name of VCFA Organization
org_name = "Legal"

# First User for VCFA Organization
org_local_username = "admin"
org_local_password = "VMware1!VMware1!"

# Name of VCFA Region
region_name = "west"

# Regional Quota Configuration
region_quota_cpu_limit_mhz = 85000
region_quota_cpu_reservation_mhz = 0
region_quota_mem_limit_mb = 450000
region_quota_mem_reservation_mb = 0
region_quota_storage_limit_mb = 48000

# IP Space Configuration
ipspace_scope_cidr1 = "31.32.0.0/16"
ipspace_max_subnet_size = 28
ipspace_max_cidr_count = 5
ipspace_max_ip_count = 5

# Name of VCFA Global Content Library
global_content_library_name = "Shared Content Library"

