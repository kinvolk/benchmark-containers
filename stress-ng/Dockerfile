FROM debian:buster as builder

# intall gcc and supporting packages
RUN apt-get update && apt-get install -yq make gcc build-essential git gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf gcc-8-aarch64-linux-gnu

WORKDIR /code

# download stress-ng sources
ENV STRESS_VER=0.09.41
ADD https://github.com/ColinIanKing/stress-ng/archive/V${STRESS_VER}.tar.gz .
RUN tar -xf V${STRESS_VER}.tar.gz && mv stress-ng-${STRESS_VER} stress-ng

# make static version
WORKDIR /code/stress-ng
RUN CC=aarch64-linux-gnu-gcc-8 STATIC=1 make

# Final image
FROM scratch

COPY --from=builder /code/stress-ng/stress-ng /

USER nobody

ENTRYPOINT ["/stress-ng"]
