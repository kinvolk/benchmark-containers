# docker build -t benchmark-base-centos --file=../common/Dockerfile.centos ../common/
FROM centos:7

LABEL maintainer="Kinvolk"

RUN yum install -y https://repo.mysql.com/mysql-community-release-el7.rpm && \
    yum install -y epel-release && \
    yum install -y mysql mysql-server jq psmisc && \
    curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.rpm.sh | bash && \
    yum -y install sysbench && \
    yum clean all

COPY --from=benchmark-base-centos /usr/local/bin/cpu.sh /usr/local/bin/output.sh /usr/local/bin/
COPY run-server.sh run-benchmark.sh /usr/local/bin/
COPY my.cnf /etc/mysql/my.cnf
