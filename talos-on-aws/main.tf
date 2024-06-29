# Data 
data "cloudflare_zone" "tanukiops" {
  name = "tanukiops.org"
}


data "aws_availability_zone" "eu-west-3a" {
  name = "eu-west-3a"
}
data "aws_availability_zone" "eu-west-3b" {
  name = "eu-west-3b"
}
data "aws_availability_zone" "eu-west-3c" {
  name = "eu-west-3c"
}
# Create vpc
resource "aws_vpc" "talos-vpc" {
  cidr_block = "10.10.0.0/16"
  tags = {
    Name = "talos-vpc"
  }
}
# Create subnet(s)
resource "aws_subnet" "talos-az1" {
  vpc_id            = aws_vpc.talos-vpc.id
  cidr_block        = "10.10.0.0/24"
  availability_zone = data.aws_availability_zone.eu-west-3a.id
  tags = {
    Name = "talos-az1"
  }
}
resource "aws_subnet" "talos-az2" {
  vpc_id            = aws_vpc.talos-vpc.id
  cidr_block        = "10.10.1.0/24"
  availability_zone = data.aws_availability_zone.eu-west-3b.id
  tags = {
    Name = "talos-az2"
  }
}
resource "aws_subnet" "talos-az3" {
  vpc_id            = aws_vpc.talos-vpc.id
  cidr_block        = "10.10.2.0/24"
  availability_zone = data.aws_availability_zone.eu-west-3c.id
  tags = {
    Name = "talos-az3"
  }
}
# create sg

resource "aws_security_group" "talos-sg" {
  name        = "talos-sg"
  description = "sg to allow ssh from home"
  vpc_id      = aws_vpc.talos-vpc.id
  tags = {
    Name = "talos-sg"
  }
}
#allow communication in the security group
resource "aws_vpc_security_group_ingress_rule" "allow-cluster-communication" {
  security_group_id            = aws_security_group.talos-sg.id
  referenced_security_group_id = aws_security_group.talos-sg.id
  from_port                    = 0
  ip_protocol                  = "all"
  to_port                      = 0
}
#expose talos and kube api to home ip
resource "aws_vpc_security_group_ingress_rule" "allow-kube-api-access" {
  security_group_id = aws_security_group.talos-sg.id
  cidr_ipv4         = var.home_ip
  from_port         = 6443
  ip_protocol       = "all"
  to_port           = 6443
}
resource "aws_vpc_security_group_ingress_rule" "allow-talos-api-access" {
  security_group_id = aws_security_group.talos-sg.id
  cidr_ipv4         = var.home_ip
  from_port         = 50000
  ip_protocol       = "tcp"
  to_port           = 50001
}
# create keypair
resource "aws_key_pair" "tvaneerdewegh" {
  key_name   = "tvaneerdewegh"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9NL4EhmSEhyaKt8fDybkRtvL/g1+hKBqL1Qp5/OOK5peGHAr2VGBvFMLM4FT+F6Q7w7IX0JXFs24smi76vnmFtFdTBZxWivsDpznFVKcQCfq/ZnBL2lEGRlchW/ZLAjWV8XpFMoybWlvaPd18m2n11FYKl0oFdn47j9UIxuofk0cp+0/QiVjrqFRD4shTAAeKH1vHnNCS+KbsBWJNZ9sO0V3l7kKyMlD2K+qfv7SGH0YHcj1+eEG/YAhDInF770yTziXy5HTGgecry+Iyh2Ck4vcLyPnHI8OHTvgFu1Xl3VQxYlaAIXBG1NPb3F6gfOF1dXOadzzt+HDHDKqonOXj tim.vaneerdewegh@uantwerpen.be"
}
# load balancer 
resource "aws_lb" "talos-lb" {
  name               = "talos-lb"
  load_balancer_type = "network"
  security_groups    = [aws_security_group.talos-sg.id]
  subnet_mapping {
    subnet_id = aws_subnet.talos-az1.id
  }
  subnet_mapping {
    subnet_id = aws_subnet.talos-az2.id
  }
  subnet_mapping {
    subnet_id = aws_subnet.talos-az3.id
  }
}
# target group
resource "aws_lb_target_group" "talos-lb-tg" {
  name        = "talos-lb-tg"
  port        = 6443
  protocol    = "TCP"
  target_type = "ip"
  vpc_id      = aws_vpc.talos-vpc.id
}
#loadbalancer dns record
resource "cloudflare_record" "web" {
  zone_id = data.cloudflare_zone.tanukiops.id
  name    = "talos-on-aws"
  value   = aws_lb.talos-lb.dns_name
  type    = "CNAME"
  ttl     = 60
}
data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [aws_vpc.talos-vpc.id]
  }
}
# create aws_instances
resource "aws_instance" "talos-controlplane" {
  ami                    = var.talos_ami_id
  for_each               = data.aws_subnets.available
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.tvaneerdewegh.key_name
  vpc_security_group_ids = [aws_security_group.talos-sg.id]
  subnet_id              = each.key
  # tags = {
  #   Name = "controlplane-${each.value}"
  # }
}
# bootstrap talos machines
# configure talos machines
# deploy cni 
# deploy argocd

