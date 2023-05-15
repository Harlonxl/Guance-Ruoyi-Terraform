terraform {
  required_providers {
    guance = {
      source  = "GuanceCloud/guance"
      version = "~> 0.0.4"
    }
  }
}

provider "alicloud" {
  region = var.region
}

provider "guance" {
  region       = var.guance_region
  access_token = var.api_key
}

data "alicloud_zones" "default" {
  available_disk_category     = "cloud_efficiency"
  available_resource_creation = "VSwitch"
}

data "alicloud_images" "centos" {
  most_recent = true
  name_regex  = "^centos_7.*x64"
}

data "alicloud_instance_types" "types_ds" {
  cpu_core_count    = 4
  memory_size       = 8
  availability_zone = data.alicloud_zones.default.ids.0
}

# create vpc
module "vpc" {
  source = "alibaba/vpc/alicloud"

  vpc_name          = var.vpc_name
  vpc_cidr          = "172.16.0.0/16"
  resource_group_id = var.resource_group_id

  availability_zones = data.alicloud_zones.default.ids
  vswitch_cidrs      = ["172.16.0.0/16"]
}

# create security group
module "service_sg_with_ports" {
  source = "alibaba/security-group/alicloud"

  name   = var.security_group_name
  vpc_id = module.vpc.this_vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]

  ingress_ports = [50, 150]
  ingress_with_cidr_blocks_and_ports = [
    {
      ports       = "22"
      protocol    = "tcp"
      priority    = 1
      cidr_blocks = "0.0.0.0/0"
    },
    {
      ports       = "30000"
      protocol    = "tcp"
      priority    = 1
      cidr_blocks = "0.0.0.0/0"
    },
    {
      protocol = "icmp"
      priority = 20
    }
  ]
}

# create ecs
module "ecs_cluster" {
  source = "alibaba/ecs-instance/alicloud"

  number_of_instances = 2

  name                        = var.ecs_name
  use_num_suffix              = true
  image_id                    = data.alicloud_images.centos.ids.0
  instance_type               = data.alicloud_instance_types.types_ds.instance_types.0.id
  vswitch_id                  = module.vpc.this_vswitch_ids.0
  security_group_ids          = [module.service_sg_with_ports.this_security_group_id]
  associate_public_ip_address = true
  internet_max_bandwidth_out  = 10
  resource_group_id           = var.resource_group_id
  password                    = var.ecs_password

  system_disk_category = "cloud_efficiency"
  system_disk_size     = 50
}

# modify resolve.conf
resource "null_resource" "k8s-node" {
  triggers = {
    instance_ids = join(",", module.ecs_cluster.instance_ids)
  }

  connection {
    type     = "ssh"
    user     = "root"
    password = var.ecs_password
    host     = element(module.ecs_cluster.this_public_ip, 1)
  }

  provisioner "remote-exec" {
    inline = [<<EOF
           echo "nameserver 114.114.114.114" >> /etc/resolv.conf
         EOF
    ]
  }

}

# create k8s cluster
resource "null_resource" "k8s-master" {
  triggers = {
    instance_ids = join(",", module.ecs_cluster.instance_ids)
  }

  connection {
    type     = "ssh"
    user     = "root"
    password = var.ecs_password
    host     = element(module.ecs_cluster.this_public_ip, 0)
  }

  provisioner "remote-exec" {
    inline = [<<EOF
           echo "nameserver 114.114.114.114" >> /etc/resolv.conf

           wget  https://guance-south.oss-cn-guangzhou.aliyuncs.com/sealos_4.1.5_linux_amd64.tar.gz  &&  \
                tar -zxvf sealos_4.1.5_linux_amd64.tar.gz sealos &&  chmod +x sealos && mv sealos /usr/bin

           # 部署 kubernetes 集群
           wget https://guance-south.oss-cn-guangzhou.aliyuncs.com/kubernetes.1.24.0.tar
           wget https://guance-south.oss-cn-guangzhou.aliyuncs.com/calico.3.22.1.tar
           sealos load -i kubernetes.1.24.0.tar
           sealos load -i calico.3.22.1.tar
           sealos run kubernetes:v1.24.0 calico:v3.22.1 --masters ${module.ecs_cluster.private_ips.0} \
                --nodes ${module.ecs_cluster.private_ips.1} --passwd ${var.ecs_password}

           # 判断集群状态
           while true; do
             status=`kubectl get no -o wide | grep ${module.ecs_cluster.private_ips.0} | awk '{print $2}'`;
             if [[ "$status" == "Ready" ]]; then echo "kubernetes ready"; break; fi
             sleep 5;
           done
           sleep 10;

           # 部署若依系统
           wget https://guance-south.oss-cn-guangzhou.aliyuncs.com/ruoyi-terraform-deploy.2.3.tar.gz
           tar xzvf ruoyi-terraform-deploy.2.3.tar.gz
           ./deploy_ruoyi.sh \
           --applicationid=${var.applicationId} \
           --allowedtracingorigins="['http://${module.ecs_cluster.this_public_ip.0}:30000', 'http://${module.ecs_cluster.this_public_ip.1}:30000']" \
           --dataway="${var.dataway}?token=${var.token}" \
           --prefix=${var.prefix} \
           --logsource=${var.log_source}

           sleep 60

         EOF
    ]
  }

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
    resource.null_resource.k8s-master
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
    resource.null_resource.k8s-master
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
    resource.null_resource.k8s-master
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
    resource.null_resource.k8s-master
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
    resource.null_resource.k8s-master
  ]
}

module "docker" {
  source          = "GuanceCloud/monitor/guance//modules/docker"
  version         = "0.0.2"
  alert_policy_id = guance_alertpolicy.alertpolicy.id
  dashboard_id    = module.k8s-dashboard.dashboard_id
}

data "template_file" "result_out_script" {
  template = file("${path.root}/template/result_out.tpl")
  vars = {
    ecs_ip1 = module.ecs_cluster.this_public_ip.1,
    ecs_ip0 = module.ecs_cluster.this_public_ip.0,
  }
  depends_on = [
    resource.null_resource.k8s-master
  ]
}

resource "local_file" "create_result_out_script" {
  content  = data.template_file.result_out_script.rendered
  filename = "${path.root}/result_out.md"
  depends_on = [
    data.template_file.result_out_script
  ]
}
