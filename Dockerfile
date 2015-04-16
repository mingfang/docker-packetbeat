FROM ubuntu:14.04

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN locale-gen en_US en_US.UTF-8
ENV LANG en_US.UTF-8
RUN echo "export PS1='\e[1;31m\]\u@\h:\w\\$\[\e[0m\] '" >> /root/.bashrc

#Runit
RUN apt-get install -y runit
CMD export > /etc/envvars && /usr/sbin/runsvdir-start
RUN echo 'export > /etc/envvars' >> /root/.bashrc

#Utilities
RUN apt-get install -y vim less net-tools inetutils-ping wget curl git telnet nmap socat dnsutils netcat tree htop unzip sudo software-properties-common jq psmisc

#Install Oracle Java 8
RUN add-apt-repository ppa:webupd8team/java -y && \
    apt-get update && \
    echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections && \
    apt-get install -y oracle-java8-installer
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

#ElasticSearch
RUN wget -O - https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.4.3.tar.gz | tar xz && \
    mv elasticsearch-* elasticsearch

#Packetbeat's Kibana fork
RUN wget -O - https://github.com/packetbeat/kibana/releases/download/v3.1.2-pb/kibana-3.1.2-packetbeat.tar.gz | tar zx && \
    mv kibana* kibana

#NGINX
RUN apt-get install -y nginx

ADD nginx.conf /etc/nginx/nginx.conf
RUN sed -i -e 's|elasticsearch:.*|elasticsearch: "http://"+window.location.hostname + ":" + window.location.port,|' /kibana/config.js

#Add Dashboards    
RUN wget https://raw.githubusercontent.com/packetbeat/packetbeat/v0.5.0/packetbeat.template.json
RUN curl -L https://github.com/packetbeat/dashboards/archive/v0.5.0K3.tar.gz | tar zx

#Add HTTP Search Dashboard
#ADD HTTP-Search-1418699625702.json /dashboards-0.4.1/dashboards/
#RUN mv /dashboards-0.4.1/dashboards/HTTP-Search-1418699625702.json /dashboards-0.4.1/dashboards/HTTP\ Search-1418699625702.json && \
#    cd /dashboards-0.4.1/generated && \
#    python generate.py

#Add runit services
ADD sv /etc/service 

RUN runsv /etc/service/elasticsearch & \
    until curl http://localhost:9200; do echo "waiting for ElasticSearch to come online..."; sleep 3; done && \
    curl -XGET 'http://localhost:9200/_cluster/health?wait_for_status=green&timeout=10s' && \
    curl -XPUT 'http://localhost:9200/_template/packetbeat' -d@packetbeat.template.json && \
    curl -XGET 'http://localhost:9200/_template/packetbeat?pretty' && \
    cd dashboard* && \
    ./load.sh localhost && \
    curl -XGET 'http://localhost:9200/_cluster/health?wait_for_status=green&timeout=10s' && \
    sv stop elasticsearch
