locals {
  server_package_install_dir = "bedrock-server-1.14.60.5"
  server_package_filename    = "bedrock-server-1.14.60.5.zip"
  enable_snapshots           = var.snapshot_config.hour_interval != -1 && var.snapshot_config.time != "" && var.snapshot_config.retain != -1
}

######
# VPC
######
resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "minecraft-${var.tag_postfix}"
  }
}

#########
# Subnet
#########
data "aws_availability_zones" "this" {
  state = "available"
}

resource "aws_subnet" "this" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 0, 0)
  availability_zone = data.aws_availability_zones.this.names[0]

  tags = {
    Name = "minecraft-${var.tag_postfix}-1a"
  }
}

######
# IGW
######
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "minecraft-${var.tag_postfix}"
  }
}

########
# Route
########
resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "minecraft-${var.tag_postfix}"
  }
}

resource "aws_route_table_association" "this" {
  subnet_id      = aws_subnet.this.id
  route_table_id = aws_route_table.this.id
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

#################
# Security Group
#################
resource "aws_security_group" "this" {
  name        = "minecraft-${var.tag_postfix}"
  description = "Main security group for Minecraft server."
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "minecraft-${var.tag_postfix}"
  }

  lifecycle {
    ignore_changes = [ingress, egress]
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each = var.ingress

  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = [each.value.cidr_block]
  description       = each.value.description
}

resource "aws_security_group_rule" "server_tcp_ipv4" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 19132
  to_port           = 19132
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Server TCP IPv4"
}

resource "aws_security_group_rule" "server_tcp_ipv6" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 19133
  to_port           = 19133
  protocol          = "tcp"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "Server TCP IPv6"
}

resource "aws_security_group_rule" "server_udp_ipv4" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 19132
  to_port           = 19132
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Server UDP IPv4"
}

resource "aws_security_group_rule" "server_udp_ipv6" {
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  from_port         = 19133
  to_port           = 19133
  protocol          = "udp"
  ipv6_cidr_blocks  = ["::/0"]
  description       = "Server UDP IPv6"
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  description       = "All traffic"
}

######
# EC2
######
resource "aws_eip" "this" {
  vpc = true
}

resource "aws_eip_association" "this" {
  allocation_id = aws_eip.this.id
  instance_id   = aws_instance.this.id
}

resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.this.id
  key_name      = var.instance_key_pair
  volume_tags = {
    Name = "minecraft-${var.tag_postfix}-1a"
  }

  tags = {
    Name = "minecraft-${var.tag_postfix}-1a"
  }
}

resource "aws_network_interface_sg_attachment" "this" {
  security_group_id    = aws_security_group.this.id
  network_interface_id = aws_instance.this.primary_network_interface_id
}

###########
# Snapshot
###########
resource "aws_iam_role" "dlm_lifecycle_role" {
  count = local.enable_snapshots ? 1 : 0

  name = "dlm-lifecycle-role-${var.tag_postfix}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "dlm.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  count = local.enable_snapshots ? 1 : 0

  name = "dlm-lifecycle-policy"
  role = aws_iam_role.dlm_lifecycle_role[0].id

  policy = <<EOF
{
   "Version": "2012-10-17",
   "Statement": [
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateSnapshot",
            "ec2:DeleteSnapshot",
            "ec2:DescribeVolumes",
            "ec2:DescribeSnapshots"
         ],
         "Resource": "*"
      },
      {
         "Effect": "Allow",
         "Action": [
            "ec2:CreateTags"
         ],
         "Resource": "arn:aws:ec2:*::snapshot/*"
      }
   ]
}
EOF
}

resource "aws_dlm_lifecycle_policy" "example" {
  count = local.enable_snapshots ? 1 : 0

  description        = "minecraft-${var.tag_postfix} DLM lifecycle policy"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role[0].arn

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "minecraft-${var.tag_postfix}-snapshot-schedule"

      create_rule {
        interval      = var.snapshot_config.hour_interval
        interval_unit = "HOURS"
        times         = [var.snapshot_config.time]
      }

      retain_rule {
        count = var.snapshot_config.retain
      }

      tags_to_add = {
        creator = "dlm"
      }
    }

    target_tags = {
      Name = "${aws_instance.this.tags["Name"]}"
    }
  }
}

##############
# Server Init
##############
resource "null_resource" "install_server" {
  count = var.server_package_filepath != "" ? 1 : 0

  connection {
    type        = "ssh"
    host        = aws_eip.this.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_filepath)
  }

  provisioner "file" {
    source      = var.server_package_filepath
    destination = "~/${local.server_package_filename}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt install unzip",
      "mkdir ${local.server_package_install_dir}",
      "unzip ${local.server_package_filename} -d ${local.server_package_install_dir}"
    ]
  }

  depends_on = [aws_instance.this, aws_eip_association.this, aws_network_interface_sg_attachment.this]
}

resource "null_resource" "config_properties" {
  count = var.server_properties_filepath != "" ? 1 : 0

  triggers = {
    hash_changesum = sha1(file(var.server_properties_filepath))
  }

  connection {
    type        = "ssh"
    host        = aws_eip.this.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_filepath)
  }

  provisioner "remote-exec" {
    inline = [
      "cd ~/${local.server_package_install_dir}",
      "echo '${file(var.server_properties_filepath)}' > server.properties"
    ]
  }

  depends_on = [null_resource.install_server]
}

resource "null_resource" "config_whitelist" {
  count = var.server_whitelist_filepath != "" ? 1 : 0

  triggers = {
    hash_changesum = sha1(file(var.server_whitelist_filepath))
  }

  connection {
    type        = "ssh"
    host        = aws_eip.this.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_filepath)
  }

  provisioner "remote-exec" {
    inline = [
      "cd ~/${local.server_package_install_dir}",
      "echo '${file(var.server_whitelist_filepath)}' > whitelist.json"
    ]
  }

  depends_on = [null_resource.install_server]
}

resource "null_resource" "config_permissions" {
  count = var.server_permissions_filepath != "" ? 1 : 0

  triggers = {
    hash_changesum = sha1(file(var.server_permissions_filepath))
  }

  connection {
    type        = "ssh"
    host        = aws_eip.this.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_filepath)
  }

  provisioner "remote-exec" {
    inline = [
      "cd ~/${local.server_package_install_dir}",
      "echo '${file(var.server_permissions_filepath)}' > permissions.json"
    ]
  }

  depends_on = [null_resource.install_server]
}

resource "null_resource" "start_server" {
  count = var.start_server ? 1 : 0

  connection {
    type        = "ssh"
    host        = aws_eip.this.public_ip
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_filepath)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt install screen",
      "touch ~/.screenrc",
      "echo 'startup_message off' > ~/.screenrc",
      "cd ~/${local.server_package_install_dir}",
      "screen -dmS minecraft bash -c 'LD_LIBRARY_PATH=. ./bedrock_server'",
      "sleep 10" # Allow time for process startup
    ]
  }

  depends_on = [null_resource.install_server]
}

#########
# Output
#########
output "instance_public_ip" {
  value = aws_instance.this.public_ip
}
