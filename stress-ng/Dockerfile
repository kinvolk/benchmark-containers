FROM alpine as builder
MAINTAINER Kinvolk

# intall gcc and supporting packages
RUN apk add --update alpine-sdk git linux-headers

WORKDIR /code

# download stress-ng sources
ENV STRESS_VER=0.10.07
ADD https://github.com/ColinIanKing/stress-ng/archive/V${STRESS_VER}.tar.gz .
RUN tar -xf V${STRESS_VER}.tar.gz && mv stress-ng-${STRESS_VER} stress-ng

# make static version
WORKDIR /code/stress-ng
RUN STATIC=1 make -j

# add dstat
RUN cd / && git clone https://github.com/dagwieers/dstat.git
COPY ./dstat-types.patch /dstat/dstat-types.patch
RUN cd /dstat && \
    patch <dstat-types.patch

# Final image
FROM alpine
MAINTAINER Kinvolk

RUN apk add --update --no-cache py2-six
COPY --from=builder /code/stress-ng/stress-ng /sbin/
COPY --from=builder /dstat/dstat /usr/local/bin/
COPY --from=builder /dstat/plugins /usr/local/bin/

USER nobody
WORKDIR /tmp
