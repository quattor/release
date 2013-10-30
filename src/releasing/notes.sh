#!/bin/bash

REPOS="aii CAF CCM cdp-listend configuration-modules-core configuration-modules-grid LC ncm-cdispd ncm-ncd ncm-query rpmt-py spma"
RELEASE=""

if [[ -n $1 && -n $2 ]]; then
    PREV=$1
    RELEASE=$2
else
    echo "ERROR: Release versions not provided"
    echo "    Based on the date, you should probably be working on $(date +%y.%m)"
    echo "USAGE: $0 PREVIOUS_RELEASE THIS_RELEASE"
    exit 3
fi

details=""

for r in $REPOS; do
    echo "* $r"
    if [[ ! -d $r ]]; then
        git clone -q git@github.com:quattor/$r.git
    fi
    cd $r
    git fetch -t 2> /dev/null
    git branch -r | grep $RELEASE > /dev/null && git checkout -q quattor-$RELEASE || git checkout -q master
    git pull -r > /dev/null
    from=$(git tag | grep $PREV'$')
    to=$(git tag | grep $RELEASE'$')
    git log $from..$to --oneline | grep -v '\[maven-release-plugin\]' | grep -v 'Merge pull request' | sed 's/^/    * /g'
    details="$details\n$r\t$(git branch | grep '^*')"
    cd ..
done
