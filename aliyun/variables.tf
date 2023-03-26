# 观测云 rum application，获取方式：https://console.guance.com/zh/rum/setting
variable "applicationId" {
  default = "ruoyi_web"
}

# 观测云 token，获取方式：https://console.guance.com/zh/workspace/detail
variable "token" {
  default = "tkn_5c73xxxxxxxeaf2"
}

# 若依服务名称前缀，按需设置
variable "prefix" {
  default = "ruoyi"
}

# 若依服务日志 source，按需设置
variable "log_source" {
  default = "ruoyi-log"
}

# 地域ID，参见：https://help.aliyun.com/document_detail/472081.html
variable "region" {
  default = "cn-guangzhou"
}

# 资源组ID，按需配置，获取链接：https://resourcemanager.console.aliyun.com/resource-groups
variable "resource_group_id" {
  default = ""
}

# VPC名称，按需设置
variable "vpc_name" {
  default = "default"
}

# 安全组名称，按需设置
variable "security_group_name" {
  default = "default"
}

# ecs名称，按需设置
variable "ecs_name" {
  default = "default"
}

# ecs密码
variable "ecs_password" {
  default = "admin@123"
}

