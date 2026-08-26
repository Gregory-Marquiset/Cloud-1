provider "proxmox" {
  ssh {
    agent       = false
    username    = "terraform"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
  }
}