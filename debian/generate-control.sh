#!/bin/sh

if [ ! -f debian/defaults ]; then
    echo "ERROR: Run ./debian/update-defaults.sh first" >&2
    exit 1
fi

PROG_LIST=$(cat debian/defaults | awk '{ print $1 }')
DEB_TARGET_GNU_TYPE=$(dpkg-architecture -a$DEB_TARGET_ARCH -qDEB_HOST_GNU_TYPE -f 2>/dev/null)

cat debian/control.head.in \
    | sed -e 's/$DEB_TARGET_ARCH/'"$DEB_TARGET_ARCH"'/g' > debian/control
echo >> debian/control

for prog in $PROG_LIST; do
    ver=$(cat debian/defaults | grep "^$prog" | awk '{ print $2 }')

    (cat debian/control.pkg.in; echo) \
	| sed -e 's/$DEB_TARGET_GNU_TYPE/'"$DEB_TARGET_GNU_TYPE"'/' \
	| sed -e 's/$DEB_TARGET_ARCH/'"$DEB_TARGET_ARCH"'/' \
	| sed -e 's/$HOST_LIST/'"$HOST_LIST"'/' \
	| sed -e 's/$prog/'"$prog"'/' >> debian/control
done
