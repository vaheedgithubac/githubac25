module "docker_sg" {
  source         = "git::https://github.com/vaheedgithubac/Infra.git//modules/security_group"
  vpc_id         = var.vpc_id #local.vpc_id
  sg_name        = "docker_sg"
  sg_description = "Docker Security Group"

  project_name = var.project_name
  env          = var.env
  common_tags  = var.common_tags
}

# Docker should be accessed from office n/w   0.0.0.0/0 ---> jenkins
resource "aws_security_group_rule" "docker_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.docker_sg.sg_id
}

# Docker should be accessed from office n/w   0.0.0.0/0 ---> bastion
resource "aws_security_group_rule" "docker_public" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.docker_sg.sg_id
}


module "docker_ec2" {
  source = "git::https://github.com/vaheedgithubac/Infra.git//modules/ec2"

  ami_id                      = var.ami_id
  instance_type               = var.instance_type
  public_key_name             = var.public_key_name
  sg_id                       = [module.docker_sg.sg_id] #[local.sg_id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  what_type_instance          = "docker"

  # user_data = file("${path.module}/ansible_setup.sh")

  # is_nat_instance             = var.is_nat_instance  # creates NAT instance if true


  project_name = var.project_name
  env          = var.env
  common_tags  = var.common_tags
}


resource "null_resource" "docker_provisioner" {
  depends_on = [module.docker_ec2]

  # Changes to any instance of the instance requires re-provisioning
  triggers = {
    instance_id = module.docker_ec2.ec2_instance.id
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = module.docker_ec2.ec2_instance.private_ip
    private_key = file(var.private_key_path)
    timeout     = "5m"
  }

  provisioner "local-exec" {
    # echo "\${module.jenkins_ec2.ec2_instance.public_ip} ansible_user=ec2-user ansible_ssh_private_key_file=\${var.private_key_path}" >> inventory.ini

    command = <<-EOT
      echo "Docker and Docker Compose installation started..."
      ansible-playbook -i ${module.docker_ec2.ec2_instance.private_ip}, docker_compose_setup.yml
    EOT
  }
}
