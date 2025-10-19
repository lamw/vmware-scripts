variable "region_name" {
  description = "Name of VCFA Region"
  type        = string
}

variable "org_name" {
  description = "Name of VCFA Organization"
  type        = string
}

variable "ipspace_scope_cidr1" {
  description = "IP Space Scope CIDR 1"
  type        = string
}

variable "ipspace_max_subnet_size" {
  description = "IP Space Max Subnet Size"
  type        = number
}

variable "ipspace_max_cidr_count" {
  description = "IP Space Max CIDR Count"
  type        = number
}

variable "ipspace_max_ip_count" {
  description = "IP Space Max IP Count"
  type        = number
}

variable "region_quota_cpu_limit_mhz" {
  description = "Region Quota CPU Limit"
  type        = number
}

variable "region_quota_cpu_reservation_mhz" {
  description = "Region Quota CPU Reservation"
  type        = number
}

variable "region_quota_mem_limit_mb" {
  description = "Region Quota Mem Limit "
  type        = number
}

variable "region_quota_mem_reservation_mb" {
  description = "Region Quota Mem Reservation"
  type        = number
}

variable "region_quota_storage_limit_mb" {
  description = "Region Quota Storage Limit"
  type        = number
}

variable "org_local_username" {
  description = "Username for local org user"
  type        = string
}

variable "org_local_password" {
  description = "Password for local org user"
  type        = string
  sensitive   = true
}

variable "global_content_library_name" {
  description = "Name of VCFA Global Content Library"
  type        = string
}