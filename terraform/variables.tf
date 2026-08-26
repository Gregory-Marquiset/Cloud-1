variable "instances" {
  description = "VMs cibles :  nom => id Proxmox"
  type        = map(number)
  default = {
    "cloud-1-srv-1" = 130
    "cloud-1-srv-2" = 131
  }
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
