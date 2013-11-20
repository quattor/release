#!/bin/bash

REPOS="aii CAF CCM cdp-listend configuration-modules-core configuration-modules-grid LC ncm-cdispd ncm-ncd ncm-query rpmt-py spma"
RELEASE=""
BUILD=""

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
            echo "RELEASE COMPLETED"
        else
            echo "RELEASE ABORTED"
            exit 2
        fi
    fi
fi
