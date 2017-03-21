#!/bin/bash

for com in 'mkdocs' 'mvn' 'pod2markdown' 'bundle'; do
    command -v $com >/dev/null 2>&1 || { echo >&2 "I require $com but it's not installed.  Aborting."; exit 1; }
done

tmpdir="/tmp/quattor-documentation"

# Create temporary working directory
mkdir -p $tmpdir/{src,output}
cd $tmpdir/src

# Clone required github repositories
for REPO in CAF configuration-modules-core configuration-modules-grid CCM maven-tools;  do
    git clone https://github.com/quattor/$REPO.git
done
cd ..

# Build the whole documentation
quattor-documentation-builder -c -m $tmpdir/src/ -o $tmpdir/output/ --info || { echo 'Something went wrong building documentation.' ; exit 1 ; }

# checkout current test build
git clone https://github.com/wdpypere/docs-test-comps.git
# build sphinx site
cd docs-test-comps/docs
rm -rf components CAF CCM components-grid Unittesting
mv $tmpdir/output/docs/* .
make clean html

# show it
firefox .build/html/index.html
