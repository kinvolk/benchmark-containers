FROM alpine as dstat-builder
MAINTAINER Kinvolk
RUN apk add --update git
RUN cd / && git clone https://github.com/dagwieers/dstat.git
COPY ./dstat-types.patch /dstat/dstat-types.patch 
RUN cd /dstat && \
	patch <dstat-types.patch


FROM alpine as builder
WORKDIR /sysbench
MAINTAINER Kinvolk
ENV SYSBENCH_VER=1.0.17
ADD https://github.com/akopytov/sysbench/archive/${SYSBENCH_VER}.tar.gz .
RUN apk add --update alpine-sdk git linux-headers automake autoconf libtool libaio-dev openssl-dev libunwind-dev mysql-dev
RUN tar -xf ${SYSBENCH_VER}.tar.gz && \
	cd sysbench-${SYSBENCH_VER} && \
	export TARGET_LIBS=-lunwind;./autogen.sh && \
	./configure && \
	make -j && \
	make DESTDIR=/sysbench/sysbench-install-root/ install


FROM alpine
MAINTAINER Kinvolk
# dstat
RUN apk add --update --no-cache py2-six
COPY --from=dstat-builder /dstat/dstat /usr/local/bin
COPY --from=dstat-builder /dstat/plugins /usr/local/bin/
# sysbench
RUN apk add --update --no-cache so:libgcc_s.so.1 so:libmariadb.so.3 so:libaio.so.1
COPY --from=builder /sysbench/sysbench-install-root/ /
