#!/bin/bash

# Source this first as it has the potential to scribble all over our variables otherwise
# shellcheck source=/dev/null
source /etc/os-release || exit 1

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
    echo "USAGE: packager.sh RELEASE_NUMBER [RELEASE_CANDIDATE]"
    echo "       RELEASE_NUMBER should be of the form YY.MM.N without leading zeros"
    exit 3
}

if [[ ! $ID_LIKE =~ 'rhel' ]]; then
    echo_error "We do not currently support packing on an non-RHEL like OS (this OS claims to be like '$ID_LIKE')."
    exit 1
fi

PACKAGE_SUFFIX="el${VERSION_ID//.*/}"

echo_info "Set package suffix to $PACKAGE_SUFFIX"


# Now define our environment
REPOS_MVN="release aii CAF CCM cdp-listend configuration-modules-core configuration-modules-grid LC ncm-cdispd ncm-ncd ncm-query ncm-lib-blockdevices"
RELEASE=""
BUILD=""
MAXFILES=2048
RELEASE_ROOT="$(dirname "$(readlink -f "$0")")"

if [[ $(ulimit -n) -lt $MAXFILES ]]; then
  echo_info "Max open files (ulimit -n) is below $MAXFILES, trying to increase the limit for you."
  ulimit -n 4096

  if [[ $(ulimit -n) -lt $MAXFILES ]]; then
    echo_error "ABORT: Max open files (ulimit -n) is still below $MAXFILES, releasing components will likely fail. Manually increase the limit and try again."
    exit 2
  fi
fi

if [[ -n "$QUATTOR_TEST_TEMPLATE_LIBRARY_CORE" && -d "$QUATTOR_TEST_TEMPLATE_LIBRARY_CORE" ]]; then
    echo_info "QUATTOR_TEST_TEMPLATE_LIBRARY_CORE defined and set to '$QUATTOR_TEST_TEMPLATE_LIBRARY_CORE'"
else
    echo_error "ABORT: QUATTOR_TEST_TEMPLATE_LIBRARY_CORE is not correctly defined, cannot perform a release without a reference copy of template-library-core."
    exit 2
fi

shopt -s expand_aliases
# CodeClimate won't let us run shellcheck with `-x`
# shellcheck disable=SC1091
source maven-illuminate.sh

# Check that dependencies required to perform a release are available
missing_deps=0
for cmd in {gpg,gpg-agent,git,mvn,createrepo,tar,sed}; do
    hash "$cmd" 2>/dev/null || {
        echo_error "Command '$cmd' is required but could not be found"
        missing_deps=$((missing_deps + 1))
    }
done
if [[ $missing_deps -gt 0 ]]; then
    echo_error "Aborted due to $missing_deps missing dependencies (see above)"
    exit 2
fi


if [[ -n $1 ]]; then
    RELEASE=$1
    if echo "$RELEASE" | grep -qv '^[1-9][0-9]\?\.\([1-9]\|1[012]\)\.[0-9]\+$'; then
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

QUATTOR_VERSION="$RELEASE"
if [[ -n $BUILD ]]; then
    QUATTOR_VERSION="$RELEASE-rc$BUILD"
fi

details=""


if gpg-agent; then
    if gpg --yes --output /tmp/"$(basename "$0")".gpg --sign "$0"; then
        echo -n "Preparing repositories for release... "
        cd "$RELEASE_ROOT" || exit 64
        mkdir -p src/
        cd src/ || exit 64

        echo "release: $RELEASE"

        for r in $REPOS_MVN; do
            if [[ ! -d $r ]]; then
                git clone -q "git@github.com:quattor/$r.git"
            fi
            cd "$r" || exit 72
            git fetch

            echo
            echo "$r"
            echo "repository: $r" | sed 's/./=/g'

            echo "release tag: "
            release_tag="$(git tag -l | grep -e "$QUATTOR_VERSION\$")"
            echo "    $release_tag"

            echo
            if [[ -n "${release_tag// }" ]]; then
                echo "checking out $release_tag"
                git checkout -q "$release_tag"
            else
                echo 'sticking with default branch'
            fi

            details="$details\n$r\t$(git branch | grep '^\*' || git tag --points-at HEAD)"
            cd ..
        done
        echo "Done."
        echo
        echo -e "$details" | column -t
        echo
        echo "We will package $QUATTOR_VERSION from the tags shown above, continue? yes/NO"
        echo -n "> "
        read -r prompt
        if [[ $prompt == "yes" ]]; then
            for r in $REPOS_MVN; do
                echo_info "---------------- Packaging $r ----------------"
                (
                    cd "$r" || exit 76
                    if ! mvn-c -q -DautoVersionSubmodules=true -Dgpg.useagent=true -Darguments=-Dgpg.useagent=true -B clean package; then
                        echo_error "RELEASE FAILURE"
                        exit 1
                    fi
                )
                echo
            done

            echo_success "---------------- Releases complete, building YUM repositories ----------------"

            cd "$RELEASE_ROOT" || exit 80
            mkdir -p target/

            echo_info "Collecting RPMs"
            TARGET_DIR="target/$QUATTOR_VERSION/$PACKAGE_SUFFIX"
            mkdir -p "$TARGET_DIR"
            find src/ -type f -name \*.rpm | grep /target/rpm/ | xargs -I @ cp @ "$TARGET_DIR/"

            echo_info "Signing RPMs"
            rpm --resign "$TARGET_DIR"/*.rpm

            echo_info "Creating repository"
            createrepo "$TARGET_DIR/"

            echo_info "Signing repository"
            gpg --detach-sign --armor "$TARGET_DIR/repodata/repomd.xml"

            echo_info "Creating repository tarball"
            tar -cjf "quattor-$QUATTOR_VERSION.tar.bz2" "$TARGET_DIR/"
            echo_info "Repository tarball built: target/quattor-$QUATTOR_VERSION.tar.bz2"

            echo_success "---------------- YUM repositories complete ----------------"

            echo_success "PACKAGING COMPLETED"
        else
            echo_error "PACKAGING ABORTED"
            exit 2
        fi
    fi
fi
