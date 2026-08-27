resource "proxmox_download_file" "ubuntu_2204" {
  content_type = "import"
  datastore_id = var.image_datastore
  node_name    = var.node_name
  url          = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  file_name    = "jammy-server-cloudimg-amd64.qcow2"
  overwrite    = false
}
resource "proxmox_virtual_environment_vm" "cloud1" {
  for_each  = var.instances
  name      = each.key
  vm_id     = each.value.vm_id
  node_name = var.node_name
  tags      = ["cloud-1", "terraform"]
  agent {
    enabled = true
  }
  cpu {
    cores = var.cores
    type  = "host"
  }
  memory {
    dedicated = var.memory
  }
  disk {
    datastore_id = var.datastore_id
    import_from  = proxmox_download_file.ubuntu_2204.id
    interface    = "scsi0"
    size         = var.disk_size
  }
  initialization {
    datastore_id      = var.datastore_id
    user_data_file_id = proxmox_virtual_environment_file.cloud_init[each.key].id
    dns {
      servers = var.dns_servers
    }
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway
      }
    }
  }
  network_device {
    bridge = var.bridge
  }
  operating_system {
    type = "l26"
  }
}
locals {
  vm_ips = {
    for name, cfg in var.instances : name => split("/", cfg.ip)[0]
  }
}
