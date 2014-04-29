#!/bin/bash

REPOS_MVN="aii CAF CCM cdp-listend configuration-modules-core configuration-modules-grid LC ncm-cdispd ncm-ncd ncm-query ncm-lib-blockdevices"
REPOS_ONE_TAG="template-library-core template-library-standard template-library-examples template-library-monitoring"
REPOS_BRANCH_TAG="template-library-os template-library-grid template-library-stratuslab"
RELEASE=""
BUILD=""
LIBRARY_CORE_DIR=$(pwd)/template-library-core


publish_templates() {
    type=$1
    tag=$2
    cd configuration-modules-$1
    git checkout $tag
    mvn -q clean compile
    dest_root=${LIBRARY_CORE_DIR}/components
    cp -r ncm-*/target/pan/components/* ${dest_root}
    git checkout master
    cd ${LIBRARY_CORE_DIR}
    git add .
    git commit -m "Component templates for $tag"
    cd ..
}

publish_aii() {
    tag=$1
    cd aii
    git checkout $tag
    mvn -q clean compile
    dest_root=${LIBRARY_CORE_DIR}/quattor/aii
    # It's better to do a rm before copying, in case a template has been suppressed.
    # For aii-core, don't delete subdirectory as some are files not coming from somewhere else...
    rm ${dest_root}/*.pan
    cp -r aii-core/target/pan/quattor/aii/* ${dest_root}
    for aii_component in dhcp ks pxe
    do
      rm -Rf ${dest_root}/${aii_component}
      cp -r aii-${aii_component}/target/pan/quattor/aii/${aii_component} ${dest_root}
    done
    git checkout master
    cd ${LIBRARY_CORE_DIR}
    git add .
    git commit -m "AII templates for $tag"
    cd ..
}

update_version_file() {
    tag=$1
    release_major=$(echo $tag | sed -e 's/-.*$//')
    release_minor=$(echo $tag | sed -e 's/^.*-//')
    version_template=quattor/client/version.pan
    cd ${LIBRARY_CORE_DIR}

    cat > ${version_template} <<EOF
template quattor/client/version;

variable QUATTOR_RELEASE ?= '${release_major}';
variable QUATTOR_REPOSITORY_RELEASE ?= QUATTOR_RELEASE;
variable QUATTOR_PACKAGES_VERSION ?= QUATTOR_REPOSITORY_RELEASE + '-${release_minor}';
EOF

    git add .
    git commit -m "Update Quattor version file"
}

tag_repository() {
    repo=$1
    tag=$2
    cd ${repo}
    #FIXME: we may want to check that the tag doesn't exist already
    git tag -m "Release ${tag}" ${tag}    
    git push
}

tag_branches() {
    repo=$1
    version=$2
    cd ${repo}
    branches=$(git branches -r)
    for branch in ${branches}
    do
      branch_name=$(basename ${branch)
      tag=${branch_name}-${version}
      git tag  -m "Release ${version} of branch ${branch_name}" ${tag} ${branch}
    done
    git push
}

if [[ -n $1 ]]; then
    RELEASE=$1
else
    echo "ERROR: Release version not provided"
    echo "    Based on the date, you should probably be working on $(date +%y.%m)"
    echo "USAGE: releaser.sh RELEASE_NUMBER [RELEASE_CANDIDATE]"
    exit 3
fi

if [[ -n $2 ]]; then
    BUILD=$2
else
    echo "WARNING: You are running a real release, please ensure you have built at least one release candidate before proceeding!"
fi

VERSION="$RELEASE"
if [[ -n $BUILD ]]; then
    VERSION="$RELEASE-rc$BUILD"
fi

details=""

if gpg-agent; then
    if gpg --yes --sign $0; then
        echo "Preparing repositories for release..."
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
                echo "---------------- Releasing $r ----------------"
                cd $r
                mvn -q -DautoVersionSubmodules=true -Dgpg.useagent=true -Darguments=-Dgpg.useagent=true -B -DreleaseVersion=$VERSION clean release:prepare release:perform
                if [[ $? -gt 0 ]]; then
                    echo "RELEASE FAILURE"
                    exit 1
                fi
                cd ..
                echo
            done
            publish_templates "core" "ncm-components-$RELEASE"
            publish_templates "grid" "configuration-modules-grid-$RELEASE"
            # FIXME: tag should be the same for both repositories
            # publish_templates "core" "configuration-modules-$RELEASE"
            # publish_templates "grid" "configuration-modules-$RELEASE"
            publish_aii "aii-$RELEASE"
            update_version_file "$RELEASE"
            #FIXME: ideally tag should be configurable but for now there is only template-library repos
            for repo in $REPOS_ONE_TAG
            do
                tag_repository $repo "template-library-$RELEASE"
            done
            for repo in $REPOS_BRANCH_TAG
            do
                tag_branches $repo  "$RELEASE"
            done
            echo "RELEASE COMPLETED"
        else
            echo "RELEASE ABORTED"
            exit 2
        fi
    fi
fi
