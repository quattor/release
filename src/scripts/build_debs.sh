#!/bin/bash

if [ "${DEBUG:-0}" -ne 0 ]; then
    set -x
fi

function hr () {
    printf '\n%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

WHITESPACE="THISISASPACEWOOHOOCRAPPYBASH"

function encode_whitespace () {
    sed "s/ /$WHITESPACE/g"
}

function decode_whitespace () {
    sed "s/$WHITESPACE/ /g"
}

function render_copyright () {
    name=$1
    echo "----> $PWD"

    dir_copyright="$DIR_WORK/$name/usr/share/doc/$name"
    mkdir -p "$dir_copyright"
    echo "Copyright (c) 2017 Contributors to the Quattor Working Group
Quattor software is licensed under the terms of:
Apache License, Version 2.0 - /usr/share/common-licenses/Apache-2.0
EU DataGrid Software License (EUDatagrid) - https://opensource.org/licenses/EUDatagrid
" > "$dir_copyright/copyright"

    echo "
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
License: /usr/share/common-licenses/Apache-2.0
Source: https://github.com/quattor
" > "$DIR_META/copyright"
}


function render_changelog () {
    package=$1
    version=$2
    distribution=$(lsb_release -sc)
    date=$(date --rfc-2822)

    dir_changelog="$DIR_WORK/$name/usr/share/doc/$name"

    echo "$package ($version) $distribution; urgency=low

  * Re-packaged by automated workflow, see http://www.quattor.org/news for release notes.

 -- Quattor Working Group <quattor-devel@lists.sourceforge.net>  $date

" | gzip -c9 > "$dir_changelog/changelog.gz"
    echo "$dir_changelog/changelog.gz"
}

function filter_package_names () {
    grep -v '^rpmlib' | grep -v '^/' | grep -v '__' | sed 's/^perl(\(\S\+\))/lib\1-perl/g' | sed 's/::/-/g' | tr '[:upper:]' '[:lower:]' | sed 's/_/-/g'
}

function mk_prov () {
    while read data; do
        # no real manipulation required?
        echo "$data" | encode_whitespace
    done
}

function mk_req () {
    local dep depname oper vers from_cache
    while read data; do
        # get package name and optional version
        read depname oper vers <<< $(echo "$data" )
        from_cache=$(grep "^$depname\$" "$APT_CACHE_DUMP")
        if [ -z "$from_cache" ]; then
            echo "missing dep for $data" >> $MISSING_DEP
        else
            if [ -z "$oper" ]; then
                echo $depname
            else
                # no epoch in version
                echo "$depname $oper ${vers#*:}" | encode_whitespace
            fi
        fi
    done
}


function repackage () {
    package=$1

    # Extract metadata
    read name version release arch <<< $(rpm -q --qf '%{NAME}\t%{VERSION}\t%{RELEASE}\t%{ARCH}\n' -p $package | tr '[:upper:]' '[:lower:]')

    hr
    echo "Original name: $name"
    name=$(echo $name | tr '[:upper:]' '[:lower:]' | sed 's/^perl-\(\S\+\)/lib\1-perl/g')
    echo "Using name: $name"

    requires=($(rpm -q --requires -p $package | filter_package_names | mk_req | sed 's/^/--depends /g'))
    provides=($(rpm -q --provides -p $package | filter_package_names | mk_prov | sed 's/^/--provides /g'))

    # decode whitespace
    count=0
    while [ "x${requires[$count]}" != "x" ]; do
        requires[$count]=$(echo ${requires[$count]} | decode_whitespace)
        count=$(( $count + 1 ))
    done
    count=0
    while [ "x${provides[$count]}" != "x" ]; do
        provides[$count]=$(echo ${provides[$count]} | decode_whitespace)
        count=$(( $count + 1 ))
    done

    if [ "${DEBUG:-0}" -ne 0 ]; then
        echo -e "Requires:\n${requires[@]}"
        echo -e "Provides:\n${provides[@]}"
    fi

    # Setup scratch area
    mkdir $name

    # Extract RPM
    (
        cd $name
        rpm2cpio $package | cpio -idm
    )

    # Process files
    render_copyright $name
    render_changelog $name $version

    # Relocate perl modules (disabled until ncm-ncd is fixed)
    #mkdir -p $name/usr/share/perl5
    #mv $name/usr/lib/perl/* $name/usr/share/perl5/

    # Remove legacy Changelog and any examples
    rm -rf $name/usr/share/doc/$name-$version

    # Build DEB
    fpm -f \
        -s dir \
        -t deb \
        -C $name \
        -n $name \
        -a $arch \
        -v $version \
        --iteration $release \
        --maintainer "James Adams <james.adams@stfc.ac.uk>" \
        --rpm-sign \
        --category admin \
        --url "http://www.quattor.org/" \
        "${requires[@]}" \
        "${provides[@]}" \
        .

    readlink -f *.deb
    lintian *.deb

    mv *.deb $DIR_DEBS
}

ROOT=$(mktemp -d)
DIR_RPMS="$ROOT/rpms"
DIR_DEBS="$ROOT/debs"
DIR_WORK="$ROOT/files"
DIR_META="$ROOT/debian"

APT_CACHE_DUMP="$ROOT/apt_cache_dump"

if [[ -d $1 ]]; then
    mkdir -p $DIR_RPMS
    mkdir -p $DIR_DEBS
    mkdir -p $DIR_WORK
    mkdir -p $DIR_META
    apt-cache dump | awk '/^Package:/ { print $NF }' | sort > "$APT_CACHE_DUMP"

    for p in $(find $1 -type f -name \*.rpm | xargs -n 1 readlink -f); do
        echo "Package: $p"
        MISSING_DEP="missing_dep.${p##*/}"
        cp $p $DIR_RPMS
        cd $DIR_WORK
        repackage $p
    done

    echo "Done, your debs are in $DIR_DEBS"
else
    echo "First argument must be a directory tree containing RPMs"
fi
