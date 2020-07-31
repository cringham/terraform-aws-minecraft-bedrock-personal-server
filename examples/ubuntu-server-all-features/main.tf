# This example has automatic snapshots enabled, server whitelist enabled, server properties + other config enabled, and auto-start for the minecraft server enabled

locals {
  region = "us-east-1"
}

provider "aws" {
  version = "~> 2.0"
  region  = local.region
}

#########
# Module
#########
module "minecraft_server" {
  source = "./../../terraform-aws-minecraft-bedrock-personal-server"

  # VPC
  vpc_cidr = "172.16.0.0/24"

  # EC2
  instance_type     = "t2.micro" # pick one to fit your usage
  instance_key_pair = "<your EC2 keypair name>"
  ami_id            = "ami-0ac80df6eff0e70b5" # ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-20200611
  snapshot_config = {
    hour_interval = 24
    time          = "08:45" # 8:45am UTC / 4:45am EDT
    retain        = 7
  }
  ingress = {
    ssh = {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_block  = "<your home IP>/32"
      description = "<your name>"
    }
    icmp = {
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_block  = "<your home IP>/32"
      description = "<your name>"
    }
  }

  # Server init
  ssh_private_key_filepath    = "C:/Users/<you>/.ssh/<your private key>.pem"
  server_package_filepath     = "./files/bedrock-server-1.16.1.02.zip"
  server_properties_filepath  = "./files/server.properties"
  server_whitelist_filepath   = "./files/whitelist.json"
  server_permissions_filepath = "./files/permissions.json"

  # Tag
  tag_postfix = "my-server"
}

#########
# Output
#########
output "instance_public_ip" {
  value = module.minecraft.instance_public_ip
}
