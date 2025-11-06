module "tomcat_sg" {
  source         = "git::https://github.com/vaheedgithubac/Infra.git//modules/security_group"
  vpc_id         = var.vpc_id #local.vpc_id
  sg_name        = "tomcat_sg"
  sg_description = "Tomcat Security Group"

  project_name = var.project_name
  env          = var.env
  common_tags  = var.common_tags
}

# Tomcat should be accessed from office n/w   0.0.0.0/0 ---> Tomcat
resource "aws_security_group_rule" "tomcat_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.tomcat_sg.sg_id
}

# Tomcat should be accessed from office n/w   0.0.0.0/0 ---> Tomcat
resource "aws_security_group_rule" "tomcat_public" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.tomcat_sg.sg_id
}

module "tomcat_ec2" {
  source = "git::https://github.com/vaheedgithubac/Infra.git//modules/ec2"

  ami_id                      = var.ami_id
  instance_type               = var.instance_type
  public_key_name             = var.public_key_name
  sg_id                       = [module.tomcat_sg.sg_id] #[local.sg_id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  what_type_instance          = "tomcat"

  user_data = file("${path.module}/ansible_setup.sh")

  # is_nat_instance             = var.is_nat_instance  # creates NAT instance if true


  project_name = var.project_name
  env          = var.env
  common_tags  = var.common_tags
}


resource "null_resource" "tomcat_provisioner" {
  depends_on = [module.tomcat_ec2]

  # Changes to any instance of the instance requires re-provisioning
  triggers = {
    instance_id = module.tomcat_ec2.ec2_instance.id
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = module.tomcat_ec2.ec2_instance.private_ip
    private_key = file(var.private_key_path)
    timeout     = "5m"
  }

  # Generate Ansible inventory and run playbook
  #provisioner "local-exec" {
  #  command = <<EOT
  #    echo "[jenkins]" > inventory.ini
  #    echo "${aws_instance.jenkins.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${var.private_key_path}" >> inventory.ini
  #    ansible-playbook -i inventory.ini install_jenkins.yml
  #  EOT
  #}

  provisioner "local-exec" {
    command = <<EOT
      echo "Tomcat installation started..."
      ansible-playbook -i ${module.tomcat_ec2.ec2_instance.private_ip}, tomcat_setup.yml
    EOT
  }
}
