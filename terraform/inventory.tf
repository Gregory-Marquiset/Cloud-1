resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/hosts.yml"
  file_permission = "0644"

  content = yamlencode({
    cloud1 = {
      hosts = {
        for name, ip in local.vm_ips :
        name => { ansible_host = ip }
      }
      vars = {
        ansible_user = "ubuntu"
      }
    }
  })
}