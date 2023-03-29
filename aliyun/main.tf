provider "alicloud" {
    region = var.region
}

data "alicloud_zones" "default" {
  available_disk_category     = "cloud_efficiency"
  available_resource_creation = "VSwitch"
}

data "alicloud_images" "centos" {
  most_recent = true
  name_regex  = "^centos_7.*x64"
}

# create vpc
module "vpc" {
  source = "alibaba/vpc/alicloud"

  vpc_name          = var.vpc_name
  vpc_cidr          = "172.16.0.0/16"
  resource_group_id = var.resource_group_id

  availability_zones = data.alicloud_zones.default.ids
  vswitch_cidrs      = ["172.16.0.0/16"]

  vpc_tags = {
    Created      = "Harlon"
  }

  vswitch_tags = {
    Created      = "Harlon"
  }
}

# create security group
module "service_sg_with_ports" {
  source = "alibaba/security-group/alicloud"

  name   = var.security_group_name
  vpc_id = module.vpc.this_vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp"]

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
  source  = "alibaba/ecs-instance/alicloud"

  number_of_instances = 2

  name                        = var.ecs_name
  use_num_suffix              = true
  image_id                    = data.alicloud_images.centos.ids.0
  instance_type               = "ecs.c7.xlarge"
  vswitch_id                  = module.vpc.this_vswitch_ids.0
  security_group_ids          = [module.service_sg_with_ports.this_security_group_id]
  associate_public_ip_address = true
  internet_max_bandwidth_out  = 10
  resource_group_id           = var.resource_group_id
  password                    = var.ecs_password

  system_disk_category = "cloud_essd"
  system_disk_size     = 50

  tags = {
    Created      = "Harlon"
  }
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

           # 部署若依系统
           wget https://guance-south.oss-cn-guangzhou.aliyuncs.com/ruoyi-terraform-deploy.2.0.tar.gz
           tar xzvf ruoyi-terraform-deploy.2.0.tar.gz
           ./deploy_ruoyi.sh \
           --applicationid=${var.applicationId} \
           --allowedtracingorigins="['http://${module.ecs_cluster.this_public_ip.0}:30000', 'http://${module.ecs_cluster.this_public_ip.1}:30000']" \
           --datakittoken=${var.token} \
           --prefix=${var.prefix} \
           --logsource=${var.log_source}

           sleep 60

         EOF
       ]
    }

}

data "template_file" "result_out_script" {
  template = file("${path.root}/template/result_out.tpl")
  vars = {
    ecs_ip1           = module.ecs_cluster.this_public_ip.1,
    ecs_ip0           = module.ecs_cluster.this_public_ip.0,
  }
  depends_on = [
    module.ecs_cluster
  ]
}

resource "local_file" "create_result_out_script" {
  content  = data.template_file.result_out_script.rendered
  filename = "${path.root}/result_out.md"
  depends_on = [
    data.template_file.result_out_script
  ]
}