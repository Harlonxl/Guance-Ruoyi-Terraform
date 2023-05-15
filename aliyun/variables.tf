# 【*】观测云 rum application id，如无可新建：「登录观测云控制台」-「用户访问监测」- 「应用列表」-「新建应用」-「应用 ID」
variable "applicationId" {
  default = "aliyun_ruoyi_web"
}

# 【*】观测云地域，地域列表：https://github.com/GuanceCloud/terraform-provider-guance
variable "guance_region" {
  default = "hangzhou"
}

# 【*】观测云 dk_dataway，获取方式：「登录观测云控制台」-「集成」-「DataKie」-「OpenWay」
variable "dataway" {
  default = "https://openway.guance.com"
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
  default = "aliyun-ruoyi"
}

# 若依服务日志 source，按需设置
variable "log_source" {
  default = "aliyun-ruoyi-log"
}

# 地域ID，参见：https://help.aliyun.com/document_detail/472081.html
variable "region" {
  default = "cn-guangzhou"
}

# ecs密码
variable "ecs_password" {
  default = "admin@123"
}

# 资源组ID，按需配置，获取链接：https://resourcemanager.console.aliyun.com/resource-groups
variable "resource_group_id" {
  default = ""
}

# VPC名称，按需设置
variable "vpc_name" {
  default = "aliyun-terraform-default"
}

# 安全组名称，按需设置
variable "security_group_name" {
  default = "aliyun-terraform-default"
}

# ecs名称，按需设置
variable "ecs_name" {
  default = "aliyun-terraform-default"
}