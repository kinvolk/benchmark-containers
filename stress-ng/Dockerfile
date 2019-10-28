FROM alpine as builder
WORKDIR /stress-ng
MAINTAINER Kinvolk
ENV STRESS_VER=0.10.07
ADD https://github.com/ColinIanKing/stress-ng/archive/V${STRESS_VER}.tar.gz .
RUN apk add --update alpine-sdk git linux-headers
RUN tar -xf V${STRESS_VER}.tar.gz && \
	cd stress-ng-${STRESS_VER} && \
	STATIC=1 make -j &&\
	mv stress-ng /stress-ng/


FROM alpine
MAINTAINER Kinvolk
# dstat
RUN apk add --update --no-cache py2-six
COPY --from=dstat-builder /dstat/dstat /usr/local/bin
COPY --from=dstat-builder /dstat/plugins /usr/local/bin/
# stress-ng
RUN apk add --update --no-cache util-linux
COPY --from=builder /stress-ng/stress-ng /sbin/
