terraform {
  required_version = ">= 1.4.0"
}

variable "pool" {
  description = "Slurm pool of compute nodes"
  default = []
}

module "openstack" {
  source         = "git::https://github.com/ComputeCanada/magic_castle.git//openstack?ref=13.1.0"
  config_git_url = "https://github.com/ComputeCanada/puppet-magic_castle.git"
  config_version = "13.1.0"

  cluster_name = "neuraldh"
  domain       = "ace-net.training"
  image        = "Rocky-8.7-x64-2023-02"

  instances = {
    mgmt   = { type = "p8-30gb", tags = ["puppet", "mgmt", "nfs"], count = 1 }
    login  = { type = "p8-30gb", tags = ["login", "public", "proxy"], count = 1 }
    node   = { type = "c16-60gb", tags = ["node"], count = 2 }
  }

  # var.pool is managed by Slurm through Terraform REST API.
  # To let Slurm manage a type of nodes, add "pool" to its tag list.
  # When using Terraform CLI, this parameter is ignored.
  # Refer to Magic Castle Documentation - Enable Magic Castle Autoscaling
  pool = var.pool

  volumes = {
    nfs = {
      home     = { size = 4000,type="volumes-ssd"}
      project  = { size = 3072,type="volumes-ec"}
      scratch  = { size = 2048,type="volumes-ec"}
    }
  }

  public_keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIENpmkSafTLSmnYQ+Ukzog9kqKe0M01/OBi6xdr8ww4K cgeroux@sol"]
  
  generate_ssh_key = true

  nb_users = 10
  # Shared password, randomly chosen if blank
  guest_passwd = ""
}

output "accounts" {
  value = module.openstack.accounts
}

output "public_ip" {
  value = module.openstack.public_ip
}

# Uncomment to register your domain name with CloudFlare
module "dns" {
  source           = "git::https://github.com/ComputeCanada/magic_castle.git//dns/cloudflare?ref=13.1.0"
  name             = module.openstack.cluster_name
  domain           = module.openstack.domain
  bastions         = module.openstack.bastions
  public_instances = module.openstack.public_instances
  ssh_private_key  = module.openstack.ssh_private_key
  sudoer_username  = module.openstack.accounts.sudoer.username
}

## Uncomment to register your domain name with Google Cloud
# module "dns" {
#   source           = "./dns/gcloud"
#   project          = "your-project-id"
#   zone_name        = "you-zone-name"
#   name             = module.openstack.cluster_name
#   domain           = module.openstack.domain
#   bastions         = module.openstack.bastions
#   public_instances = module.openstack.public_instances
#   ssh_private_key  = module.openstack.ssh_private_key
#   sudoer_username  = module.openstack.accounts.sudoer.username
# }

output "hostnames" {
  value = module.dns.hostnames
}
