terraform {
  required_providers {
    guance = {
      source  = "GuanceCloud/guance"
      version = "~> 0.0.4"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "guance" {
  region = var.guance_region
  access_token  = var.api_key
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.202*-x86_64-ebs"]
  }
}

data "aws_ec2_instance_types" "types_ds" {
  filter {
    name   = "vcpu-info.default-cores"
    values = ["2"]
  }
  filter {
    name   = "memory-info.size-in-mib"
    values = ["8192"]
  }
  filter {
    name   = "processor-info.supported-architecture"
    values = ["x86_64"]
  }
}

# create vpc
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc_name
  cidr = "10.10.0.0/16"

  azs             = data.aws_availability_zones.available.names
  public_subnets  = ["10.10.0.0/24", "10.10.10.0/24"]
  private_subnets = ["10.10.1.0/24", "10.10.11.0/24"]

  enable_dns_hostnames = true
  enable_dns_support   = true
}

# create security group
module "service_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name   = var.security_group_name
  vpc_id = module.vpc.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp", "ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 30000
      to_port     = 30000
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      rule        = "all-tcp"
      cidr_blocks = "10.10.0.0/16"
    },
  ]

  ingress_ipv6_cidr_blocks = []
  egress_rules             = ["all-all"]
  egress_cidr_blocks       = ["0.0.0.0/0"]
  egress_ipv6_cidr_blocks  = []
}

# create key pair
resource "aws_key_pair" "id_rsa" {
  key_name   = "aws_key_pair"
  public_key = file("${path.cwd}/resource/ssh/id_rsa.pub")
}

# create ec2
module "ec2_cluster" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 2.0"

  name           = var.ec2_name
  instance_count = 2

  ami           = data.aws_ami.amazon.id
  instance_type = data.aws_ec2_instance_types.types_ds.instance_types.0
  key_name      = resource.aws_key_pair.id_rsa.key_name

  monitoring                  = true
  vpc_security_group_ids      = [module.service_sg.security_group_id]
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
}

# modify resolve.conf
resource "null_resource" "k8s-node" {
  triggers = {
    instance_ids = join(",", module.ec2_cluster.id)
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = element(module.ec2_cluster.public_ip, 1)
    private_key = file("${path.cwd}/resource/ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [<<EOF
           echo "nameserver 114.114.114.114" | sudo tee -a /etc/resolv.conf
           # 卸载自带 docker
           sudo yum -y remove docker

           # 设置 root 密码
           echo root:${var.ec2_password} |sudo chpasswd root
           sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
           sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
           sudo service sshd restart
         EOF
    ]
  }
}

# create k8s cluster
resource "null_resource" "k8s-master" {
  triggers = {
    instance_ids = join(",", module.ec2_cluster.id)
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    host        = element(module.ec2_cluster.public_ip, 0)
    private_key = file("${path.cwd}/resource/ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [<<EOF
           echo "nameserver 114.114.114.114" | sudo tee -a /etc/resolv.conf
           sudo yum -y install wget

           # 卸载自带 docker
           sudo yum -y remove docker

           # 设置 root 密码
           echo root:${var.ec2_password} |sudo chpasswd root
           sudo sed -i 's/^.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config;
           sudo sed -i 's/^.*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config;
           sudo service sshd restart

           wget  https://guance-south.oss-cn-guangzhou.aliyuncs.com/sealos_4.1.5_linux_amd64.tar.gz  &&  \
                tar -zxvf sealos_4.1.5_linux_amd64.tar.gz sealos &&  chmod +x sealos && sudo mv sealos /usr/bin

           # 部署 kubernetes 集群
           wget https://guance-south.oss-cn-guangzhou.aliyuncs.com/kubernetes.1.24.0.tar
           wget https://guance-south.oss-cn-guangzhou.aliyuncs.com/calico.3.22.1.tar
           sudo sealos load -i kubernetes.1.24.0.tar
           sudo sealos load -i calico.3.22.1.tar
           sudo sealos run kubernetes:v1.24.0 calico:v3.22.1 --masters ${module.ec2_cluster.private_ip.0} \
                --nodes ${module.ec2_cluster.private_ip.1} --passwd ${var.ec2_password}
           sleep 10;
         EOF
    ]
  }
}

