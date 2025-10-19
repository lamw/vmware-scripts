# William Lam
# Example configuring VCF Automation Provider Portal using Terraform Provider for VCFA
# Automates the following configuration from https://williamlam.com/2025/08/ms-a2-vcf-9-0-lab-configuring-vcf-automation.html

terraform {
  required_providers {
    vcfa = {
      source  = "vmware/vcfa"
      version = "~> 1.0.0"
    }
  }
}

# Configure the VMware Cloud Foundation Automation Provider
provider "vcfa" {
  user                 = var.username
  password             = var.password
  auth_type            = "integrated"
  org                  = "System"
  url                  = var.url
  allow_unverified_ssl = true
  logging              = true
  logging_file         = "vcfa.log"
}

# Fetch the VCFA version
data "vcfa_version" "version" {
  condition         = ">= 9.0.0"
  fail_if_not_match = false
}

# Fetch vCenter Server attached to VCFA
data "vcfa_vcenter" "vc" {
  name = replace(var.vcenter_url, "https://", "")
}

# Fetch vSphere Supervisor Cluster attached to vCenter Server
data "vcfa_supervisor" "sv" {
  name       = var.supervisor_name
  vcenter_id = data.vcfa_vcenter.vc.id
}

# Fetch NSX Manager attached to vCenter Server & vSphere Supervisor
data "vcfa_nsx_manager" "nsx" {
  name = replace(var.nsx_manager_url, "https://", "")
}

# Fetch vSphere Supervisor Zone Name
data "vcfa_region_zone" "zone" {
  region_id = vcfa_region.region.id
  name      = var.supervisor_zone_name
}

# Fetch 1st VM Class that will be used within VCFA Region
data "vcfa_region_vm_class" "vm_class1" {
  name      = tolist(var.region_vm_class_names)[0]
  region_id = vcfa_region.region.id
}

# Fetch 2nd VM Class that will be used within VCFA Region
data "vcfa_region_vm_class" "vm_class2" {
  name      = tolist(var.region_vm_class_names)[1]
  region_id = vcfa_region.region.id
}

# Fetch 3rd VM Class that will be used within VCFA Region
data "vcfa_region_vm_class" "vm_class3" {
  name      = tolist(var.region_vm_class_names)[2]
  region_id = vcfa_region.region.id
}

# Fetch 4th VM Class that will be used within VCFA Region
data "vcfa_region_vm_class" "vm_class4" {
  name      = tolist(var.region_vm_class_names)[3]
  region_id = vcfa_region.region.id
}

# Fetch VM Storage Policy for use by VCFA Region
data "vcfa_region_storage_policy" "region-sc" {
  name      = tolist(var.region_storage_policy_names)[0]
  region_id = vcfa_region.region.id
}

# Create VCFA Region
resource "vcfa_region" "region" {
  name                 = var.region_name
  nsx_manager_id       = data.vcfa_nsx_manager.nsx.id
  supervisor_ids       = [data.vcfa_supervisor.sv.id]
  storage_policy_names = var.region_storage_policy_names
}

# Create VCFA Org
resource "vcfa_org" "org" {
  name         = var.org_name
  display_name = var.org_name
  description  = "${var.org_name} Organization"
  is_enabled   = true
}

# Create VCFA Region Quota
resource "vcfa_org_region_quota" "region_quota" {
  org_id         = vcfa_org.org.id
  region_id      = vcfa_region.region.id
  supervisor_ids = [data.vcfa_supervisor.sv.id]
  zone_resource_allocations {
    region_zone_id         = data.vcfa_region_zone.zone.id
    cpu_limit_mhz          = var.region_quota_cpu_limit_mhz
    cpu_reservation_mhz    = var.region_quota_cpu_reservation_mhz
    memory_limit_mib       = var.region_quota_mem_limit_mb
    memory_reservation_mib = var.region_quota_mem_reservation_mb
  }
  region_vm_class_ids = [
    data.vcfa_region_vm_class.vm_class1.id,
    data.vcfa_region_vm_class.vm_class2.id,
    data.vcfa_region_vm_class.vm_class3.id,
    data.vcfa_region_vm_class.vm_class4.id,
  ]
  region_storage_policy {
    region_storage_policy_id = data.vcfa_region_storage_policy.region-sc.id
    storage_limit_mib        = var.region_quota_storage_limit_mb
  }
}

