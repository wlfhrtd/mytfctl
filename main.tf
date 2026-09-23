resource "libvirt_volume" "machine" {
  for_each = local.hosts

  name     = "${each.value.vm_name}.qcow2"
  pool     = "default"
  capacity = 20 * 1024 * 1024 * 1024

  target = {
    format = {
      type = "qcow2"
    }
  }

  backing_store = {
    path = "/vmstore/libvirt/images/golden-server-ubuntu.qcow2"

    format = {
      type = "qcow2"
    }
  }
}

resource "libvirt_cloudinit_disk" "machine" {
  for_each = local.hosts

  name = "${each.value.vm_name}-seed.iso"

  meta_data = <<-EOF
    instance-id: ${each.key}
  EOF

  user_data = templatefile("${path.module}/cloud-init/user-data.yaml.tftpl", {
    bootstrap_password = var.bootstrap_password
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yaml.tftpl", {
    ip = each.value.ip
  })
}

resource "libvirt_volume" "machine_seed" {
  for_each = local.hosts

  name = "${each.value.vm_name}-seed.iso"
  pool = "seeds"

  create = {
    content = {
      url = libvirt_cloudinit_disk.machine[each.key].path
    }
  }

  target = {
    format = {
      type = "iso"
    }
  }
}

resource "libvirt_domain" "machine" {
  for_each = local.hosts

  autostart = false
  clock = {
    offset = "utc"
    timer = [
      {
        name        = "rtc"
        tick_policy = "catchup"
      },
      {
        name        = "pit"
        tick_policy = "delay"
      },
      {
        name    = "hpet"
        present = "no"
      },
    ]
  }
  cpu = {
    check = "none"
    mode  = "host-passthrough"
  }
  current_memory      = each.value.memory * 1024
  current_memory_unit = "KiB"
  devices = {
    audios = [
      {
        id    = 1
        spice = {}
      },
    ]
    channels = [
      {
        address = {}
        source = {
          null      = false
          spice_vmc = false
          std_io    = false
          unix      = {}
          vc        = false
        }
        target = {
          virt_io = {
            name = "org.qemu.guest_agent.0"
          }
        }
      },
      {
        address = {}
        source = {
          null      = false
          spice_vmc = true
          std_io    = false
          vc        = false
        }
        target = {
          virt_io = {
            name = "com.redhat.spice.0"
          }
        }
      },
    ]
    consoles = [
      {
        source = {
          null = false
          pty = {
            path      = ""
            sec_label = null
          }
          spice_vmc = false
          std_io    = false
          vc        = false
        }
        target = {
          port = 0
          type = "serial"
        }
      },
    ]
    controllers = [
      {
        address = {}
        index   = 0
        model   = "qemu-xhci"
        type    = "usb"
        usb = {
          port = 15
        }
      },
      {
        index = 0
        model = "pcie-root"
        pci   = {}
        type  = "pci"
      },
      {
        address = {}
        index   = 1
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 2
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 3
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 4
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 5
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 6
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 7
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 8
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 9
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 10
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 11
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 12
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 13
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 14
        model   = "pcie-root-port"
        pci = {
          model = {
            name = "pcie-root-port"
          }
          target = {}
        }
        type = "pci"
      },
      {
        address = {}
        index   = 0
        type    = "sata"
      },
      {
        address        = {}
        index          = 0
        type           = "virtio-serial"
        virt_io_serial = {}
      },
    ]
    disks = [
      {
        address = {}
        device  = "disk"
        driver = {
          discard = "unmap"
          name    = "qemu"
          type    = "qcow2"
        }
        read_only = false
        shareable = false
        source = {
          file = {
            file = libvirt_volume.machine[each.key].path
          }
        }
        target = {
          bus = "virtio"
          dev = "vda"
        }
      },
      {
        address = {}
        device  = "cdrom"
        driver = {
          name = "qemu"
          type = "raw"
        }
        read_only = true
        shareable = false
        source = {
          file = {
            file = libvirt_volume.machine_seed[each.key].path
          }
        }
        target = {
          bus = "sata"
          dev = "sda"
        }
      },
    ]
    emulator = "/usr/bin/qemu-system-x86_64"
    graphics = [
      {
        spice = {
          image = {
            compression = "off"
          }
          listeners = [
            {},
          ]
        }
      },
    ]
    inputs = [
      {
        address = {}
        bus     = "usb"
        source  = {}
        type    = "tablet"
      },
      {
        bus    = "ps2"
        source = {}
        type   = "mouse"
      },
      {
        bus    = "ps2"
        source = {}
        type   = "keyboard"
      },
    ]
    interfaces = [
      {
        address = {}
        model = {
          type = "virtio"
        }
        source = {
          network = {
            network = "lab-net"
          }
          null = false
        }
      },
    ]
    mem_balloon = {
      address = {}
      model   = "virtio"
    }
    redir_devs = [
      {
        address = {}
        bus     = "usb"
        source = {
          null      = false
          spice_vmc = true
          std_io    = false
          vc        = false
        }
      },
      {
        address = {}
        bus     = "usb"
        source = {
          null      = false
          spice_vmc = true
          std_io    = false
          vc        = false
        }
      },
    ]
    rngs = [
      {
        address = {}
        backend = {
          built_in = false
          random   = "/dev/urandom"
        }
        model = "virtio"
      },
    ]
    serials = [
      {
        source = {
          null = false
          pty = {
            path      = ""
            sec_label = null
          }
          spice_vmc = false
          std_io    = false
          vc        = false
        }
        target = {
          model = {
            name = "isa-serial"
          }
          port = 0
          type = "isa-serial"
        }
      },
    ]
    videos = [
      {
        address = {}
        model = {
          device  = "virtio-vga"
          heads   = 1
          primary = "yes"
          type    = "virtio"
        }
      },
    ]
    watchdogs = [
      {
        action = "reset"
        model  = "itco"
      },
    ]
  }
  features = {
    acpi           = true
    apic           = {}
    pae            = false
    priv_net       = false
    viridian       = false
    virtualization = false
    vm_port = {
      state = "off"
    }
  }
  memory      = each.value.memory * 1024
  memory_unit = "KiB"
  metadata = {
    xml = "\n    <libosinfo:libosinfo xmlns:libosinfo=\"http://libosinfo.org/xmlns/libvirt/domain/1.0\">\n      <libosinfo:os id=\"http://ubuntu.com/ubuntu/26.04\"/>\n    </libosinfo:libosinfo>\n  "
  }
  name        = each.value.vm_name
  on_crash    = "destroy"
  on_poweroff = "destroy"
  on_reboot   = "restart"
  os = {
    boot_devices = [
      {
        dev = "hd"
      },
    ]
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc-q35-11.0"
  }
  pm = {
    suspend_to_disk = {
      enabled = "no"
    }
    suspend_to_mem = {
      enabled = "no"
    }
  }
  running        = false
  type           = "kvm"
  vcpu           = each.value.vcpu
  vcpu_placement = "static"
}
