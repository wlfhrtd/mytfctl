locals {
  hosts = {
    for name, config in var.hosts : name => merge(config, {
      vm_name = "${var.vm_name_prefix}-${name}-${var.vm_name_suffix}"
    })
  }
}
