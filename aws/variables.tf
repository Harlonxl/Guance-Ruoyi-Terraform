# 观测云 rum application，获取方式：https://console.guance.com/zh/rum/setting
variable "applicationId" {
  default = "aws_ruoyi_web"
}

# 观测云 token，获取方式：https://console.guance.com/zh/workspace/detail
variable "token" {
  default = "tkn_5c7xxxxxxaf2"
}

# 若依服务名称前缀，按需设置
variable "prefix" {
  default = "aws_ruoyi"
}

# 若依服务日志 source，按需设置
variable "log_source" {
  default = "aws-ruoyi-log"
}

# 地域ID，参见：https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#using-regions-availability-zones-describe
variable "region" {
  default = "cn-north-1"
}

# ecs密码
variable "ec2_password" {
  default = "admin@123"
}

# VPC名称，按需设置
variable "vpc_name" {
  default = "aws-terraform-default"
}

# 安全组名称，按需设置
variable "security_group_name" {
  default = "aws-terraform-default"
}

# ec2名称，按需设置
variable "ec2_name" {
  default = "aws-terraform-default"
}