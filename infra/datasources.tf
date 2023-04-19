data "aws_ami" "test_ami" {

  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["1103-a-91353974-90fc-42ed-923a-4791245c2c3c-22051-91353974-90fc-42ed-923a-4791245c2c3c"]
  }


}


# path /home/user/.ssh/testkey
