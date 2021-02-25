FROM alpine as dstat-builder
MAINTAINER Kinvolk
RUN apk add --update git patch
RUN cd / && git clone https://github.com/dagwieers/dstat.git
COPY ./dstat-types.patch /dstat/dstat-types.patch 
RUN cd /dstat && \
    patch <dstat-types.patch
