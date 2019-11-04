FROM alpine
MAINTAINER Kinvolk
# dstat
RUN apk add --update --no-cache py2-six
COPY --from=dstat-builder /dstat/dstat /usr/local/bin
COPY --from=dstat-builder /dstat/plugins /usr/local/bin/
# lscpu
RUN apk add --update --no-cache util-linux
# nginx serving 404 on port 8000 running as benchmark user (switches if started as root)
RUN apk add --update --no-cache nginx
RUN adduser -u 1000 -D benchmark
RUN sed -i 's/user nginx;/user benchmark;/g' /etc/nginx/nginx.conf
RUN sed -i 's/80 default_server/8000 default_server/g' /etc/nginx/conf.d/default.conf
RUN mkdir /run/nginx
RUN chown benchmark:benchmark -R /var/lib/nginx /run/nginx/ /var/tmp/nginx /var/log/nginx
CMD nginx -g "daemon off;"
