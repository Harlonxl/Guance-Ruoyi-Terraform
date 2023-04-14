FROM centos:7.9.2009
MAINTAINER Harlon

# 添加中文支持
RUN rm -rf /etc/localtime && ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN yum -y install kde-l10n-Chinese && yum -y reinstall glibc-common
RUN localedef -c -f UTF-8 -i zh_CN zh_CN.utf8
ENV LC_ALL zh_CN.utf8

# 添加terraform
RUN yum -y install wget unzip git
RUN wget https://releases.hashicorp.com/terraform/1.3.9/terraform_1.3.9_linux_amd64.zip
RUN unzip terraform_1.3.9_linux_amd64.zip
RUN mv terraform /usr/local/bin/

RUN mkdir -p /apps/aliyun
COPY ./aliyun/template /apps/aliyun/template
COPY ./aliyun/main.tf /apps/aliyun/
COPY ./aliyun/variables.tf /apps/aliyun/
RUN cd /apps/aliyun/ && /usr/local/bin/terraform init

RUN mkdir -p /apps/aws
COPY ./aws/template /apps/aws/template
COPY ./aws/resource /apps/aws/resource
COPY ./aws/main.tf /apps/aws/
COPY ./aws/variables.tf /apps/aws/
RUN cd /apps/aws/ && /usr/local/bin/terraform init

WORKDIR /apps

CMD ["tail", "-f", "/dev/null"]
