terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.17.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  profile = var.profile
}

resource "aws_appconfig_application" "main" {
  name        = "MoviesApp"
  description = "Watch movies anywhere"
}

### Hosted Feature Flags ###

resource "aws_appconfig_configuration_profile" "feature_flags_hosted" {
  application_id = aws_appconfig_application.main.id
  description    = "Feature flags that hosted by AppConfig"
  name           = "Hosted Feature Flags"
  location_uri   = "hosted"
  type           = "AWS.AppConfig.FeatureFlags"
}

resource "aws_appconfig_hosted_configuration_version" "feature_flags_hosted_v1" {
  application_id           = aws_appconfig_application.main.id
  configuration_profile_id = aws_appconfig_configuration_profile.feature_flags_hosted.configuration_profile_id
  description              = "Example Feature Flag Configuration Version"
  content_type             = "application/json"

  content = jsonencode({
    flags : {
      blackfriday : {
        name : "Black Friday Promotion",
        description : "Discount feature for the Black Friday sales.",
        _deprecation : {
          "status" : "planned"
        }
      },
      recommendations : {
        name : "Smart Recommendations",
        description : "Movie recommendations feature.",
        attributes : {
          itemsQuantity : {
            constraints : {
              type : "number",
              required : true
            }
          },
          someAttribute : {
            constraints : {
              type : "string",
              required : true
            }
          }
        }
      }
    },
    values : {
      blackfriday : {
        enabled : "true",
      },
      recommendations : {
        enabled : "true",
        itemsQuantity : 3,
        someAttribute : "Hello World"
      }
    },
    version : "1"
  })
}

resource "aws_appconfig_environment" "production" {
  name           = "PRODUCTION"
  description    = "MoviesApp configuration for Production"
  application_id = aws_appconfig_application.main.id

  # monitor {
  #   alarm_arn      = aws_cloudwatch_metric_alarm.example.arn
  #   alarm_role_arn = aws_iam_role.example.arn
  # }
}

resource "aws_appconfig_deployment_strategy" "example" {
  name                           = "Terraform MovieApp"
  description                    = "Terraform Deployment Strategy"
  deployment_duration_in_minutes = 0
  final_bake_time_in_minutes     = 3
  growth_factor                  = 100
  growth_type                    = "LINEAR"
  replicate_to                   = "NONE"
}

resource "aws_appconfig_deployment" "example" {
  application_id           = aws_appconfig_application.main.id
  configuration_profile_id = aws_appconfig_configuration_profile.feature_flags_hosted.configuration_profile_id
  configuration_version    = aws_appconfig_hosted_configuration_version.feature_flags_hosted_v1.version_number
  deployment_strategy_id   = aws_appconfig_deployment_strategy.example.id
  description              = "Terraform production deployment"
  environment_id           = aws_appconfig_environment.production.environment_id
}

locals {
  prefix = "/moviesapp/appconfig"
}

resource "aws_ssm_parameter" "application_id" {
  name  = "${local.prefix}/application-id"
  type  = "String"
  value = aws_appconfig_application.main.id
}

resource "aws_ssm_parameter" "configuration_profile_id" {
  name  = "${local.prefix}/configuration-profile-id"
  type  = "String"
  value = aws_appconfig_configuration_profile.feature_flags_hosted.configuration_profile_id
}

resource "aws_ssm_parameter" "environment_id" {
  name  = "${local.prefix}/environment-id"
  type  = "String"
  value = aws_appconfig_environment.production.environment_id
}
