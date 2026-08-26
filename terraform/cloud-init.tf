resource "proxmox_virtual_environment_file" "cloud_init" {
  for_each = var.instances

  content_type = "snippets"
  datastore_id = var.image_datastore
  node_name    = var.node_name

  source_raw {
    file_name = "${each.key}-user-data.yaml"
    data      = <<-CLOUDCFG
      #cloud-config
      hostname: ${each.key}
      users:
        - default
        - name: ubuntu
          groups: [sudo]
          shell: /bin/bash
          sudo: "ALL=(ALL) NOPASSWD:ALL"
          ssh_authorized_keys:
            - ${var.ssh_public_key}
      package_update: true
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
    CLOUDCFG
  }
}
