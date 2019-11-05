FROM golang:alpine as builder
RUN apk add --update git
RUN go get fortio.org/fortio

FROM alpine
MAINTAINER Kinvolk
# dstat
RUN apk add --update --no-cache py2-six
COPY --from=dstat-builder /dstat/dstat /usr/local/bin
COPY --from=dstat-builder /dstat/plugins /usr/local/bin/
# lscpu
RUN apk add --update --no-cache util-linux
# fortio
COPY --from=builder /go/bin/fortio /usr/local/bin/fortio
COPY --from=builder /go/src/fortio.org /go/src/fortio.org
