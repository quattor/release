#!/bin/bash

if [ ! -z "$DEBUG" ]; then
    set -x
fi

# build rpms for last number of tags
# For now, always use new clone in /tmp
# TODO: detect present clone and switch to upstream
NR_TAGS=${1:-5}

NAME=aquilon-protocols
REPO=https://github.com/quattor/$NAME.git

# name of upstream remote
# git remote add upstream https://github.com/quattor/aquilon-protocols.git
UPSTREAM=upstream

BASE=/tmp

# PRs against upstream that we really want
# 6: add bdist_rpm setup.py
PRs="6"

error () {
    echo "ERROR: $@"
    exit 1
}

# For now, always clone
if [ ! -d $BASE/$NAME ]; then
    cd $BASE
    git clone $REPO
    if [ $? -gt 0 ]; then error "!!"; fi
    cd $NAME
    if [ $? -gt 0 ]; then error "!!"; fi
    git remote add $UPSTREAM $REPO
    if [ $? -gt 0 ]; then error "!!"; fi
fi

cd $BASE/$NAME
if [ $? -gt 0 ]; then error "!!"; fi


pbc=protobuf-compiler
rpm -q $pbc  >&/dev/null
if [ $? -ne 0 ]; then
    error "Please install required rpm: sudo yum install -y $pbc"
fi

git checkout master
git pull $UPSTREAM master
git fetch -a
for tag in $(git tag -l --sort=-taggerdate |head -$NR_TAGS); do
    branch="__tag_$tag"
    # cleanup any leftovers?
    # not fatal
    git branch -D $branch


    git checkout tags/$tag -b $branch
    if [ $? -gt 0 ]; then error "!!"; fi

    # merge PRs
    for pr in $PRs; do
        git fetch $UPSTREAM refs/pull/$pr/head
        if [ $? -gt 0 ]; then error "!!"; fi
        git merge FETCH_HEAD --commit -m "merging PR $pr"
        if [ $? -gt 0 ]; then error "!!"; fi
    done

    sed -i "s/version=.*,/version='$tag',/" setup.py
    python setup.py bdist_rpm
    # clean it up
    git checkout setup.py

    git checkout master
    if [ $? -gt 0 ]; then error "!!"; fi
    git branch -D $branch
    if [ $? -gt 0 ]; then error "!!"; fi
done

echo "RPMS in $PWD/dist"