# Create VCFA Network Logs Label
resource "vcfa_org_networking" "network" {
  org_id   = vcfa_org.org.id
  log_name = lower(var.org_name)
}

# Fetch VCFA Org Admin Role
data "vcfa_role" "org-admin" {
  org_id = vcfa_org.org.id
  name   = "Organization Administrator"
}

# Create First User for VCFA Org
resource "vcfa_org_local_user" "user" {
  org_id   = vcfa_org.org.id
  role_ids = [data.vcfa_role.org-admin.id]
  username = var.org_local_username
  password = var.org_local_password
}

# Fetch NSX Edge Cluster for use with VCFA Region
data "vcfa_edge_cluster" "edge-cluster" {
  name             = var.nsx_edge_cluster_name
  region_id        = vcfa_region.region.id
  sync_before_read = true
}

# Fetch NSX T0 Gateway for use with VCFA Region
data "vcfa_tier0_gateway" "t0-gw" {
  name      = var.tier0_gateway_name
  region_id = vcfa_region.region.id
}

# Create VCFA Edge Cluster QoS
resource "vcfa_edge_cluster_qos" "edge-cluster-qos" {
  edge_cluster_id = data.vcfa_edge_cluster.edge-cluster.id

  egress_committed_bandwidth_mbps  = -1
  egress_burst_size_bytes          = -1
  ingress_committed_bandwidth_mbps = -1
  ingress_burst_size_bytes         = -1
}

# Create VCFA IP Space
resource "vcfa_ip_space" "ipspace" {
  name                          = "${var.org_name}-ipspace"
  description                   = "${var.org_name} IP Space"
  region_id                     = vcfa_region.region.id
  external_scope                = "0.0.0.0/0"
  default_quota_max_subnet_size = var.ipspace_max_subnet_size
  default_quota_max_cidr_count  = var.ipspace_max_cidr_count
  default_quota_max_ip_count    = var.ipspace_max_ip_count

  internal_scope {
    name = "scope1"
    cidr = var.ipspace_scope_cidr1
  }
}
# Create VCFA Provider Gateway
resource "vcfa_provider_gateway" "provider-gw" {
  name             = "${var.org_name}-provider-gw"
  description      = "${var.org_name} Provider Gateway"
  region_id        = vcfa_region.region.id
  tier0_gateway_id = data.vcfa_tier0_gateway.t0-gw.id
  ip_space_ids     = [vcfa_ip_space.ipspace.id]
}

# Create VCFA Regional Networking
resource "vcfa_org_regional_networking" "regional-network" {
  name = "${var.org_name}-regional-network"

  org_id = vcfa_org_networking.network.id

  provider_gateway_id = vcfa_provider_gateway.provider-gw.id
  region_id           = vcfa_region.region.id

  edge_cluster_id = data.vcfa_edge_cluster.edge-cluster.id
}

# Fetch VM Storage Class for use by Content Library in VCFA Region
data "vcfa_storage_class" "sc" {
  region_id = vcfa_region.region.id
  name      = tolist(var.region_storage_policy_names)[0]
}

data "vcfa_org" "system" {
  name = "System"
}

# Create Content Library
resource "vcfa_content_library" "cl" {
  org_id      = data.vcfa_org.system.id
  name        = var.global_content_library_name
  description = var.global_content_library_name
  storage_class_ids = [
    data.vcfa_storage_class.sc.id
  ]
}