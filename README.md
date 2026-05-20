# Setting Up Infrastucture On AWS Using Terraform  
<img width="800" height="457" alt="Setting up Infrastructure on AWS using Terraform" src="https://github.com/user-attachments/assets/ed110866-6754-4083-852b-e4f126f29411" />

## 📌 Project Overview

In this project we are going to create a complete AWS infrastructure using Terraform.

The infrastructure includes:

* Custom VPC
* 2 Public Subnets in different Availability Zones
* Internet Gateway
* Route Table
* Security Group
* 2 EC2 Instances
* S3 Bucket
* IAM Role for EC2 to access S3
* Application Load Balancer
* Target Group & Listener

The main goal of this project is to understand how real-world infrastructure is provisioned automatically using Infrastructure as Code (IaC).

---

# ⚙️ Prerequisites

Before starting the project install Terraform and AWS CLI.

---

## Install Terraform

Terraform is used to automate the infrastructure creation process.

Official Documentation:

[Terraform Install Guide](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli?utm_source=chatgpt.com)

Verify installation:

```bash
terraform -version
```

---

## Install AWS CLI

AWS CLI is required so Terraform can authenticate with AWS.

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

unzip awscliv2.zip

sudo ./aws/install
```

Verify installation:

```bash
aws --version
```

---

## Configure AWS Credentials

Configure AWS account credentials.

```bash
aws configure
```

Provide:

* AWS Access Key
* AWS Secret Access Key
* Region
* Output Format

---

# 🚀 Let's Start the Project

---

# Step 1:

Create a project directory and go inside it.

Then create all Terraform configuration files.

```bash
mkdir terraform-aws-project/

cd terraform-aws-project/
```
<img width="1710" height="157" alt="Screenshot 2026-05-19 at 10 28 27 PM" src="https://github.com/user-attachments/assets/4d94be4c-c7a7-4cd5-8494-d3fa91c53032" />

Now create the required files.

```bash
vim provider.tf
vim main.tf
vim variables.tf
vim backend.tf
vim outputs.tf
vim userdata1.sh
vim userdata2.sh
```

These files will contain provider configuration, infrastructure resources, variables, backend configuration, outputs and userdata scripts.

---

# Step 2:

Now configure the AWS provider inside the `provider.tf` file.

Terraform needs to know which cloud provider we are using and which region resources should be created in.

## provider.tf

```hcl
provider "aws" {
  region = var.region
}
```

---

# Step 3:

Now create the variables file.

Variables help us avoid hardcoding values and make the project reusable.

## variables.tf

```hcl
variable "region" {
  default = "us-east-1"
}

variable "cidr" {
  default = "10.0.0.0/16"
}

variable "ami" {
  default = "ami-053b0d53c279acc90"
}
```

---

# Step 4:

Now configure the Terraform backend.

Backend is used to store the Terraform state file remotely in S3.

## backend.tf

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-backend-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}
```

---

# Step 5:

Now start writing the `main.tf` file.

First create the VPC because the whole infrastructure will be created inside this Virtual Private Cloud.

## Create VPC

```hcl
resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}
```

The CIDR block defines the IP address range of the VPC.

---

# Step 6:

Now create two public subnets.

These subnets will be created in two different Availability Zones for High Availability.

Also enable automatic public IP assignment.

## Create Public Subnets

```hcl
resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}
```

---

# Step 7:

Public subnets should have internet access.

For that create and attach an Internet Gateway to the VPC.

## Create Internet Gateway

```hcl
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}
```

Internet Gateway allows resources inside the VPC to communicate with the internet.

---

# Step 8:

Now create the Route Table.

The Route Table will define routes for internet communication.

## Create Route Table

```hcl
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
```

`0.0.0.0/0` means all internet traffic will go through the Internet Gateway.

---

# Step 9:

Now associate both public subnets with the Route Table.

## Route Table Association

```hcl
resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}
```

This allows both subnets to access the internet.

---

# Step 10:

Now create the Security Group.

Security Groups act like virtual firewalls for EC2 instances.

Allow:

* Port 80 → HTTP Traffic
* Port 22 → SSH Access

## Create Security Group

```hcl
resource "aws_security_group" "websg" {
  name   = "websg"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}
```

---

# Step 11:

Now create the S3 Bucket.

S3 bucket names should always be globally unique.

## Create S3 Bucket

```hcl
resource "aws_s3_bucket" "example" {
  bucket = "20may-terraform-aws-project"
}
```

---

# Step 12:

Now create IAM Role and Instance Profile.

