# 【*】观测云 rum application id，如无可新建：「登录观测云控制台」-「用户访问监测」- 「应用列表」-「新建应用」-「应用 ID」
variable "applicationId" {
  default = "ruoyi_terraform_web"
}

# 【*】观测云地域，地域列表：https://github.com/GuanceCloud/terraform-provider-guance
variable "guance_region" {
  default = "ningxia"
}

# 【*】观测云 dk_dataway，获取方式：「登录观测云控制台」-「集成」-「DataKie」-「OpenWay」
variable "dataway" {
  default = "https://aws-openway.guance.com"
}

# 【*】观测云 token，获取方式：「登录观测云控制台」-「管理」- 「设置」-「Token」
variable "token" {
  default = "tkn_5c7xxxxxxaf2"
}

# 【*】观测云 API KEY，获取方式：「登录观测云控制台」-「API Key 管理」- 「新建Key」-「Key ID」
variable "api_key" {
  default = "wsak_f1d23xxxxxx37"
}

# 【*】观测云注册邮箱，创建告警通知时使用
variable "email" {
  default = "someone@guance.com"
}

# 若依服务名称前缀，按需设置
variable "prefix" {
  default = "aws-ruoyi"
}

# 若依服务日志 source，按需设置
variable "log_source" {
  default = "aws-ruoyi-log"
}

# 地域ID，参见：https://docs.aws.amazon.com/zh_cn/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#using-regions-availability-zones-describe
variable "region" {
  default = "cn-north-1"
}

# ec2 密码
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