data "aws_ami" "app_ami" {
  most_recent = true
  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["979382823631"] # Bitnami
}
data "aws_vpc" "default" {
  default = true
}
resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  vpc_security_group_ids = [module.blog_sg.security_group_id]
  
  tags = {
    Name = "HelloWorld"
  }
}
module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.17.1"
  name    = "blog_new"

  vpc_id      = data.aws_vpc.default.id
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
}

resource "aws_security_group" "blog" {
  name        = "blog"
  description = "Allow HTTP and HTTPS in. Allow everything out"

  vpc_zone_identifier = module.vpc.public_subnets
  target_group_arns  = module.blog_alb.target_group_arns
  security_groups     = [module.blog_sg.security_group_id]
  image_id           = data.aws_ami.app_ami.id
  instance_type      = var.instance_type
}

resource "aws_security_group_rule" "blog_http_in" {
  type        = "ingress"
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  name = "blog-alb"

  load_balancer_type = "application"

  vpc_id             = module.blog_vpc.vpc_id
  subnets            = module.blog_vpc.public_subnets
  security_groups    = module.blog_sg.security_group_id

  target_groups = [
    {
      name_prefix      = "blog-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      target = {
        target_id = aws_instance.blog.id
        port = 80
      }
    }
  ]

  http_tcp_listeners = [
    {
      port        = 80
      protocol    = "HTTP"
      target_group_index = 0 
    }
  ]

  tags = {
    Environment = "dev"
  }
}

resource "aws_security_group_rule" "blog_https_in" {
  type        = "ingress"
  from_port   = 443
  to_port     = 443
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.blog.id
}

resource "aws_security_group_rule" "blog_everything_out" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = aws_security_group.blog.id
}