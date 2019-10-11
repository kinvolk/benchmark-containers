FROM alpine as builder
MAINTAINER Kinvolk

WORKDIR /usr/src
RUN apk add --update alpine-sdk libaio-dev zlib-dev linux-headers coreutils
RUN mkdir /fio && cd /fio   && \
    wget https://github.com/axboe/fio/archive/fio-3.15.tar.gz && \
    tar xzf fio-3.15.tar.gz && \
    cd fio-fio-3.15 && \
    ./configure && \
    make -j && \
    strip fio && \
    mv fio ..
RUN cd / && git clone https://github.com/dagwieers/dstat.git
COPY ./dstat-types.patch /dstat/dstat-types.patch 
RUN cd /dstat && \
    patch <dstat-types.patch


FROM alpine
MAINTAINER Kinvolk
RUN apk add --update --no-cache libaio zlib so:libgcc_s.so.1 py2-six
COPY --from=builder /fio/fio /usr/local/bin
COPY --from=builder /dstat/dstat /usr/local/bin
COPY --from=builder /dstat/plugins /usr/local/bin/
