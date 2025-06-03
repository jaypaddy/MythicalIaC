variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name to use in resource names"
  type        = string
  default     = "insoshi"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "key_name" {
  description = "Name of the EC2 key pair to use"
  type        = string
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "insoshi"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]*$", var.db_name))
    error_message = "The database name must begin with a letter and contain only alphanumeric characters."
  }
}

variable "db_username" {
  description = "Username for MySQL database access"
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9]*$", var.db_username))
    error_message = "The database username must begin with a letter and contain only alphanumeric characters."
  }
}

variable "db_password" {
  description = "Password for MySQL database access"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8 && length(var.db_password) <= 41 && can(regex("^[a-zA-Z0-9]*$", var.db_password))
    error_message = "The database password must be between 8 and 41 characters long and contain only alphanumeric characters."
  }
}

variable "multi_az_database" {
  description = "Create a multi-AZ MySQL Amazon RDS database instance"
  type        = bool
  default     = true
}

variable "web_server_capacity" {
  description = "The initial number of WebServer instances"
  type        = number
  default     = 2
  validation {
    condition     = var.web_server_capacity >= 1 && var.web_server_capacity <= 5
    error_message = "The web server capacity must be between 1 and 5 instances."
  }
}

variable "instance_type" {
  description = "WebServer EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.small"
}

variable "db_allocated_storage" {
  description = "The size of the database (GB)"
  type        = number
  default     = 5
  validation {
    condition     = var.db_allocated_storage >= 5 && var.db_allocated_storage <= 1024
    error_message = "The database allocated storage must be between 5 and 1024 GB."
  }
}

variable "ssh_location" {
  description = "The IP address range that can be used to SSH to the EC2 instances"
  type        = string
  default     = "0.0.0.0/0"
  validation {
    condition     = can(regex("^(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})$", var.ssh_location))
    error_message = "The SSH location must be a valid IP CIDR range of the form x.x.x.x/x."
  }
}

# AMI mapping based on region and architecture
variable "ami_id" {
  description = "The AMI ID to use for the EC2 instances"
  type        = string
  default     = "ami-0c55b159cbfafe1f0" # Default Amazon Linux 2 AMI, change as needed
}
