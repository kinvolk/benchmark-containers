FROM alpine as builder
WORKDIR /usr/src/iperf
ENV IPERF_VER=3.7
ADD  https://github.com/esnet/iperf/archive/${IPERF_VER}.tar.gz .
RUN apk add --update alpine-sdk libtool autoconf automake openssl-dev
RUN tar xzf ${IPERF_VER}.tar.gz && \
    cd iperf-${IPERF_VER} && \
    ./bootstrap.sh && \
    ./configure --disable-profiling && \
    make -j install DESTDIR=/iperf3

FROM benchmark-base
MAINTAINER Kinvolk

# iperf3
RUN apk add --update --no-cache openssl
COPY --from=builder /iperf3/ /

# The benchmark uses jq to parse the JSON output
RUN apk add --update --no-cache jq

# Runnable scripts
COPY run-benchmark.sh /usr/local/bin/run-benchmark.sh
COPY run-server.sh /usr/local/bin/run-server.sh