# apply ruoyi application
resource "null_resource" "ruoyi" {
  triggers = {
    instance_ids = join(",", module.ec2_cluster.id)
  }

  connection {
    type     = "ssh"
    user     = "root"
    password = var.ec2_password
    host     = element(module.ec2_cluster.public_ip, 0)
  }

  provisioner "remote-exec" {
    inline = [<<EOF
           # 判断集群状态
           while true; do
             status=`kubectl get no -o wide | grep ${module.ec2_cluster.private_ip.0} | awk '{print $2}'`;
             if [[ "$status" == "Ready" ]]; then echo "kubernetes ready"; break; fi
             sleep 5;
           done
           sleep 10;

           # 部署若依系统
           wget https://guance-south.oss-cn-guangzhou.aliyuncs.com/ruoyi-terraform-deploy.2.3.tar.gz
           tar xzvf ruoyi-terraform-deploy.2.3.tar.gz
           ./deploy_ruoyi.sh \
           --applicationid=${var.applicationId} \
           --allowedtracingorigins="['http://${module.ec2_cluster.public_ip.0}:30000', 'http://${module.ec2_cluster.public_ip.1}:30000']" \
           --dataway="${var.dataway}?token=${var.token}" \
           --prefix=${var.prefix} \
           --logsource=${var.log_source}

           sleep 60
         EOF
    ]
  }

  depends_on = [
    resource.null_resource.k8s-master
  ]
}

# create guance pipeline
resource "guance_pipeline" "ruoyi-log" {
  name     = var.log_source
  category = "logging"
  source = [
    var.log_source
  ]
  is_default = false
  is_force   = false

  content = <<EOF
    grok(_, "%%{TIMESTAMP_ISO8601:time} %%{NOTSPACE:thread_name} %%{LOGLEVEL:status}%%{SPACE}%%{NOTSPACE:class_name} - \\[%%{NOTSPACE:method_name},%%{NUMBER:line}\\] - %%{DATA:service} %%{DATA:trace_id} %%{DATA:span_id} - %%{GREEDYDATA:msg}")
    default_time(time, "Asia/Shanghai")
    EOF

  depends_on = [
    resource.null_resource.ruoyi
  ]
}

resource "guance_pipeline" "ruoyi-nginx" {
  name     = "${var.prefix}-nginx"
  category = "logging"
  source = [
    "${var.prefix}-nginx"
  ]
  is_default = false
  is_force   = false

  content = <<EOF
    json(_, opentracing_context_x_datadog_trace_id, trace_id)
    json(_, `@timestamp`, time)
    json(_, status)
    group_between(status, [200, 300], "OK")
    default_time(time)
    EOF

  depends_on = [
    resource.null_resource.ruoyi
  ]
}

resource "guance_blacklist" "ruoyi-blacklist" {
  source = {
    type = "rum"
    name = var.applicationId
  }

  filter_rules = [
    {
      name      = "resource_url_path"
      operation = "match"
      condition = "and"
      values    = ["/rum/*"]
    }
  ]

  depends_on = [
    resource.null_resource.ruoyi
  ]
}

module "k8s-dashboard" {
  source  = "GuanceCloud/dashboard/guance//modules/kubernetes"
  version = "0.0.3"
  name    = "Kubernetes 监控视图"
}

data "guance_members" "members" {
  filters = [
    {
      name   = "email"
      values = [var.email]
    }
  ]
}

resource "guance_membergroup" "membergroup" {
  name       = "guance-tf-membergroup"
  member_ids = data.guance_members.members.items[*].id

    depends_on = [
      resource.null_resource.ruoyi
    ]
}

resource "guance_alertpolicy" "alertpolicy" {
  name           = "guance-tf-alertpolicy"
  silent_timeout = "15m"

  statuses = [
    "critical",
    "error",
    "warning",
    "info",
    "ok",
    "nodata",
    "nodata_ok",
    "nodata_as_ok",
  ]

  alert_targets = [
    {
      type = "member_group"
      member_group = {
        id = guance_membergroup.membergroup.id
      }
    },
  ]

  depends_on = [
    resource.null_resource.ruoyi
  ]
}

module "docker" {
  source  = "GuanceCloud/monitor/guance//modules/docker"
  version         = "0.0.2"
  alert_policy_id = guance_alertpolicy.alertpolicy.id
  dashboard_id = module.k8s-dashboard.dashboard_id
}

data "template_file" "result_out_script" {
  template = file("${path.root}/template/result_out.tpl")
  vars = {
    ec2_ip1 = module.ec2_cluster.public_ip.1,
    ec2_ip0 = module.ec2_cluster.public_ip.0,
  }
  depends_on = [
    resource.null_resource.ruoyi
  ]
}

resource "local_file" "create_result_out_script" {
  content  = data.template_file.result_out_script.rendered
  filename = "${path.root}/result_out.md"
  depends_on = [
    data.template_file.result_out_script
  ]
}