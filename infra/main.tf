data "aws_region" "current" {}

resource "aws_vpc" "test_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true


  tags = {
    "Name" = "test_vpc"
  }

}



resource "aws_subnet" "test_subnet_private-1a" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"



  tags = {
    "Name" = "test_subnet_private-1a"
  }
}



resource "aws_subnet" "test_subnet_private-1b" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1b"



  tags = {
    "Name" = "test_subnet_private-1b"
  }
}

resource "aws_subnet" "test_subnet_public-1c" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1c"



  tags = {
    "Name" = "test_subnet_public-1c"
  }
}


resource "aws_subnet" "test_subnet_public-1d" {
  vpc_id                  = aws_vpc.test_vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1d"



  tags = {
    "Name" = "test_subnet_public-1d"
  }
}




resource "aws_route_table" "test_private_table" {
  vpc_id = aws_vpc.test_vpc.id
  tags = {
    "Name" = "test_rt_private"
  }


}


resource "aws_route_table" "test_public_table" {
  vpc_id = aws_vpc.test_vpc.id
  tags = {
    "Name" = "test_rt_public"
  }

}


resource "aws_route_table_association" "test_private_rt_association-1a" {
  subnet_id      = aws_subnet.test_subnet_private-1a.id
  route_table_id = aws_route_table.test_private_table.id
}

resource "aws_route_table_association" "test_private_rt_association-1b" {
  subnet_id      = aws_subnet.test_subnet_private-1b.id
  route_table_id = aws_route_table.test_private_table.id
}

resource "aws_route_table_association" "test_public_rt_association-1c" {
  subnet_id      = aws_subnet.test_subnet_public-1c.id
  route_table_id = aws_route_table.test_public_table.id
}


resource "aws_route_table_association" "test_public_rt_association-1d" {
  subnet_id      = aws_subnet.test_subnet_public-1d.id
  route_table_id = aws_route_table.test_public_table.id
}



resource "aws_internet_gateway" "test_internet_gateway" {
  vpc_id = aws_vpc.test_vpc.id
  tags = {
    "Name" = "test_igv"
  }
}


resource "aws_route" "internet_route" {
  route_table_id         = aws_route_table.test_public_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test_internet_gateway.id
}



# create a nat gateway
resource "aws_eip" "test_nat" {
  vpc = true
}

resource "aws_nat_gateway" "test_ng" {
  allocation_id = aws_eip.test_nat.id
  subnet_id     = aws_subnet.test_subnet_public-1c.id


  tags = {
    "Name" = "test_ng"
  }
}


resource "aws_route" "test_nat_route" {
  route_table_id         = aws_route_table.test_private_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.test_ng.id
}



resource "aws_security_group" "mtc_sg" {
  name        = "test_sg"
  description = "test security group"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
  }
}

# create aws key pair to ssh
resource "aws_key_pair" "test_auth_1" {
  key_name   = "key"
  public_key = file("~/.ssh/private_key.pem.pub")
}

resource "aws_instance" "test_1node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.test_ami.id # this is a id
  key_name               = aws_key_pair.test_auth_1.key_name
  vpc_security_group_ids = [aws_security_group.mtc_sg.id]
  subnet_id              = aws_subnet.test_subnet_public-1c.id

  tags = {
    "Name" = "1test_node"
  }

  root_block_device {
    volume_size = 10
  }
}

resource "aws_instance" "test_2node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.test_ami.id
  key_name               = aws_key_pair.test_auth_1.key_name
  vpc_security_group_ids = [aws_security_group.mtc_sg.id]
  subnet_id              = aws_subnet.test_subnet_private-1b.id

  tags = {
    "Name" = "2test_node"
  }
  root_block_device {
    volume_size = 10
  }


}

# create a ecr_repo
resource "aws_ecr_repository" "test_registry" {
  name                 = "test_repo"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}


resource "local_file" "inventory" {
  content  = "[webservers]\npublic_instance ansible_host=public\nprivate_instance ansible_host=private\n"
  filename = "ansible/inventory"
}


resource "local_file" "ssh_config" {
  content = <<-EOF
      Host public
        hostname ${aws_instance.test_1node.public_ip}
        user ubuntu
        port 22
        IdentityFile /home/user/.ssh/private_key.pem

      Host private
        hostname ${aws_instance.test_2node.private_ip}
        user ubuntu
        port 22
        IdentityFile /home/user/.ssh/private_key.pem
        ProxyCommand ssh -W %h:%p public
  EOF

  filename = "/home/user/.ssh/config"
}

# Host public
#   hostname public_ip
#   user:ubuntu
#   port 22
#   identifyfile:path

# Host private_ip
#  hostname
#  port 22
#  identifyfile 
#  proxyCommand ssh public -w %h:%p
# resource "null_resource" "push_test_registry" {
#   provisioner "local-exec" {
#     command = "${path.module}/ansible/push_image.yml"
#     environment = {
#       image_name      = "test_name"
#       image_tag       = "test_image_1"
#       REPOSITORY_URL  = aws_ecr_repository.test_registry.repository_url
#       REGION          = data.aws_region.current.name
#       IMAGE_DIRECTORY = abspath("${path.module}/../images")
#     }
#   }
# }

# # pull image to aws ec2
# resource "null_resource" "pull_image" {
#   connection {
#     type        = "ssh"
#     host        = aws_instance.test_1node.public_ip
#     user        = "ec2-user"
#     private_key = file("/home/user/.ssh/testkey")
#   }

#   provisioner "local-exec" {
#     inline = [
#       "sudo systemctl start docker",
#       "$(aws ecr get-login --no-include-email --region ${data.aws_region.current.name})",
#       "sudo docker pull ${aws_ecr_repository.test_registry.repository_url}:latest"
#     ]
#   }
# }



