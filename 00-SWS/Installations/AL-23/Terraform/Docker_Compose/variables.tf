#############################   Common Variables   ###############################################################
variable "project_name" { default = "expense" }
variable "env" { default = "dev" }

variable "common_tags" {
  default = {
    Project     = "expense"
    Environment = "dev"
    Terraform   = "true"
  }
}
##################################################################################################################
variable "ami_id" {}
variable "public_key_name" {}
variable "instance_type" {} # t2.micro / t2.small / t2.medium  only ( our ec2 module allows these 3 types only )
##################################################################################################################

variable "vpc_id" {}
variable "subnet_id" {}
variable "private_key_path" {}
