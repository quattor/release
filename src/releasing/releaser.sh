#!/bin/bash

REPOS_MVN="release aii CAF CCM cdp-listend configuration-modules-core configuration-modules-grid LC ncm-cdispd ncm-ncd ncm-query ncm-lib-blockdevices"
REPOS_ONE_TAG="template-library-core template-library-standard template-library-examples template-library-monitoring"
REPOS_BRANCH_TAG="template-library-os template-library-grid template-library-stratuslab template-library-openstack"
RELEASE=""
BUILD=""
MAXFILES=2048
RELEASE_ROOT=$(dirname $(readlink -f "$0"))
LIBRARY_CORE_DIR=$RELEASE_ROOT/src/template-library-core

if [[ $(ulimit -n) -lt $MAXFILES ]]; then
  echo "INFO: Max open files (ulimit -n) is below $MAXFILES, trying to increase the limit for you."
  ulimit -n 4096

  if [[ $(ulimit -n) -lt $MAXFILES ]]; then
    echo "ABORT: Max open files (ulimit -n) is still below $MAXFILES, releasing components will likely fail. Manually increase the limit and try again."
    exit 2
  fi
fi

shopt -s expand_aliases
source maven-illuminate.sh

# Update the Quattor version used by template-library-examples (SCDB-based) to the one being released
update_examples () {
    tag=$1
    cd template-library-examples
    sed -i -e "s%quattor/[0-Z\.\_\-]\+\s%quattor/$tag %" $(find clusters -name cluster.build.properties)
    git commit -a -m "Update Quattor version used by examples to ${tag}"
    cd ..
}

