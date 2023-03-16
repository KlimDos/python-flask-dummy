module "appcat_app_data" {
  source   = "../../../modules/terraform/appcat-app-data"
  app_code = "dcm-alfresco7-one"
}

module "ct_shared_data" {
  source = "../../../modules/terraform/ct-shared-data"
}

resource "aws_db_parameter_group" "this" {
  name        = "dcm-alfresco7-one-${var.env_name}-pg"
  description         = "Parameter group for dcm-alfresco7-one"
  family      = var.family
  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
  }
  parameter {
    name  = "slow_query_log"
    value = "1"
  }
  parameter {
    name  = "innodb_flush_log_at_trx_commit"
    value = var.innodb_flush_log_at_trx_commit
  }
  parameter {
       name  = "sync_binlog"
       value = var.sync_binlog
  }

}

# Master username and password SHOULD be created in HC vault beforehand and separately from this code 
data "vault_generic_secret" "this" {
  path = "general-secrets/rds/${var.env_name}/dcm-alfresco7-one"
}

resource "aws_db_instance" "this" {
  allocated_storage          = var.allocated_storage
  auto_minor_version_upgrade = false
  skip_final_snapshot        = true
  storage_type               = var.storage_type
  iops                       = var.iops
  engine_version             = var.engine_version
  instance_class             = var.instance_class
  identifier                 = "dcm-alfresco7-one-${var.env_name}"
  backup_retention_period    = var.backup_retention_period
  backup_window              = var.backup_window
  username                   = data.vault_generic_secret.this.data["MASTER_USERNAME"]
  password                   = data.vault_generic_secret.this.data["MASTER_PASSWORD"]
  parameter_group_name       = aws_db_parameter_group.this.name
  performance_insights_enabled = var.performance_insights_enabled
  max_allocated_storage      = var.max_allocated_storage

  db_subnet_group_name   = var.rds_subnet_group_name[var.vpc_name]
  availability_zone      = var.availability_zone
  vpc_security_group_ids = [var.rds_security_groups[var.vpc_name]]

  tags = merge(module.appcat_app_data.ct_app_tags,
  module.ct_shared_data.ct_common_tags,{
    envName    = var.env_name
  })
}
