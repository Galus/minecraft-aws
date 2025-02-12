
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  // Optionally Enable TF Remote State - S3 Bucket needs to be manually created.
  # backend "s3" {
  #   bucket = "s3-remote-state-bucket"
  #   key    = "state"
  #   region = "us-east-1"
  # }
}

provider "archive" {}

provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "minecraft"
      DeployedBy  = "Terraform"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"

  default_tags {
    tags = merge(local.tags, {
      Environment = "dev"
      Project     = "minecraft"
      DeployedBy  = "Terraform"
    })
  }
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  vpc_id     = data.aws_vpc.default.id
  tags = {
    terraform = true,
    by        = data.aws_caller_identity.current.arn
  }
}

module "minecraft" {
  source = "../minecraft"
  providers = {
    aws           = aws
    aws.us-east-1 = aws.us-east-1
  }
  region        = "us-east-1"
  account       = local.account_id
  vpc_id        = local.vpc_id
  /* ATTENTION: If your domain is registered with AWS Route53 you must import
   * your aws_route53_zone state so you don't create duplicate hosted zones
   * which will fail your SES domain identity verification and break your
   * domain's DNS. 
   * https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone#import
   *
   * Ex: terraform import module.minecraft.aws_route53_zone.main Z1D633PJN98FT9
   *     where 'Z1D633PJN98FT9' is the Hosted zone ID.
   *
   */
  domain_name   = "example.com"
  cluster_name  = "minecraft"
  service_name  = "minecraft-server"
  s3_bucket_arn = "arn:aws:s3:::example-com-us-east-1"
  minecraft_server_cpu    = 1024
  minecraft_server_memory = 2048
  // optional - enabling this allow you to get into your ecs container:
  // ex: aws ecs execute-command --cluster minecraft --command "/bin/sh" --container minecraft-server --interactive --task 7b26500738354a4ea75cb4925999a4f4 
  ecs_service_enable_execute_command = false
  // optional
  extra_minecraft_server_env_vars = {
    // "Version of Minecraft to deploy"
    // https://github.com/itzg/docker-minecraft-server/blob/master/README.md#versions
    "VERSION" = "LATEST"
    // "Type of Minecraft to deploy (FORGE,FABRIC,SPIGOT,etc...)"
    // https://github.com/itzg/docker-minecraft-server/blob/master/README.md#server-types
    "TYPE" = "FORGE"
    // "Configures initial (Xms) and max (Xmx) JVM memory heap settings"
    // https://github.com/itzg/docker-minecraft-server/blob/master/README.md#memory-limit
    "MEMORY" = "1G"
  }
  // optional
  extra_ingresses = [
    # github.com/henkelmax/simple-voice-chat mod
    {
      protocol    = "udp"
      from_port   = 24454
      to_port     = 24454
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
