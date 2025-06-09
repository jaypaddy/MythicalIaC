provider "aws" {
  region = var.aws_region
}

# S3 Resources
resource "aws_iam_user" "s3_user" {
  name = "${var.project_name}-s3-user"
}

resource "aws_iam_access_key" "s3_keys" {
  user = aws_iam_user.s3_user.name
}

resource "aws_s3_bucket" "s3_content" {
  bucket_prefix = "${var.project_name}-content-"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-content"
  }
}

resource "aws_s3_bucket_ownership_controls" "s3_ownership" {
  bucket = aws_s3_bucket.s3_content.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_public_access" {
  bucket = aws_s3_bucket.s3_content.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "s3_content_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.s3_ownership,
    aws_s3_bucket_public_access_block.s3_public_access,
  ]

  bucket = aws_s3_bucket.s3_content.id
  acl    = "public-read"
}

# S3 Bucket Policy
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.s3_content.id
  policy = jsonencode({
    Version = "2008-10-17",
    Id      = "WriteContentPolicy",
    Statement = [
      {
        Sid       = "WriteAccess",
        Action    = ["s3:GetObject", "s3:PutObject", "s3:PutObjectACL"],
        Effect    = "Allow",
        Resource  = "${aws_s3_bucket.s3_content.arn}/*",
        Principal = {
          AWS = aws_iam_user.s3_user.arn
        }
      }
    ]
  })
}

# Load Balancer
resource "aws_lb" "insoshi_lb" {
  name               = "${var.project_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [for subnet in aws_subnet.public_subnets : subnet.id]

  tags = {
    Name = "${var.project_name}-lb"
  }
}

resource "aws_lb_target_group" "insoshi_target" {
  name     = "${var.project_name}-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
}

resource "aws_lb_listener" "insoshi_listener" {
  load_balancer_arn = aws_lb.insoshi_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.insoshi_target.arn
  }

  # Sticky session configuration
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 30
    enabled         = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web_server_group" {
  name                = "${var.project_name}-asg"
  min_size            = 1
  max_size            = 5
  desired_capacity    = var.web_server_capacity
  vpc_zone_identifier = [for subnet in aws_subnet.private_subnets : subnet.id]
  launch_configuration = aws_launch_configuration.launch_config.name

  target_group_arns = [aws_lb_target_group.insoshi_target.arn]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-instance"
    propagate_at_launch = true
  }
}

# Launch Configuration for Auto Scaling
resource "aws_launch_configuration" "launch_config" {
  name_prefix   = "${var.project_name}-lc-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name
  security_groups = [aws_security_group.web_server_sg.id]

  user_data = <<-EOF
#!/bin/bash -v
yum update -y aws-cfn-bootstrap

# Install packages
yum install -y git gcc-c++ make ruby-devel ruby18-rdoc rubygems mysql mysql-devel mysql-libs libjpeg-devel libpng-devel libtiff-devel freetype-devel ghostscript-devel ImageMagick-devel

# Setup Ruby Gems
gem update --system 1.4.2

# Install required gems
gem install mysql -v 2.9.1
gem install rake -v 0.8.7
gem install rails -v 2.3.15
gem install chronic -v 0.9.1
gem install rdiscount -v 2.0.7.3
gem install rmagick -v 2.13.2
gem install aws-s3

# Download Sphinx and Insoshi
mkdir -p /home/ec2-user/sphinx
curl -L http://sphinxsearch.com/files/sphinx-2.0.6-release.tar.gz | tar -xz -C /home/ec2-user/sphinx --strip-components=1
mkdir -p /home/ec2-user/insoshi
curl -L http://github.com/insoshi/insoshi/tarball/master | tar -xz -C /home/ec2-user/insoshi --strip-components=1

# Configure database.yml
cat > /home/ec2-user/insoshi/config/database.yml << 'DBCONFIG'
development:
  adapter: mysql
  database: ${var.db_name}
  host: ${aws_db_instance.db_instance.address}
  username: ${var.db_username}
  password: ${var.db_password}
  timeout: 5000
DBCONFIG

# Configure amazon_s3.yml
cat > /home/ec2-user/insoshi/config/amazon_s3.yml << 'S3CONFIG'
development:
  bucket_name: ${aws_s3_bucket.s3_content.bucket}
  access_key_id: ${aws_iam_access_key.s3_keys.id}
  secret_access_key: ${aws_iam_access_key.s3_keys.secret}
S3CONFIG

# Build Sphinx
cd /home/ec2-user/sphinx
./configure
make
make install

# Configure and Install Insoshi
cd /home/ec2-user/insoshi
export PATH=$PATH:/usr/local/bin
script/install
rake ultrasphinx:configure
rake ultrasphinx:index
rake ultrasphinx:daemon:start
# Fixup configuration to use S3 for photos and thumbnails
sed -i 's/file_system/s3/' app/models/photo.rb
sed -i 's/file_system/s3/' app/models/thumbnail.rb
script/server -d -p 80

# Cleanup
cd /home/ec2-user
rm -Rf build_sphinx configure_insoshi sphinx
  EOF

  lifecycle {
    create_before_destroy = true
  }
}

# RDS Database Instance
resource "aws_db_instance" "db_instance" {
  allocated_storage    = var.db_allocated_storage
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = var.db_instance_class
  db_name              = var.db_name
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql5.7"
  multi_az             = var.multi_az_database
  vpc_security_group_ids = [aws_security_group.db_security_group.id]
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot  = true

  tags = {
    Name = "${var.project_name}-database"
  }
}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.database_subnets : subnet.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}