This allows EC2 instances to securely access S3 without storing credentials inside the server.

## Create IAM Role

```hcl
resource "aws_iam_role" "ec2_s3_role" {
  name = "20may-ec2-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}
```

Attach S3 ReadOnly Policy:

```hcl
resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
```

Create Instance Profile:

```hcl
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "20may-ec2-profile"
  role = aws_iam_role.ec2_s3_role.name
}
```

---

# Step 13:

Now create two EC2 instances.

Attach:

* Public Subnets
* Security Group
* IAM Instance Profile
* User Data Scripts

## Create EC2 Instances

```hcl
resource "aws_instance" "webserver1" {
  ami                    = var.ami
  instance_type          = "t2.micro"

  subnet_id              = aws_subnet.sub1.id

  vpc_security_group_ids = [aws_security_group.websg.id]

  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(file("userdata1.sh"))
}
```

```hcl
resource "aws_instance" "webserver2" {
  ami                    = var.ami
  instance_type          = "t2.micro"

  subnet_id              = aws_subnet.sub2.id

  vpc_security_group_ids = [aws_security_group.websg.id]

  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = base64encode(file("userdata2.sh"))
}
```

The userdata scripts automatically install Apache and create a web page after instance launch.

---

# Step 14:

Now create the Application Load Balancer.

The ALB distributes incoming traffic between both EC2 instances.

## Create ALB

```hcl
resource "aws_lb" "myalb" {
  name               = "myalb"

  internal           = false

  load_balancer_type = "application"

  security_groups = [aws_security_group.websg.id]

  subnets = [
    aws_subnet.sub1.id,
    aws_subnet.sub2.id
  ]
}
```

---

# Step 15:

Now create the Target Group.

The Target Group contains the EC2 instances that receive traffic from the ALB.

## Create Target Group

```hcl
resource "aws_lb_target_group" "tg" {
  name     = "myTG"

  port     = 80

  protocol = "HTTP"

  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}
```

Health checks ensure traffic goes only to healthy instances.

---

# Step 16:

Now attach both EC2 instances to the Target Group.

## Attach Instances

```hcl
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn

  target_id        = aws_instance.webserver1.id

  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn

  target_id        = aws_instance.webserver2.id

  port             = 80
}
```

---

# Step 17:

Now create the Listener for the Load Balancer.

The Listener listens on port 80 and forwards requests to the Target Group.

## Create Listener

```hcl
resource "aws_lb_listener" "listener" {

  load_balancer_arn = aws_lb.myalb.arn

  port              = 80

  protocol          = "HTTP"

  default_action {

    type             = "forward"

    target_group_arn = aws_lb_target_group.tg.arn
  }
}
```

---

# Step 18:

Now create the output file.

This will print the DNS name of the Load Balancer after deployment.

## outputs.tf

```hcl
output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}
```

---

# Step 19:

Initialize Terraform.

This downloads all required provider plugins.

```bash
terraform init
```
<img width="1710" height="1107" alt="Screenshot 2026-05-19 at 11 14 52 PM" src="https://github.com/user-attachments/assets/6e85cb94-5d6a-457c-b80e-9ae8492d6fd7" />

---

# Step 20:

Validate the Terraform code.

```bash
terraform validate
```

---

# Step 21:

Check the execution blueprint before deployment.

```bash
terraform plan
```

Terraform will show all resources that are going to be created.

---

# Step 22:

Now deploy the infrastructure.

```bash
terraform apply
```

Type:

```bash
yes
```

Terraform will now create all AWS resources automatically.
<img width="1710" height="1107" alt="Screenshot 2026-05-20 at 3 24 20 PM" src="https://github.com/user-attachments/assets/be1878c5-82c7-48c4-81be-9e686290b703" />


---

# Step 23:

After successful deployment Terraform will print the ALB DNS Name.

Copy the DNS and open it in the browser.

```bash
http://<load-balancer-dns>
```

Refresh the page multiple times to see traffic switching between the two servers.

---

# Final Output


<img width="1709" height="969" alt="Screenshot 2026-05-20 at 3 21 31 PM" src="https://github.com/user-attachments/assets/58492adf-834b-4927-88e1-83bec89767af" />

<img width="1710" height="1107" alt="Screenshot 2026-05-20 at 4 12 43 PM" src="https://github.com/user-attachments/assets/719a1a44-86e0-49c4-be48-523a101cda68" />


---

# Step 24:

After project completion destroy the infrastructure to avoid AWS charges.

```bash
terraform destroy
```

---
Amtul Saboor
DevOps & Cloud Enginner
