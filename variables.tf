######
# VPC
######
variable "vpc_cidr" {
  type        = string
  description = "The VPC CIDR to provision."
}

######
# EC2
######
variable "instance_key_pair" {
  type        = string
  description = "The instance key pair to associate with the instance."
}
variable "ami_id" {
  type        = string
  description = "The AMI to use for instance provisioning. Expecting a Ubuntu 18 based AMI."
}
variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "The instance type of the EC2 instance."
}

variable "ssh_private_key_filepath" {
  type        = string
  description = "The filepath to your local private SSH key associated with your AWS instance keypair. Necessary for running server init-related tasks upon provisioning."
}
variable "server_package_filepath" {
  type        = string
  default     = ""
  description = "If given a value, will unzip and install the server package given."
}
variable "server_properties_filepath" {
  type        = string
  default     = ""
  description = "If given a value, will overwrite the `server.properties` file of the server with the content of your file. See the `bedrock_server_how_to.html` file that is zipped in the server package under `~/files` for valid values and syntax."
}
variable "server_whitelist_filepath" {
  type        = string
  default     = ""
  description = "If given a value, will overwrite the `whitelist.json` file of the server with the content of your file. See the `bedrock_server_how_to.html` file that is zipped in the server package under `~/files` for valid values and syntax."
}
variable "server_permissions_filepath" {
  type        = string
  default     = ""
  description = "If given a value, will overwrite the `permissions.json` file of the server with the content of your file. See the `bedrock_server_how_to.html` file that is zipped in the server package under `~/files` for valid values and syntax."
}
variable "start_server" {
  type        = bool
  default     = true
  description = "If set to false, the server will not be automatically started upon provisioning."
}

variable "snapshot_config" {
  type = object({
    hour_interval = number
    time          = string
    retain        = number
  })
  default = {
    hour_interval = -1
    time          = ""
    retain        = -1
  }
  description = "If given values, automatic snapshots will be kept on the instance with the given schedule and number to retain. Give military time, i.e \"23:45\" for 11:45pm UTC."
}
variable "ingress" {
  type        = map(map(any))
  default     = {}
  description = "A map of maps that describe the instance security group ingresses."
}

######
# Tag
######
variable "tag_postfix" {
  type        = string
  description = "The string to append to resource tags and names."
}
