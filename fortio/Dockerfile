FROM golang:alpine as builder
RUN apk add --update git
RUN go get fortio.org/fortio

FROM benchmark-base
MAINTAINER Kinvolk

# fortio
COPY --from=builder /go/bin/fortio /usr/local/bin/fortio
COPY --from=builder /go/src/fortio.org /go/src/fortio.org
