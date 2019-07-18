variable "parent_zone" {}

provider "aws" {
  region = "us-east-1"
}

locals {
  fully_qualified_parent_zone = "${var.parent_zone}."
  name                        = "ec2-route53-demo"
}

data "aws_route53_zone" "parent" {
  name = local.fully_qualified_parent_zone
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.parent.id
  name    = "demo"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.instance.public_ip]
}

resource "aws_instance" "instance" {
  ami             = "ami-0a01a5636f3c4f21c" # OmniOS r151030
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.security_group.name]
  key_name        = aws_key_pair.key_pair.key_name


  tags = {
    Name = local.name
  }
}

resource "null_resource" "instance" {

  triggers = {
    instance = aws_instance.instance.id
  }

  connection {
    host = aws_instance.instance.public_ip
  }

  provisioner "remote-exec" {
    # Tell the host what its domain name is 
    inline = [format("hostname -s %s", aws_route53_record.record.fqdn)]
  }

}

resource "aws_key_pair" "key_pair" {
  key_name   = local.name
  public_key = file(pathexpand("~/.ssh/id_rsa.pub"))
}

resource "aws_security_group" "security_group" {
  name        = local.name
  description = "SSH for ec2-route53-demo"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.name
  }
}
