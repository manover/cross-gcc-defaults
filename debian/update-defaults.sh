#!/bin/sh

PROGS="^cpp|^gcc|^g\+\+|^gfortran"

set -e

dh_testdir

rm -rf debian/tmp
mkdir debian/tmp
cd debian/tmp

# workaround for debian bug #441178: make sure you don't have experimental in
# your sources.list otherwise gcc-defaults version could be out of sync with
# unstable
if [ $(cat /etc/apt/sources.list /etc/apt/sources.list.d/* | grep experimental | grep -v '^#') ]; then
    echo "Error: remove unstable form source.list" >&2
    exit 1
fi

apt-get source gcc-defaults

f=$(echo gcc-defaults* | sed 's/ /\n/g' | head -n1)

echo -n > ../defaults
progs=$(cat $f/debian/README.Debian \
    | egrep '[a-z+]+[[:space:]]+:[[:space:]]*[a-z+]+-[0-9]+(.[0-9]+)*' \
    | sed 's/://g')

printf "%s" "$progs" | while read l; do
    prog=$(echo $l | awk '{ print $1 }')
    ver=$(echo $l | awk '{ print $2 }' | sed 's/.*-//')

    if ! echo $prog | egrep "$PROGS" >/dev/null; then
	break
    fi

    echo $prog $ver >> ../defaults
done