# Remove all current configuration module related templates.
# To be used before starting the update: after the updated
# only the obsolete configuration modules will be missing.
clean_templates() {
    rm -Rf ${LIBRARY_CORE_DIR}/components/*
}

# Commit to template-library-core the removal of obsolete configuration modules
remove_obsolete_components () {
    cd ${LIBRARY_CORE_DIR}
    #FIXME: ideally should check that there is only deleted files left
    git add -A .
    git commit -m 'Remove obsolete components'
    cd ..
}

# Update the templates related to configuration modules.
# This has to be called for every repository containing configuration modules.
publish_templates() {
    echo_info "Publishing Component Templates"
    type=$1
    tag=$2
    cd configuration-modules-$1
    git checkout $tag
    mvn-c clean compile
    # ugly hack
    if [ -d ncm-metaconfig ]; then
        cd ncm-metaconfig
        mvn-c clean test
        cd ..
    fi
    components_root=${LIBRARY_CORE_DIR}/components
    metaconfig_root=${LIBRARY_CORE_DIR}/metaconfig
    mkdir -p ${components_root}
    mkdir -p ${metaconfig_root}
    cp -r ncm-*/target/pan/components/* ${components_root}
    cp -r ncm-metaconfig/target/pan/metaconfig/* ${metaconfig_root}
    git checkout master
    cd ${LIBRARY_CORE_DIR}
    git add .
    git commit -m "Component templates (${type}) for tag ${tag}"
    cd ..
}

# Update templates related to AII and its plugins.
# Existing AII templates are removed before the update so
# that obsolete templates are removed.
publish_aii() {
    echo_info "Publishing AII Templates"
    tag=$1
    cd aii
    git checkout $tag
    mvn-c -q clean compile
    dest_root=${LIBRARY_CORE_DIR}/quattor/aii
    # It's better to do a rm before copying, in case a template has been suppressed.
    # For aii-core, don't delete subdirectory as some are files not coming from somewhere else...
    rm ${dest_root}/*.pan
    cp -r aii-core/target/pan/quattor/aii/* ${dest_root}
    for aii_component in dhcp ks pxelinux
    do
      rm -Rf ${dest_root}/${aii_component}
      cp -r aii-${aii_component}/target/pan/quattor/aii/${aii_component} ${dest_root}
    done
    git checkout master
    cd ${LIBRARY_CORE_DIR}
    git add -A .
    git commit -m "AII templates for tag $tag"
    cd ..
}

# Build the template version.pan appropriate for the version
update_version_file() {
    release_major=$1
    if [ -z "$(echo $release_major | egrep 'rc[0-9]*$')" ]
    then
      release_minor="-1"
    else
      release_minor="_1"
    fi
    version_template=quattor/client/version.pan
    cd ${LIBRARY_CORE_DIR}

    cat > ${version_template} <<EOF
template quattor/client/version;

variable QUATTOR_RELEASE ?= '${release_major}';
variable QUATTOR_REPOSITORY_RELEASE ?= QUATTOR_RELEASE;
variable QUATTOR_PACKAGES_VERSION ?= QUATTOR_REPOSITORY_RELEASE + '${release_minor}';
EOF

    git add .
    git commit -m "Update Quattor version file for ${release_major}"
    cd -
}

tag_repository() {
    repo=$1
    tag=$2
    cd ${repo}
    #FIXME: we may want to check that the tag doesn't exist already
    git tag -m "Release ${tag}" ${tag}
    git push origin --tags HEAD
    cd -
}

tag_branches() {
    repo=$1
    version=$2
    cd ${repo}
    # Ignore remote HEAD symlink and branches marked as obsolete
    branches=$(git branch -r | grep -v ' -> ' | egrep -v 'obsolete$' )
    for branch in ${branches}
    do
      branch_name=$(basename ${branch})
      tag=${branch_name}-${version}
      git tag  -m "Release ${version} of branch ${branch_name}" ${tag} ${branch}
    done
    git push origin --tags
    cd -
}

function echo_warning {
  echo -e "\033[1;33mWARNING\033[0m  $1"
}

function echo_error {
  echo -e "\033[1;31mERROR\033[0m  $1"
}

function echo_success {
  echo -e "\033[1;32mSUCCESS\033[0m  $1"
}

function echo_info {
  echo -e "\033[1;34mINFO\033[0m  $1"
}

function exit_usage {
    echo
    echo "USAGE: releaser.sh RELEASE_NUMBER [RELEASE_CANDIDATE]"
    echo "       RELEASE_NUMBER should be of the form YY.MM.N without leading zeros"
    exit 3
}

# Check that dependencies required to perform a release are available
missing_deps=0
for cmd in {gpg,gpg-agent,git,mvn,createrepo,tar,sed}; do
    hash $cmd 2>/dev/null || {
        echo_error "Command '$cmd' is required but could not be found"
        missing_deps=$(($missing_deps + 1))
    }
done
if [[ $missing_deps -gt 0 ]]; then
    echo_error "Aborted due to $missing_deps missing dependencies (see above)"
    exit 2
fi


if [[ -n $1 ]]; then
    RELEASE=$1
    if echo $RELEASE | grep -qv '^[1-9][0-9]\?\.\([1-9]\|1[012]\)\.[0-9]\+$'; then
        echo_error "Release version doesn't match expected format."
        exit_usage
    fi
else
    echo_error "Release version not provided"
    echo "    Based on the date, you should probably be working on $(date +%-y.%-m).0"
    exit_usage
fi

if [[ -n $2 ]]; then
    BUILD=$2
else
    echo_warning "You are running a final release, please ensure you have built at least one release candidate before proceeding!"
fi

VERSION="$RELEASE"
if [[ -n $BUILD ]]; then
    VERSION="$RELEASE-rc$BUILD"
fi

details=""

if gpg-agent; then
    if gpg --yes --sign $0; then
        echo -n "Preparing repositories for release... "
        cd $RELEASE_ROOT
        mkdir -p src/
        cd src/
        for r in $REPOS_MVN $REPOS_ONE_TAG $REPOS_BRANCH_TAG; do
            if [[ ! -d $r ]]; then
                git clone -q git@github.com:quattor/$r.git
            fi
            cd $r
            git branch -r | grep $RELEASE > /dev/null && git checkout -q quattor-$RELEASE || git checkout -q master
            details="$details\n$r\t$(git branch | grep '^*')"
            cd ..
        done
        echo "Done."
        echo
        echo -e $details | column -t
        echo
        echo "We will build $VERSION from the branches shown above, continue with release? yes/NO"
        echo -n "> "
        read prompt
        if [[ $prompt == "yes" ]]; then
            for r in $REPOS_MVN; do
                echo_info "---------------- Releasing $r ----------------"
                cd $r
                mvn-c -q -DautoVersionSubmodules=true -Dgpg.useagent=true -Darguments=-Dgpg.useagent=true -B -DreleaseVersion=$VERSION clean release:prepare
                if [[ $? -gt 0 ]]; then
                    echo_error "RELEASE FAILURE"
                    exit 1
                fi
                cd ..
                echo
            done

            echo_success "---------------- Releases complete, building YUM repositories ----------------"

            cd $RELEASE_ROOT
            mkdir -p target/

            echo_info "Collecting RPMs"
            mkdir -p target/$VERSION
            find src/ -type f -name \*.rpm | grep /target/rpm/ | xargs -I @ cp @ target/$VERSION/

            cd target/

            echo_info "Signing RPMs"
            rpm --resign $VERSION/*.rpm

            echo_info "Creating repository"
            createrepo -s sha $VERSION/

            echo_info "Signing repository"
            gpg --detach-sign --armor $VERSION/repodata/repomd.xml

            echo_info "Creating repository tarball"
            tar -cjf quattor-$VERSION.tar.bz2 $VERSION/
            echo_info "Repository tarball built: target/quattor-$VERSION.tar.bz2"

            echo_success "---------------- YUM repositories complete, tagging git repositories ----------------"

            cd $RELEASE_ROOT/src

            echo_info "---------------- Updating template-library-core  ----------------"
            clean_templates
            echo_info "    Updating configuration module templates..."
            publish_templates "core" "configuration-modules-core-$VERSION" && echo_info "    Published core configuration module templates"
            publish_templates "grid" "configuration-modules-grid-$VERSION" && echo_info "    Published grid configuration module templates"
            # FIXME: tag should be the same for both repositories
            # publish_templates "core" "configuration-modules-$VERSION"
            # publish_templates "grid" "configuration-modules-$VERSION"
            echo_info "    Remove templates for obsolete components..."
            remove_obsolete_components

            echo_info "    Updating AII templates..."
            publish_aii "aii-$VERSION" &&  echo_info "    AII templates successfully updated"

            echo_info "    Updating Quattor version template..."
            update_version_file "$VERSION" && echo_info "    Quattor version template sucessfully updated"

            echo_info "Updating examples"
            update_examples $VERSION

            echo_info "    Tagging template library repositories..."
            #FIXME: ideally tag should be configurable but for now there is only template-library repos
            for repo in $REPOS_ONE_TAG
            do
                tag_repository $repo "$VERSION" && echo_info "    Tagged $repo"
            done
            for repo in $REPOS_BRANCH_TAG
            do
                tag_branches $repo  "$VERSION" && echo_info "    Tagged branches in $repo"
            done

            echo_success "---------------- Update of template-library-core successfully completed ----------------"

            echo_success "RELEASE COMPLETED"
        else
            echo_error "RELEASE ABORTED"
            exit 2
        fi
    fi
fi
