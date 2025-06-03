# Insoshi Terraform Configuration

This is a Terraform implementation of the Insoshi deployment originally created as a CloudFormation template. The infrastructure sets up a highly-available, scalable Insoshi deployment with a multi-az Amazon RDS database instance for storage and an S3 bucket for photos and thumbnails.

## Architecture

This Terraform configuration creates:

- VPC with public, private, and database subnets across multiple availability zones
- Internet gateway and NAT gateway for network connectivity
- Security groups for the load balancer, web servers, and database
- Application Load Balancer with health checks and sticky sessions
- Auto Scaling Group for EC2 instances running Insoshi
- RDS MySQL database instance with Multi-AZ support
- S3 bucket for content storage with appropriate IAM permissions

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (version 1.2.0 or newer)
- AWS account with appropriate permissions
- AWS CLI configured with credentials

## Usage

1. Initialize the Terraform configuration:

```bash
terraform init
```

2. Create a `terraform.tfvars` file with your specific values (use the provided `terraform.tfvars.example` as a template).

3. Plan the deployment:

```bash
terraform plan
```

4. Apply the configuration:

```bash
terraform apply
```

5. After the deployment completes, the outputs will provide:
   - The website URL
   - S3 bucket name
   - RDS endpoint
   - Access credentials for the S3 user

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| aws_region | AWS region to deploy resources | us-east-1 |
| project_name | Project name to use in resource names | insoshi |
| vpc_cidr | CIDR block for the VPC | 10.0.0.0/16 |
| availability_zones | List of availability zones to use | ["us-east-1a", "us-east-1b"] |
| key_name | Name of the EC2 key pair to use | - |
| db_name | MySQL database name | insoshi |
| db_username | Username for MySQL database access | - |
| db_password | Password for MySQL database access | - |
| multi_az_database | Create a multi-AZ MySQL Amazon RDS database instance | true |
| web_server_capacity | The initial number of WebServer instances | 2 |
| instance_type | WebServer EC2 instance type | t3.micro |
| db_instance_class | Database instance class | db.t3.small |
| db_allocated_storage | The size of the database (GB) | 5 |
| ssh_location | The IP address range that can be used to SSH to the EC2 instances | 0.0.0.0/0 |
| ami_id | The AMI ID to use for the EC2 instances | ami-0c55b159cbfafe1f0 |

## Clean Up

To destroy all resources created by this Terraform configuration:

```bash
terraform destroy
```

## Notes

- This implementation modernizes the original CloudFormation template with current AWS best practices
- The EC2 instances use user data to install and configure Insoshi, similar to the original template
- Security groups are more restrictive, following the principle of least privilege
- The VPC architecture provides better isolation between different tiers of the application
