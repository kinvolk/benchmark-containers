FROM alpine as builder
MAINTAINER Kinvolk

# intall gcc and supporting packages
RUN apk add --update alpine-sdk git linux-headers automake autoconf libtool libaio-dev openssl-dev libunwind-dev mysql-dev

# download sysbench sources
WORKDIR /code
ENV SYSBENCH_VER=1.0.17
ADD https://github.com/akopytov/sysbench/archive/${SYSBENCH_VER}.tar.gz .
RUN tar -xf ${SYSBENCH_VER}.tar.gz && mv sysbench-${SYSBENCH_VER} sysbench

WORKDIR /code/sysbench
RUN export TARGET_LIBS=-lunwind;./autogen.sh && ./configure && make -j && make DESTDIR=/tmp/sysbench-install-root/ install

# add dstat
WORKDIR /code
RUN git clone https://github.com/dagwieers/dstat.git
COPY ./dstat-types.patch /code/dstat/dstat-types.patch 
RUN cd dstat && \
    patch <dstat-types.patch

# Final image
FROM alpine
MAINTAINER Kinvolk

RUN apk add --update --no-cache py2-six so:libgcc_s.so.1 so:libmariadb.so.3 so:libaio.so.1
COPY --from=builder /tmp/sysbench-install-root/ /
COPY --from=builder /code/dstat/dstat /usr/local/bin/
COPY --from=builder /code/dstat/plugins /usr/local/bin/

USER nobody
WORKDIR /tmp
