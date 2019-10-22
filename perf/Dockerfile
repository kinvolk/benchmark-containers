FROM flatcar-developer-container AS builder
MAINTAINER Kinvolk
WORKDIR /

# This is ugly. We back up the dev container overlay config, then run
#  emerge-gitclone, and abort that command (SIGPIPE, emitted by sed)
#  after the checkout phase, then restore our overlay config.
RUN tar czf /ovl.tgz var/lib/portage/coreos-overlay/profiles/coreos/ && \
    emerge-gitclone | sed -e ':Git clone in /var/lib/portage/coreos-overlay successful:q' && \
    tar xzf ovl.tgz && \
    emerge sys-process/audit && \
    emerge sys-devel/bison && \
    emerge sys-devel/flex && \
    emerge dev-libs/elfutils && \
    emerge sys-libs/binutils-libs && \
    mkdir -p /usr/src && cd /usr/src && \
    git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git && \
    cd linux && git checkout $(uname -r | sed 's/^\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/v\1/') && \
    cd tools/perf && make && cp perf /usr/bin/ && \
    tar hczf /perf.tgz /usr/bin/perf $(ldd perf | awk '/=>/{print $3}')


FROM gentoo-stage3
MAINTAINER Kinvolk
COPY --from=builder /perf.tgz /
RUN cd / && tar xzf perf.tgz && ldconfig -v
