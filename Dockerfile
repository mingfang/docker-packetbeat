FROM ubuntu:14.04
 
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN locale-gen en_US en_US.UTF-8
ENV LANG en_US.UTF-8

#Runit
RUN apt-get install -y runit 
CMD /usr/sbin/runsvdir-start

#SSHD
RUN apt-get install -y openssh-server && \
    mkdir -p /var/run/sshd && \
    echo 'root:root' |chpasswd
RUN sed -i "s/session.*required.*pam_loginuid.so/#session    required     pam_loginuid.so/" /etc/pam.d/sshd
RUN sed -i "s/PermitRootLogin without-password/#PermitRootLogin without-password/" /etc/ssh/sshd_config

#Utilities
RUN apt-get install -y vim less net-tools inetutils-ping wget curl git telnet nmap socat dnsutils netcat tree htop unzip sudo software-properties-common

#Install Oracle Java 7
RUN echo 'deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main' > /etc/apt/sources.list.d/java.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EEA14886 && \
    apt-get update && \
    echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections && \
    apt-get install -y oracle-java7-installer

#ElasticSearch
RUN curl https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.4.0.tar.gz | tar xz && \
    mv elasticsearch-* elasticsearch

#Packet's Kibana fork
RUN curl -L https://github.com/packetbeat/kibana/releases/download/v3.1.0-pb/kibana-3.1.0-packetbeat.tar.gz | tar zx && \
    mv kibana* kibana

#NGINX
RUN apt-get install -y nginx

RUN apt-get -y -q install libpcap0.8

RUN wget https://github.com/packetbeat/packetbeat/releases/download/v0.4.1/packetbeat_0.4.1-1_amd64.deb && \
    dpkg -i packetbeat*.deb && \
    rm packetbeat*.deb

ADD packetbeat.conf /etc/packetbeat/packetbeat.conf
ADD nginx.conf /etc/nginx/nginx.conf
RUN sed -i -e 's|elasticsearch:.*|elasticsearch: "http://"+window.location.hostname + ":" + window.location.port,|' /kibana/config.js

#Add runit services
ADD sv /etc/service 
    
RUN wget https://raw.githubusercontent.com/packetbeat/packetbeat/master/packetbeat.template.json
RUN curl -L https://github.com/packetbeat/dashboards/archive/v0.4.1.tar.gz | tar zx

RUN runsv /etc/service/elasticsearch & \
    until curl http://localhost:9200; do echo "waiting for ElasticSearch to come online..."; sleep 3; done && \
    curl -XGET 'http://localhost:9200/_cluster/health?wait_for_status=green&timeout=10s' && \
    curl -XPUT 'http://localhost:9200/_template/packetbeat' -d@packetbeat.template.json && \
    curl -XGET 'http://localhost:9200/_template/packetbeat?pretty' && \
    cd dashboard* && \
    ./load.sh localhost && \
    sv stop elasticsearch
