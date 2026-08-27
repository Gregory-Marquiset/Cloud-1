variable "instances" {
  description = "VMs cibles : nom => identifiant Proxmox et adresse fixe"
  type = map(object({
    vm_id = number
    ip    = string
  }))
  default = {
    "cloud-1-srv-1" = { vm_id = 130, ip = "192.168.1.210/24" }
    "cloud-1-srv-2" = { vm_id = 131, ip = "192.168.1.211/24" }
  }
}
variable "gateway" {
  type    = string
  default = "192.168.1.254"
}
variable "dns_servers" {
  type    = list(string)
  default = ["192.168.1.254", "1.1.1.1"]
}
variable "node_name" {
  description = "Nom du node Proxmox"
  type        = string
  default     = "marquis"
}
variable "cores" {
  description = "vCPU par VM"
  type        = number
  default     = 2
}
variable "memory" {
  description = "RAM par VM"
  type        = number
  default     = 2048
}
variable "disk_size" {
  description = "Taille du disque par VM"
  type        = number
  default     = 20
}
variable "datastore_id" {
  description = "ID du datastore Proxmox"
  type        = string
  default     = "local-lvm"
}
variable "image_datastore" {
  description = "Datastore contenant l'image ISO"
  type        = string
  default     = "local"
}
variable "bridge" {
  description = "Nom du bridge réseau"
  type        = string
  default     = "vmbr0"
}
variable "ssh_public_key" {
  description = "Clé publique SSH pour l'accès aux VMs"
  type        = string
}
