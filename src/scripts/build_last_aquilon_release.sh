#!/bin/bash

if [ ! -z "$DEBUG" ]; then
    set -x
fi

NAME=aquilon
REPO=https://github.com/quattor/$NAME.git

# name of upstream remote
# git remote add upstream https://github.com/quattor/aquilon-protocols.git
UPSTREAM=upstream

RELEASEBRANCH=upstream

BASE=/tmp

# PRs against upstream that we really want
# 6: add bdist_rpm setup.py
PRs="37 41"

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

git checkout $RELEASEBRANCH
git pull $UPSTREAM $RELEASEBRANCH
git fetch -a

branch="__build_latest"
# cleanup any leftovers?
# not fatal
git branch -D $branch

git checkout $RELEASEBRANCH -b $branch
if [ $? -gt 0 ]; then error "!!"; fi

# merge PRs
for pr in $PRs; do
    git fetch $UPSTREAM refs/pull/$pr/head
    if [ $? -gt 0 ]; then error "!!"; fi
    git merge FETCH_HEAD --commit -m "merging PR $pr"
    if [ $? -gt 0 ]; then error "!!"; fi
done

# is created based on git-describe
rm -f VERSION
# fix symlink issue in PR 37
cd bin
rm -f aq
ln -s aq.py aq
cd -

python setup.py bdist_rpm

# clean it up
git checkout VERSION
git checkout bin/aq

git checkout $RELEASEBRANCH
if [ $? -gt 0 ]; then error "!!"; fi
git branch -D $branch
if [ $? -gt 0 ]; then error "!!"; fi

echo "RPMS in $PWD/dist"
