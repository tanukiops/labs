data "cloudflare_zone" "tanukiops" {
  name = "tanukiops.org"
}

resource "aws_key_pair" "tvaneerdewegh" {
  key_name   = "tvaneerdewegh"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9NL4EhmSEhyaKt8fDybkRtvL/g1+hKBqL1Qp5/OOK5peGHAr2VGBvFMLM4FT+F6Q7w7IX0JXFs24smi76vnmFtFdTBZxWivsDpznFVKcQCfq/ZnBL2lEGRlchW/ZLAjWV8XpFMoybWlvaPd18m2n11FYKl0oFdn47j9UIxuofk0cp+0/QiVjrqFRD4shTAAeKH1vHnNCS+KbsBWJNZ9sO0V3l7kKyMlD2K+qfv7SGH0YHcj1+eEG/YAhDInF770yTziXy5HTGgecry+Iyh2Ck4vcLyPnHI8OHTvgFu1Xl3VQxYlaAIXBG1NPb3F6gfOF1dXOadzzt+HDHDKqonOXj tim.vaneerdewegh@uantwerpen.be"
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "sg to allow ssh from home"
  vpc_id      = "vpc-01f763b28bcd3c32e"
  tags = {
    Name = "allow_ssh"
  }
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "78.20.204.131/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "78.20.204.131/32"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_egress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}
resource "aws_vpc_security_group_egress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.tvaneerdewegh.key_name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  tags = {
    Name = "terraform-example"
  }
}

resource "cloudflare_record" "web" {
  zone_id = data.cloudflare_zone.tanukiops.id
  name    = "www"
  value   = aws_instance.web.public_ip
  type    = "A"
  ttl     = 60
}
