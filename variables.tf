variable "hosts" {
  description = "Hosts to be created"

  type = map(object({
    ip     = string
    memory = number
    vcpu   = number
  }))

  validation {
    condition = alltrue([
      for host in var.hosts :
      can(cidrhost("${host.ip}/32", 0))
    ])
    error_message = "Each host must have a valid IPv4 address."
  }

  validation {
    condition = alltrue([
      for name in keys(var.hosts) :
      can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", name))
    ])
    error_message = "Host names must contain only lowercase letters, digits and hyphens, be 1-63 characters long, and not start or end with a hyphen."
  }

  validation {
    condition = alltrue([
      for host in var.hosts :
      host.memory >= 512 && host.memory <= 131072
    ])
    error_message = "Memory must be between 512 and 131072 MiB."
  }

  validation {
    condition = alltrue([
      for host in var.hosts :
      host.vcpu >= 1 && host.vcpu <= 64
    ])
    error_message = "vCPU count must be between 1 and 64."
  }
}

variable "bootstrap_password" {
  type      = string
  sensitive = true
}

variable "vm_name_prefix" {
  description = "Prefix used for libvirt VM and disk names"
  type        = string

  default = "lab"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.vm_name_prefix))
    error_message = "VM name prefix must contain only lowercase letters, digits and hyphens."
  }
}

variable "vm_name_suffix" {
  description = "Suffix used for libvirt VM and disk names"
  type        = string

  default = "ubuntu"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.vm_name_suffix))
    error_message = "VM name suffix must contain only lowercase letters, digits and hyphens."
  }
}
