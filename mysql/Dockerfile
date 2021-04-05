FROM alpine as builder
WORKDIR /sysbench
LABEL maintainer="Kinvolk"
ENV SYSBENCH_VER=1.0.20
ADD https://github.com/akopytov/sysbench/archive/${SYSBENCH_VER}.tar.gz .
RUN apk add --update alpine-sdk git linux-headers automake autoconf libtool libaio-dev openssl-dev libunwind-dev mysql-dev
RUN tar -xf ${SYSBENCH_VER}.tar.gz && \
  cd sysbench-${SYSBENCH_VER} && \
  export TARGET_LIBS=-lunwind;./autogen.sh && \
  ./configure && \
  make -j && \
  make DESTDIR=/sysbench/sysbench-install-root/ install

FROM benchmark-base
LABEL maintainer="Kinvolk"

# sysbench
RUN apk add --update --no-cache so:libgcc_s.so.1 so:libmariadb.so.3 so:libaio.so.1 curl jq mysql mysql-client && rm -f /var/cache/apk/*
COPY --from=builder /sysbench/sysbench-install-root/ /

VOLUME [ "/var/lib/mysql" ]
COPY my.cnf /etc/mysql/my.cnf
# Runnable scripts
COPY startup.sh /usr/local/bin/startup.sh
COPY run-benchmark.sh /usr/local/bin/run-benchmark.sh

# To start mysql server
RUN chmod 777 /usr/local/bin/startup.sh
RUN chmod 777 /usr/local/bin/run-benchmark.sh
