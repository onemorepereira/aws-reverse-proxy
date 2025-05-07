provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"] # Filters out Local Zones and Wavelength Zones
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC & Networking
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_eip" "nlb_eip_1" {}

resource "aws_eip" "nlb_eip_2" {}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet1_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet2_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
}

resource "aws_route_table_association" "rta_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "haproxy_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for SSM access
resource "aws_iam_role" "ssm_ec2_role" {
  name = "haproxy-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "haproxy-ssm-profile"
  role = aws_iam_role.ssm_ec2_role.name
}

# Launch Template
resource "aws_launch_template" "haproxy_lt" {
  name_prefix   = "haproxy-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.proxy_class

  iam_instance_profile {
    name = aws_iam_instance_profile.ssm_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.haproxy_sg.id]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    upstream_ip   = var.upstream_ip
    upstream_port = var.upstream_port
    vpc_cidr      = var.vpc_cidr
  }))

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "haproxy_asg" {
  name                      = "haproxy-asg"
  max_size                  = 2
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  target_group_arns         = [aws_lb_target_group.tcp_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.haproxy_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "HAProxyPassthrough"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }
}

# Network Load Balancer
resource "aws_lb" "nlb" {
  name               = "haproxy-nlb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = aws_subnet.public_1.id
    allocation_id = aws_eip.nlb_eip_1.id
  }

  subnet_mapping {
    subnet_id     = aws_subnet.public_2.id
    allocation_id = aws_eip.nlb_eip_2.id
  }
}

resource "aws_lb_target_group" "tcp_tg" {
  name        = "tcp-target-group"
  port        = 443
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    port     = "9000"
    protocol = "TCP"
  }
}

resource "aws_lb_listener" "tcp_listener" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tcp_tg.arn
  }
}