# docker build -t benchmark-base-debian --file=../common/Dockerfile.debian ../common/
FROM mysql:8

LABEL maintainer="Kinvolk"

RUN apt-get update && \
    apt-get install -y curl psmisc && \
    curl https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | bash && \
    apt -y install sysbench

COPY --from=benchmark-base-debian /usr/local/bin/cpu.sh /usr/local/bin/output.sh /usr/local/bin/
COPY run-server.sh run-benchmark.sh /usr/local/bin/
COPY my.cnf /etc/mysql/my.cnf
