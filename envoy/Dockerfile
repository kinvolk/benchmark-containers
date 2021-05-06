FROM alpine as builder
WORKDIR /usr/src
RUN apk add --update alpine-sdk zlib-dev openssl-dev wget lua lua-dev luarocks
RUN luarocks-5.1 install luasocket
ADD https://github.com/kinvolk/wrk2/archive/master.zip .
RUN unzip master.zip && cp -R wrk2-master/ /usr/src/wrk2-cache-stresser/

RUN cd wrk2-cache-stresser && \
  make clean && \
  make -j && \
  strip wrk

FROM benchmark-base
LABEL maintainer="Kinvolk"

# ab && wrk2
RUN apk add --update --no-cache apache2-utils so:libcrypto.so.1.1 so:libssl.so.1.1 so:libgcc_s.so.1 curl nginx expect util-linux
COPY --from=builder /usr/src/wrk2-cache-stresser/wrk /usr/local/bin/
COPY --from=builder /usr/local/lib/lua/ /usr/local/lib/lua/
COPY --from=builder /usr/local/share/lua/ /usr/local/share/lua/
COPY --from=builder /usr/src/wrk2-cache-stresser/scripts/multiple-endpoints-prometheus-metrics.lua /usr/local/bin/

RUN mkdir /tmpfs

COPY ./prometheus-export-wrapper /usr/local/bin/

RUN chmod 755 /usr/local/bin/prometheus-export-wrapper
