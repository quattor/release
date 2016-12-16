#!/bin/bash

VERSION="master"

#!/bin/bash
while getopts "h:v:" arg; do
  case $arg in
    h)
      echo "usage: use '-v' to specify another branch than master."
      ;;
    s)
      VERSION=$OPTARG
      ;;
  esac
done

for com in 'mkdocs' 'mvn' 'pod2markdown' 'bundle'; do
    command -v $com >/dev/null 2>&1 || { echo >&2 "I require $com but it's not installed.  Aborting."; exit 1; }
done

tmpdir="/tmp/quattor-documentation"

# Create temporary working directory
mkdir -p $tmpdir/{src,output}
cd $tmpdir/src

# Clone required github repositories
for REPO in CAF configuration-modules-core configuration-modules-grid CCM ;  do
    git clone https://github.com/quattor/$REPO.git
    cd $REPO
    tag=`git tag -l | grep "$VERSION$"`
    git checkout -q $tag
    cd ..
done
cd ..

# Build the whole documentation
quattor-documentation-builder -c -m $tmpdir/src/ -o $tmpdir/output/ --info || { echo 'Something went wrong building documentation.' ; exit 1 ; }

# get required index which is not generated
curl https://raw.githubusercontent.com/quattor/documentation/master/docs/index.md -o $tmpdir/output/docs/index.md

cd $tmpdir/output
mkdocs build --clean

# Get some tests up
curl https://raw.githubusercontent.com/quattor/documentation/master/Gemfile -o Gemfile
bundle

bundle exec htmlproofer  --check-html ./site/ --file-ignore ./site/base.html,./site/breadcrumbs.html,./site/footer.html,./site/toc.html,./site/versions.html || { echo 'build test errors detected. stopping.' ; exit 1 ; }
