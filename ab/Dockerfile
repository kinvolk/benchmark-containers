FROM alpine
MAINTAINER Kinvolk
# dstat
RUN apk add --update --no-cache py2-six
COPY --from=dstat-builder /dstat/dstat /usr/local/bin
COPY --from=dstat-builder /dstat/plugins /usr/local/bin/
# lscpu
RUN apk add --update --no-cache util-linux
# ab
RUN apk add --update --no-cache apache2-utils
