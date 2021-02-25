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

FROM benchmark-base
MAINTAINER Kinvolk

# stress-ng
COPY --from=builder /stress-ng/stress-ng /sbin/
