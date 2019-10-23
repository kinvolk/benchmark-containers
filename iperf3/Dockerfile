FROM alpine as builder
WORKDIR /iperf-build
ENV IPERF_VER=3.7
ADD  https://github.com/esnet/iperf/archive/${IPERF_VER}.tar.gz .
RUN apk add --update alpine-sdk libtool autoconf automake openssl-dev
RUN tar xzf ${IPERF_VER}.tar.gz && \
    cd iperf-${IPERF_VER} && \
    ./bootstrap.sh && \
    ./configure --disable-profiling && \
    make -j install DESTDIR=/iperf3


FROM alpine
MAINTAINER Kinvolk
# dstat
RUN apk add --update --no-cache py2-six
COPY --from=dstat-builder /dstat/dstat /usr/local/bin
COPY --from=dstat-builder /dstat/plugins /usr/local/bin/
# iperf3
RUN apk add --update --no-cache openssl
COPY --from=builder /iperf3/ /
