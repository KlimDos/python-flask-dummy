module "vpc" {
  source = "git::git@github.com:wiley/do-infrastructure-modules.git//cloud/aws/vpc?ref=v2.19.3"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs = var.availability_zones

  private_subnets = var.cidr_private
  public_subnets  = var.cidr_public

  # Use single NAT GW,
  # Enable DNS, but disable Public DNS hostnames for EC2 instances
  enable_nat_gateway           = true
  single_nat_gateway           = true
  enable_dns_hostnames         = true
  enable_dns_support           = true
  create_database_subnet_group = true

  # Tags differ for Public and Private subnets for Kubernetes
  private_subnet_tags = var.eks_cluster_name != null ? merge(
    { "kubernetes.io/role/internal-elb" = "1" },
    { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" },
    var.global_tags,
    var.additional_priv_sn_tags
  ) : merge(var.global_tags, var.additional_priv_sn_tags)

  public_subnet_tags = var.eks_cluster_name != null ? merge(
    { "kubernetes.io/role/elb" = "1" },
    { "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared" },
    var.global_tags,
    var.additional_pub_sn_tags
  ) : merge(var.global_tags, var.additional_pub_sn_tags)

  vpc_tags                   = var.global_tags
  private_route_table_tags   = var.global_tags
  public_route_table_tags    = var.global_tags
  igw_tags                   = var.global_tags
  nat_gateway_tags           = var.global_tags
  nat_eip_tags               = var.global_tags
  database_subnet_group_tags = var.global_tags

}

##########################################################################
# DNS Zone setup
resource "aws_route53_zone" "private" {
  count   = var.enable_private_resolver ? 1 : 0
  name    = var.zone_name
  comment = var.zone_comment

  # Add more vpc blocks if new VPCs need to be added
  vpc {
    vpc_id = module.vpc.vpc_id
  }

  tags = merge(var.global_tags,
    tomap({"Name"=var.vpc_name}))
}

locals {
  # for performance, do this eval only once
  # used by SG used by Route 53 resolver
  sg_cidr_blocks = concat(tolist([module.vpc.vpc_cidr_block]),
  var.route53_resolver_cidr)
}

resource "aws_security_group" "vpc" {
  count  = var.enable_private_resolver ? 1 : 0
  name   = var.vpc_name
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = local.sg_cidr_blocks
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = local.sg_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.global_tags,
   tomap({"Name"=var.vpc_name}))
}



# Required to add visibility for a private DNS zone
# from Wiley's inernal networks - VPN, Office, etc
resource "aws_route53_resolver_endpoint" "inbound" {
  count     = var.enable_private_resolver ? 1 : 0
  name      = var.vpc_name
  direction = "INBOUND"

  security_group_ids = [
    aws_security_group.vpc[0].id
  ]

  dynamic "ip_address" {
    for_each = module.vpc.private_subnets
    content {
      subnet_id = ip_address.value
    }
  }

  tags = merge(var.global_tags,
    tomap({"Name"=var.vpc_name}))
}

# Forwarding DNS queries to the *.wiley.com networks
resource "aws_route53_resolver_endpoint" "outbound" {
  count     = var.enable_private_resolver ? 1 : 0
  name      = "${var.vpc_name}-outbound"
  direction = "OUTBOUND"

  security_group_ids = [
    aws_security_group.vpc[0].id
  ]

  dynamic "ip_address" {
    for_each = module.vpc.private_subnets
    content {
      subnet_id = ip_address.value
    }
  }

  tags = merge(var.global_tags,
    tomap({"Name"=var.vpc_name}))
}

resource "aws_route53_resolver_rule" "fwd" {
  count                = var.enable_private_resolver ? 1 : 0
  domain_name          = "wiley.com"
  name                 = "forward-to-wiley-com"
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound[count.index].id

  target_ip {
    ip = "10.201.0.53"
  }

  target_ip {
    ip = "10.200.0.53"
  }

  tags = merge(var.global_tags,
    tomap({"Name"=var.vpc_name}))
}

resource "aws_route53_resolver_rule_association" "outbound" {
  count            = var.enable_private_resolver ? 1 : 0
  resolver_rule_id = aws_route53_resolver_rule.fwd[count.index].id
  vpc_id           = module.vpc.vpc_id
}

# used for testing/verification
resource "aws_route53_record" "hello" {
  count   = var.enable_private_resolver ? 1 : 0
  zone_id = aws_route53_zone.private[0].id
  name    = "hello.${var.zone_name}"
  type    = "TXT"
  ttl     = "30"
  records = [
    "Hello, Mozart!"
  ]
}

output "mozart_private_hello_fqdn" {
  value = var.enable_private_resolver ? aws_route53_record.hello[0].fqdn : null
}

#####################################################################


# TGW Configs

resource "aws_flow_log" "vpc" {
  log_destination          = "arn:aws:s3:::${var.vpc_flow_log_bucket}/${module.vpc.vpc_id}"
  log_destination_type     = "s3"
  traffic_type             = "ALL"
  vpc_id                   = module.vpc.vpc_id
  log_format               = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status} $${vpc-id} $${subnet-id} $${instance-id}"
  max_aggregation_interval = "60"
}

module "accept_tgw_share_mozart" {
  count                  = var.accept_tgw_share ? 1 : 0
  source                 = "git@github.com:wiley/do-networking-tgw.git//modules/accept_tgw_share?ref=v0.0.4"
  tgw_resource_share_arn = var.tgw_resource_share_arn
}

module "mozart_attach_vpc_to_tgw" {
  source = "git@github.com:wiley/do-networking-tgw.git//modules/attach_vpc_to_tgw?ref=v0.0.4"

  # Hard coded the tqw_id because of creationg tgw is not a part of that.
  tgw_id          = "tgw-089488869f917cdaa"
  vpc_id          = module.vpc.vpc_id
  tgw_route_cidrs = var.tgw_network_cidrs

  vpc_route_table_ids = [module.vpc.private_route_table_ids[0]]
  subnet_ids          = module.vpc.private_subnets

  tags = merge(var.global_tags,
    tomap({"Name"=  var.vpc_name}))
}

# Security Groups

resource "aws_security_group" "k8s-internal" {
  count       = var.enable_eks_sg ? 1 : 0
  name        = "k8s-internal-access"
  description = "Allows access to k8s APIs from internal subnets"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from Private Ranges"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16", "172.16.0.0/12", "10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.global_tags,
    tomap({"Name"="k8s-internal-access"}))

  lifecycle {
    ignore_changes = [
      ingress,
      egress
    ]
  }
}
