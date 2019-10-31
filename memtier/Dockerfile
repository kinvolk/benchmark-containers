FROM alpine as builder
MAINTAINER Kinvolk
WORKDIR /usr/src/memcached
ENV MEMCACHE_VER=1.5.19
ADD https://github.com/memcached/memcached/archive/${MEMCACHE_VER}.tar.gz .
RUN apk add --update alpine-sdk autoconf automake pcre-dev libevent-dev zlib-dev linux-headers
RUN tar xzf ${MEMCACHE_VER}.tar.gz &&\
    cd memcached-${MEMCACHE_VER} && \
    ./autogen.sh && \
    ./configure --enable-arm-crc32 && \
    make -j && \
    make DESTDIR=/memcached install

WORKDIR /usr/src/redis
ENV REDIS_VER=5.0.6
ADD https://github.com/antirez/redis/archive/${REDIS_VER}.tar.gz .
RUN tar xzf ${REDIS_VER}.tar.gz && \
    cd redis-${REDIS_VER} && \
    make -j && \
    make PREFIX=/redis/usr install

WORKDIR /usr/src/memtier
ENV MEMTIER_VER=1.2.17
ADD https://github.com/RedisLabs/memtier_benchmark/archive/${MEMTIER_VER}.tar.gz .
RUN tar xzf ${MEMTIER_VER}.tar.gz && \
    cd memtier_benchmark-${MEMTIER_VER} && \
    autoreconf -ivf && \
    ./configure && \
     make -j && \
     make DESTDIR=/memtier install


FROM alpine
MAINTAINER Kinvolk
# dstat
RUN apk add --update --no-cache py2-six
COPY --from=dstat-builder /dstat/dstat /usr/local/bin
COPY --from=dstat-builder /dstat/plugins /usr/local/bin/
# lscpu
RUN apk add --update --no-cache util-linux
# memcached, redis, memtier
RUN apk add --update --no-cache pcre libevent zlib so:libstdc++.so.6 so:libgcc_s.so.1
COPY --from=builder /memcached/ /
COPY --from=builder /redis/ /
COPY --from=builder /memtier/ /
RUN adduser -u 1000 -D benchmark
