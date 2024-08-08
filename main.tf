terraform {
    backend "s3" {
        profile = "production-iamadmin"
        bucket = "homelab-tf-prd-bckend-01"
        key = "detect-lab/terraform.tfstate"
        region = "us-east-1"
        dynamodb_table = "terraform-state-locking"
        encrypt = true
    }
    required_providers {
      aws = {
        source = "hashicorp/aws"
      }
    }
}

provider "aws" {
    region = "us-east-1"
    profile = "production-iamadmin"
}

/**
This section creates a Firehose stream that outputs data to an S3 bucket.
It creates:
1. The Firehose stream itself
2. The IAM role used by the Firehose stream
3. The S3 bucket used as an output destination
**/
resource "aws_kinesis_firehose_delivery_stream" "extended_s3_stream" {
  name        = "terraform-kinesis-firehose-extended-s3-test-stream"
  destination = "extended_s3"
  extended_s3_configuration {
    prefix = "endpoint/!{timestamp:YYYY}/!{timestamp:MM}/!{timestamp:dd}/"
    error_output_prefix = "error_endpoint/!{firehose:error-output-type}/!{timestamp:YYYY}/!{timestamp:MM}/!{timestamp:dd}/"
    role_arn   = aws_iam_role.firehose_role.arn
    bucket_arn = aws_s3_bucket.bucket.arn
    compression_format = "GZIP"
    buffering_interval = 60
    buffering_size = 1
  }
}
resource "aws_s3_bucket" "bucket" {
  bucket = "raw-s3-logs-telemetry-1211"
}
data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}
resource "aws_iam_role" "firehose_role" {
  name               = "firehose_role"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json
}

/**
This section creates an small Amazon Linux 2 EC2 instance that contains a bootstrap script that installs and runs osquery.
It also creates an IAM role and EC2 instance profile so the EC2 instance can write to Firehose.
**/
resource "aws_instance" "linux_workstation" {
    depends_on = [ aws_iam_role.ec2allowfirehoserole ]
    ami           = "ami-0427090fd1714168b" # Amazon Linux 2023 AMI 2023.5.20240722.0 x86_64 HVM kernel-6.1
    instance_type = "t2.micro"
    // pass osquery bootstrap script to instance
    user_data = file("${path.module}/osquery.sh")
    // provide subnet located in created VPC
    subnet_id = aws_subnet.public_subnet.id
    // SG allowing SSH access via EC2 Instance Connect
    security_groups = [aws_security_group.allow_ssh.id]
    // IAM Instance Role allowing interaction with Kinesis
    //TODO: Need to create this role via Terraform
    iam_instance_profile = aws_iam_instance_profile.ec2allowfirehoseprofile.name
    tags = {
        Name = "linux_workstation"
  }
}
resource "aws_iam_role_policy" "ec2allowfirehosepolicy" {
  name = "ec2allowfirehosepolicy"
  role = aws_iam_role.ec2allowfirehoserole.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
            "firehose:PutRecordBatch",
            "firehose:PutRecord"
        ],
        Effect = "Allow"
        Resource = "${aws_kinesis_firehose_delivery_stream.extended_s3_stream.arn}"
      }
    ]
  })
}

resource "aws_iam_role" "ec2allowfirehoserole" {
  name = "ec2allowfirehoserole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_instance_profile" "ec2allowfirehoseprofile" {
  name = "ec2allowfirehoseprofile"
  role = aws_iam_role.ec2allowfirehoserole.name
}

/**
This section creates the network infrastructure used by the EC2 instance. 
It creates a VPC, Subnet, Route Table, and Security Group allowing inbound SSH and outbound everything
**/
resource "aws_vpc" "main" {
 cidr_block = "10.0.0.0/24"

 tags = {
   Name = "engine-from-scratch-vpc"
 }
}
resource "aws_subnet" "public_subnet" {
    vpc_id = aws_vpc.main.id
    cidr_block = "10.0.0.128/28"
    map_public_ip_on_launch = true
    tags = {
        Name = "public_subnet"
    }
}
resource "aws_internet_gateway" "gw" {

    vpc_id = aws_vpc.main.id
    tags = {
        Name = "engine-from-scratch-ig"
    }
}
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gw.id
    }
    tags = {
        Name = "public_rt"
    }
}
resource "aws_route_table_association" "public_subnet_asso" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_rt.id
}
resource "aws_security_group" "allow_ssh" {
    name = "allow_ssh"
    description = "Allows inbound SSH and all outbound traffic"
    vpc_id = aws_vpc.main.id
    tags = {
      Name = "allow_ssh"
    }
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
    security_group_id = aws_security_group.allow_ssh.id
    cidr_ipv4 = "18.206.107.24/29" #cidr range for EC2 Instance Connect Service
    from_port = 22
    ip_protocol = "tcp"
    to_port = 22
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.allow_ssh.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}