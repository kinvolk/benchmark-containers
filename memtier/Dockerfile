FROM alpine as builder
LABEL maintainer="Kinvolk"
WORKDIR /usr/src/memcached
ENV MEMCACHE_VER=1.6.9
ADD https://github.com/memcached/memcached/archive/${MEMCACHE_VER}.tar.gz .
RUN apk add --update alpine-sdk autoconf automake pcre-dev libevent-dev zlib-dev linux-headers openssl-dev
RUN tar xzf ${MEMCACHE_VER}.tar.gz &&\
    cd memcached-${MEMCACHE_VER} && \
    ./autogen.sh && \
    ./configure --enable-arm-crc32 && \
    make -j && \
    make DESTDIR=/memcached install

WORKDIR /usr/src/redis
ENV REDIS_VER=6.0.11
ADD https://github.com/redis/redis/archive/${REDIS_VER}.tar.gz .
RUN tar xzf ${REDIS_VER}.tar.gz && \
    cd redis-${REDIS_VER} && \
    make -j && \
    make PREFIX=/redis/usr install

WORKDIR /usr/src/memtier
ENV MEMTIER_VER=1.3.0
ADD https://github.com/RedisLabs/memtier_benchmark/archive/${MEMTIER_VER}.tar.gz .
RUN tar xzf ${MEMTIER_VER}.tar.gz && \
    cd memtier_benchmark-${MEMTIER_VER} && \
    autoreconf -ivf && \
    ./configure && \
     make -j && \
     make DESTDIR=/memtier install

FROM benchmark-base
LABEL maintainer="Kinvolk"

# memcached, redis, memtier
RUN apk add --update --no-cache pcre libevent zlib so:libstdc++.so.6 so:libgcc_s.so.1 curl jq
COPY --from=builder /memcached/ /
COPY --from=builder /redis/ /
COPY --from=builder /memtier/ /
RUN adduser -u 1000 -D benchmark

# Runnable scripts
COPY run-benchmark.sh /usr/local/bin/run-benchmark.sh
COPY run-server.sh /usr/local/bin/run-server.sh

# Change permissions
RUN chmod 777 /usr/local/bin/run-benchmark.sh
