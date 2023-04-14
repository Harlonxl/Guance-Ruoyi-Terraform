# 观测云若依Demo一键部署

## 准备工作

### 1. 使用 docker 镜像部署（推荐）
> 注意：terraform 构建信息存储至容器中，未释放资源请勿停止容器

Docker环境安装：

[MAC 环境安装docker](https://www.runoob.com/docker/macos-docker-install.html) | [Windows 环境安装docker](https://www.runoob.com/docker/windows-docker-install.html) | [CentOS 环境安装docker](https://www.runoob.com/docker/centos-docker-install.html)

### 2. 使用本地环境部署
本地安装：

[Terraform安装](https://www.terraform.io/downloads.html) 

[观测云若依Demo Git 地址](https://github.com/Harlonxl/Guance-Ruoyi-Terraform)


## 快速构建观测云若依Demo
### 1. 第一步：拉取一键安装镜像
> 本地环境部署跳到第二步
```shell
docker run --name guance-ruoyi-terraform -d -it registry.cn-guangzhou.aliyuncs.com/guance-south/guance-ruoyi-terraform:v1.2 /bin/bash
```
进入容器
```shell
docker exec -it guance-ruoyi-terraform /bin/bash
```

### 2. 第二步：修改变量
### 2.1 创建环境变量，存放身份认证信息
- 阿里云配置方式

`ALICLOUD_ACCESS_KEY` 和 `ALICLOUD_SECRET_KEY` 获取方式：https://ram.console.aliyun.com/manage/ak
```shell
export ALICLOUD_ACCESS_KEY="LTAIUrZCw3********"
export ALICLOUD_SECRET_KEY="zfwwWAMWIAiooj14GQ2*************"
```

- AWS 配置方式

`AWS_ACCESS_KEY_ID` 和 `AWS_SECRET_ACCESS_KEY` 获取方式：https://docs.aws.amazon.com/zh_cn/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_RotateAccessKey

```shell
export AWS_ACCESS_KEY_ID="AKIAUJGWAI********"
export AWS_SECRET_ACCESS_KEY="r5R2ft1c48Xzo72+Mb*************"
```

### 2.2 修改项目目录下 ./variables.tf 文件中的变量
> 仔细阅读变量含义，按需进行修改

- 阿里云
```shell
cd aliyun
vi ./variables.tf
```

- AWS
```shell
cd aws
vi ./variables.tf
```

### 3. 第三步：快速构建
#### 3.1 初始化 terraform 依赖组件
> Dokcer 环境已做初始化，可跳过
```shell
terraform init
```

#### 3.2 查看 terraform 任务执行计划
```shell
terraform plan #查看terraform任务执行计划
```

#### 3.3 部署安装
```shell
terraform apply -auto-approve 
```

#### 3.4 查看访问方式及部署清单
```shell
cat result_out.md 
```

#### 3.5 资源回收

```shell
#查看 terraform state 资源清单
terraform state list 
```

```shell
#释放 terraform 创建资源
terraform destroy -auto-approve 
```

### 4. 第四步：配置观测云
> Todo: 利用观测云 terraform provider 可跳过此步骤，预计4月中旬

#### 4.1 设置业务日志 Pipeline
进入观测云控制台，「日志」-「文本处理 Pipeline」- 「新建Pipeline」
- 过滤：选择第二步设置的 source，默认为 ruoyi-log
- Pipeline 名称：按需设置，例如：ruoyi-log
- 定义解析规则：
```shell
grok(_, "%{TIMESTAMP_ISO8601:time} %{NOTSPACE:thread_name} %{LOGLEVEL:status}%{SPACE}%{NOTSPACE:class_name} - \\[%{NOTSPACE:method_name},%{NUMBER:line}\\] - %{DATA:service} %{DATA:trace_id} %{DATA:span_id} - %{GREEDYDATA:msg}")
default_time(time, "Asia/Shanghai")
```

#### 4.2 设置 nginx 日志 Pipeline
进入观测云控制台，「日志」-「文本处理 Pipeline」- 「新建Pipeline」
- 过滤：选择第二步设置的 source，默认为 ruoyi-nginx
- Pipeline 名称：按需设置，例如：ruoyi-nginx
- 定义解析规则：
```shell
json(_, opentracing_context_x_datadog_trace_id, trace_id)
json(_, `@timestamp`, time)
json(_, status)
group_between(status, [200, 300], "OK")
default_time(time)
```

#### 4.3 过滤前端请求
> 通过 nginx 代理方式上传 RUM 数据，导致 RUM Fetch/XHR 中有大量 /v1/write/rum、/v1/write/rum/replay 类似接口调用，设置过滤规则进行过滤

进入观测云控制台，「管理」-「黑名单」- 「新建黑名单」
- 访问来源：选择用户访问监测，以及对应的应用
- 过滤：选择所有，筛选条件：resource_url_path math /rum/*

## 其他资料
- [观测云若依Demo部署清单](https://github.com/Harlonxl/Observability/tree/master/ruoyi-terraform-deploy)
- [观测云若依Demo镜像清单](https://github.com/Harlonxl/Observability/tree/master/ruoyi-terraform-image)