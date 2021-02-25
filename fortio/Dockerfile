FROM golang:alpine as builder
RUN go get fortio.org/fortio

FROM benchmark-base
MAINTAINER Kinvolk

# fortio
COPY --from=builder /go/bin/fortio /usr/local/bin/fortio
