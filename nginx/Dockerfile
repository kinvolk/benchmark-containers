FROM benchmark-base
LABEL maintainer="Kinvolk"
# nginx serving 404 on port 8000 running as benchmark user (switches if started as root)
RUN apk add --update --no-cache nginx wrk curl
RUN adduser -u 1000 -D benchmark
RUN sed -i 's/user nginx;/user benchmark;/g' /etc/nginx/nginx.conf
RUN sed -i 's/80 default_server/8000 default_server/g' /etc/nginx/conf.d/default.conf
RUN mkdir /run/nginx

ADD report-json.lua /usr/local/share/wrk/report-json.lua
COPY run-benchmark.sh /usr/local/bin/run-benchmark.sh
RUN chmod 777 /usr/local/bin/run-benchmark.sh

CMD nginx -g "daemon off;"
