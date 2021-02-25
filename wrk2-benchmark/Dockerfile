FROM alpine as builder
WORKDIR /usr/src
RUN apk add --update alpine-sdk zlib-dev openssl-dev
ADD https://github.com/kinvolk/wrk2/archive/master.zip .
RUN unzip master.zip && \
    cd wrk2-master && \
    make -j && \
    strip wrk

FROM benchmark-base
MAINTAINER Kinvolk

# wrk2
RUN apk add --update --no-cache so:libcrypto.so.1.1 so:libssl.so.1.1 so:libgcc_s.so.1
COPY --from=builder /usr/src/wrk2-master/wrk /usr/local/bin/
ADD body-100-report.lua /usr/local/share/wrk2/body-100-report.lua

# nginx serving 404 on port 9000 running as benchmark user (switches if started as root)
RUN apk add --update --no-cache nginx
RUN adduser -u 1000 -D benchmark
RUN sed -i 's/user nginx;/user benchmark;/g' /etc/nginx/nginx.conf
RUN sed -i 's/80 default_server/9000 default_server/g' /etc/nginx/conf.d/default.conf
RUN mkdir /run/nginx
RUN chown benchmark:benchmark -R /var/lib/nginx /run/nginx/ /var/log/nginx

# Runnable scripts
COPY run-benchmark.sh /usr/local/bin/run-benchmark.sh
COPY run-server.sh /usr/local/bin/run-server.sh
