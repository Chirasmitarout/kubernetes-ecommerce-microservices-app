############################################################
# EXISTING RDS DB SUBNET GROUP
############################################################
#
# 'main' already exists in AWS.
# So we READ it instead of creating it.
#
############################################################

data "aws_db_subnet_group" "sub_grp" {

  name = "main"
}

############################################################
# RDS INSTANCE
############################################################

resource "aws_db_instance" "rds" {

  allocated_storage = 20

  identifier = "microservices-rds"

  # Existing DB subnet group
  db_subnet_group_name = data.aws_db_subnet_group.sub_grp.name

  engine         = "mysql"
  engine_version = "8.4.8"

  instance_class = "db.t3.micro"

  multi_az = true

  db_name = "mydb"

  username = "admin"
  password = "Cloud123"

  skip_final_snapshot = true

  vpc_security_group_ids = [
    aws_security_group.allow_all.id
  ]

  publicly_accessible = true

  backup_retention_period = 7

  tags = {
    DB_identifier = "book-rds"
  }

  depends_on = [
    data.aws_db_subnet_group.sub_grp
  ]
}
