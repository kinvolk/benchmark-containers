#!/bin/bash -e

grep -qE '^ID=flatcar' /usr/share/coreos/os-release || {
		echo "ERROR: unable to identify the running OS as Flatcar" >&2
		echo "'ID=flatcar' missing from /usr/share/coreos/os-release" >&2
		echo "Please run this build on Flatcar OS." 2>&1
		exit 1
}

# http://distfiles.gentoo.org/releases/amd64/autobuilds/20191020T214501Z/stage3-amd64-20191020T214501Z.tar.xz
gentoo_stage3_url="http://distfiles.gentoo.org/experimental/arm64/stage3-arm64-20190613.tar.bz2"
gentoo_stage3=$(basename ${gentoo_stage3_url})

if [ ! -f dev-container.tgz ] ; then
    if [ ! -f flatcar_developer_container.bin.bz2 ] ; then
        source /usr/share/coreos/release
        source /usr/share/coreos/update.conf
        echo "** build: downloading https://${GROUP:-stable}.release.flatcar-linux.net/$FLATCAR_RELEASE_BOARD/$FLATCAR_RELEASE_VERSION/flatcar_developer_container.bin.bz2"
        wget https://${GROUP:-stable}.release.flatcar-linux.net/$FLATCAR_RELEASE_BOARD/$FLATCAR_RELEASE_VERSION/flatcar_developer_container.bin.bz2
    else
        echo "** build: using existing $(pwd)/flatcar_developer_container.bin.bz2"
    fi

    mkdir -p rootfs
    offset=$(sfdisk -l flatcar_developer_container.bin | grep flatcar_developer_container.bin9 | awk '{print $2*512}')
    sudo mount -o loop,offset=${offset} flatcar_developer_container.bin rootfs
    cd rootfs && sudo tar czf ../dev-container.tgz . && cd ..
    sudo umount rootfs
else
    echo "** build: using existing $(pwd)/dev-container.tgz"
fi

echo "** build: importing dev-container.tgz"
docker import dev-container.tgz flatcar-developer-container

if [ ! -f ${gentoo_stage3} ] ; then
    echo "** build: downloading ${gentoo_stage3_url}"
    wget ${gentoo_stage3_url}
else
    echo "** build: using existing $(pwd)/${gentoo_stage3}"
fi

echo "** build: importing ${gentoo_stage3}"
docker import ${gentoo_stage3} gentoo-stage3

echo "** build: containers created; commencing build"
docker build -t perf .
