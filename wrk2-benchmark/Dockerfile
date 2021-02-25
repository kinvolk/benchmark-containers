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
