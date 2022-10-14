resource "aws_key_pair" "key_gen" {

    key_name = "generated_key"
    public_key = file("local_key.pub")
  
}

resource "aws_security_group" "jenkins_sg" {

    name = "allow__jenkins_traffic"
    description = "allow  traffic"
    
    ingress {
    description      = "Jenkins port"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    "Name" = "Jenkins_sg"
  }
  
}


resource "aws_security_group" "traffic_sg" {

    name = "allow_traffic"
    description = "allow  traffic"
    
    ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    "Name" = "traffic_sg"
  }
  
}

resource "aws_iam_role_policy" "ec2_policy" {

  name = "ec2_policy"
  role = aws_iam_role.ec2_role.id

  policy = "${file("ec2_policy.json")}"
  
}

resource "aws_iam_role" "ec2_role" {

  name = "testrole"
  assume_role_policy  = "${file("ec2_role.json")}" 

  
}

resource "aws_iam_instance_profile" "ec2_profile" {

  name = "ec2_profile"
  role = aws_iam_role.ec2_role.id

  
}


resource "aws_instance" "jenkins" {

    ami = data.aws_ami.amazon.id
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
    key_name = aws_key_pair.key_gen.id 
    iam_instance_profile = aws_iam_instance_profile.ec2_profile.id
     tags = {
      "Name" = "jenkins"
      "Project" = "${var.project}"
    }
  
  
}

resource "aws_instance" "test_server" {

    ami = data.aws_ami.amazon.id
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.traffic_sg.id]
    key_name = aws_key_pair.key_gen.id
    tags = {
      "Name" = "test_server"
      "Project" = "${var.project}"
    }
}


resource "aws_instance" "build_server" {

    ami = data.aws_ami.amazon.id
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.traffic_sg.id]
    key_name = aws_key_pair.key_gen.id
    tags = {
      "Name" = "build_server"
      "Project" = "${var.project}"
    }
}



