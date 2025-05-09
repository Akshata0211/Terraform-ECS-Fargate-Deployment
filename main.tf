# Set AWS provider and region
provider "aws" {
  region = "us-west-1"
}

# Create a new VPC with DNS support
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Create a public subnet in the VPC
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-west-1a"
  map_public_ip_on_launch = true
}

# Internet Gateway for the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Route table to allow internet access
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
}

# Default route to the internet
resource "aws_route" "default" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate the subnet with the route table
resource "aws_route_table_association" "assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.rt.id
}

# Security group to allow inbound HTTP traffic on port 5000
resource "aws_security_group" "ecs_sg" {
  name        = "flask-app-sg"
  description = "Allow HTTP on port 5000"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5000
    to_port     = 5000
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

# ECR repository to store Docker image
resource "aws_ecr_repository" "flask_app" {
  name = "flask-app-repo"
}

# IAM role for ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach the execution role policy
resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Cluster
resource "aws_ecs_cluster" "flask_cluster" {
  name = "flask-app-cluster"
}

# Push Docker image to ECR
resource "null_resource" "docker_push" {
  provisioner "local-exec" {
    command = <<EOT
      repo=${aws_ecr_repository.flask_app.repository_url}
      echo "Logging in to AWS ECR..."
      aws ecr get-login-password --region us-west-1 | docker login --username AWS --password-stdin $repo

      echo "Building Docker image..."
      docker build -t flask-app .

      echo "Tagging image..."
      docker tag flask-app:latest $repo:latest

      echo "Pushing to ECR..."
      docker push $repo:latest
    EOT
    # Adjust interpreter if not using Git Bash (for Windows users)
    interpreter = ["C:/Program Files/Git/usr/bin/bash.exe", "-c"]
  }

  triggers = {
    always_run = timestamp()
  }

  depends_on = [aws_ecr_repository.flask_app]
}

# CloudWatch Logs for ECS container
resource "aws_cloudwatch_log_group" "flask_app_logs" {
  name = "/ecs/flask-app-logs"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "flask_task" {
  family                   = "flask-app-task"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([{
    name      = "flask-app",
    image     = "${aws_ecr_repository.flask_app.repository_url}:latest",
    essential = true,
    portMappings = [{
      containerPort = 5000,
      protocol      = "tcp"
    }],
    logConfiguration = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = aws_cloudwatch_log_group.flask_app_logs.name,
        awslogs-region        = "us-west-1",
        awslogs-stream-prefix = "flask-app"
      }
    }
  }])

  depends_on = [
    null_resource.docker_push,
    aws_cloudwatch_log_group.flask_app_logs
  ]
}

# ECS Service to run the task
resource "aws_ecs_service" "flask_service" {
  name            = "flask-app-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.public_subnet.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [aws_ecs_task_definition.flask_task]
}
