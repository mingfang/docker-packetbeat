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
RUN wget -O - https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.7.2.tar.gz | tar xz && \
    mv elasticsearch-* elasticsearch

#Kibana
RUN wget -O - https://download.elastic.co/kibana/kibana/kibana-4.1.2-linux-x64.tar.gz | tar zx && \
    mv kibana* kibana

#Packetbeat Agent
RUN apt-get -y install libpcap0.8
RUN wget -O - https://download.elastic.co/beats/packetbeat/packetbeat-1.0.0-beta3-x86_64.tar.gz | tar zx && \
    mv packetbeat* packetbeat

#Add Dashboards    
RUN wget -O - http://download.elastic.co/beats/dashboards/beats-dashboards-1.0.0-beta3.tar.gz | tar zx && \
    mv beats-dashboards* packetbeat-dashboards

#Add runit services
ADD sv /etc/service 

RUN runsv /etc/service/elasticsearch & \
    until curl http://localhost:9200; do echo "waiting for ElasticSearch to come online..."; sleep 3; done && \
    curl -X GET 'http://localhost:9200/_cluster/health?wait_for_status=green&timeout=10s' && \
    curl -X PUT 'http://localhost:9200/_template/packetbeat' -d@/packetbeat/packetbeat.template.json && \
    curl -X GET 'http://localhost:9200/_template/packetbeat?pretty' && \
    curl -X POST 'http://localhost:9200/.kibana/index-pattern/packetbeat-*?op_type=create' -d '{"title":"packetbeat-*","timeFieldName":"timestamp","customFormats":"{}"}' && \
    cd packetbeat-dashboards && \
    ./load.sh && \
    curl -XGET 'http://localhost:9200/_cluster/health?wait_for_status=green&timeout=10s' && \
    sv stop elasticsearch
