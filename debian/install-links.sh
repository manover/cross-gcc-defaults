#!/bin/sh
set -e

DEB_TARGET_GNU_TYPE=$(dpkg-architecture -a$DEB_TARGET_ARCH -qDEB_HOST_GNU_TYPE -f 2>/dev/null)

cat debian/defaults | while read l; do
    arch=$DEB_TARGET_GNU_TYPE
    prog=$(echo $l | awk '{ print $1 }')
    ver=$(echo $l | awk '{ print $2 }')

    dh_link -p$arch-$prog usr/bin/$arch-$prog-$ver usr/bin/$arch-$prog
done
