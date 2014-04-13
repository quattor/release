#!/bin/bash

REPOS="aii CAF CCM cdp-listend configuration-modules-core configuration-modules-grid LC ncm-cdispd ncm-ncd ncm-query ncm-lib-blockdevices"
RELEASE=""
BUILD=""

publish_templates() {
    type=$1
    tag=$2
    cd configuration-modules-$1
    git checkout $tag
    mvn -q clean compile
    library_core_dir=../template-library-core/quattor/aii
    dest_root=${library_core_dir}/components
    cp -r ncm-*/target/pan/components/* ${dest_root}
    git checkout master
    cd ${library_core_dir}
    git add .
    git commit -m "Component templates for $tag"
    cd ..
}

publish_aii() {
    tag=$1
    cd aii
    git checkout $tag
    mvn -q clean compile
    library_core_dir=../template-library-core/quattor/aii
    dest_root=${library_core_dir}/quattor/aii
    # It's better to do a rm before copying, in case a template has been suppressed.
    # For aii-core, don't delete subdirectory as some are files not coming from somewhere else...
    rm ../template-library-core/quattor/aii/*.pan
    cp -r aii-core/target/pan/quattor/aii/* ${dest_root}
    for aii_component in dhcp ks pxe
    do
      rm -Rf ${dest_root}/${aii_component}
      cp -r aii-${aii_component}/target/pan/quattor/aii/${aii_component} ${dest_root}
    done
    git checkout master
    cd ${library_core_dir}
    git add .
    git commit -m "AII templates for $tag"
    cd ..
}

push_changes() {
    cd template-library-core
    echo "After updating quattor/client/version.pan, don't forget to tag release as ${RELEASE}".
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
        for r in $REPOS; do
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
            for r in $REPOS; do
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
            push_changes
            echo "RELEASE COMPLETED"
        else
            echo "RELEASE ABORTED"
            exit 2
        fi
    fi
fi
