#!/bin/bash

function is_color_tty {
    ( [[ -t 1 ]] && tput colors >& /dev/null )
    return $?
}

if [[ "$DEBUGSCRIPT" == "1" ]]; then
    export PS4='+ \011 L$LINENO \011x: '
    if is_color_tty; then
        export PS4='+ \011 \e[0;45m L$LINENO\011\e[0m '
    fi
    set -x
fi

NAME="$(basename "${0%.sh}")"

# base destination directory, base for all other
DEST=${DEST:-$HOME/quattordev}

# if set to 1, cleans up more e.g. the repositories
RELEASE=${RELEASE:-0}

# Run a git clean on each repo
GITCLEAN=${GITCLEAN:-1}

# Run verbose
VERBOSE=${VERBOSE:-0}

# Enable wrapping of command output
RUN_WRAPPER=${RUN_WRAPPER:-1}

# mvn clean PACKAGE
PACKAGE=${PACKAGE:-package}

MINIMAL_DEPS_PATH="which"

now="$(date +%s)"
# List with all deps
REPODEPS_INSTALL_LIST=$DEST/repodeps_install_list.$now
# List with all yum install
YUM_INSTALL_LIST=$DEST/yum_install_list.$now
# Perl with all perl packages (incl version requirements) installed by cpan
PERL_CPAN_PERLPKG_INSTALL_LIST=$DEST/perl_cpan_perlpkg_install_list.$now
# List with all cpanm install
PERL_CPAN_INSTALL_LIST=$DEST/perl_cpan_install_list.$now

# The current redhat-release
RH_RELEASE="$(sed -n "s/.*release \([0-9]\+\).*/\1/p" /etc/redhat-release)"

function echo_info {
    prefix=""
    suffix="I:"
    if is_color_tty; then
        prefix="\e[0;44m"
        suffix="\e[0m"
    fi
    echo -e "${prefix}BUILD_ALL_REPOS ${suffix} $*"
}

function echo_error {
    prefix=""
    suffix="E:"
    if is_color_tty; then
        prefix="\e[0;41m"
        suffix="\e[0m"
    fi
    echo -e "${prefix}BUILD_ALL_REPOS ${suffix} $*"
}

function run_wrapped {
    # Run a command wrapping stdout and stderr to aid in identification of output text
    # Disabled by setting RUN_WRAPPER=0
    if [[ "$RUN_WRAPPER" -eq 1 ]]; then
        cmd=$1
        if [[ "$cmd" == "sudo" ]]; then
            cmd="$2"
        fi

        # Wrap with plain characters by default, use colour if output is a colour-capable TTY
        prefix=""
        stdout="O:"
        stderr="E:"
        suffix=""
        if is_color_tty; then
            prefix="\e[0;100m"
            stdout="\e[0;37m"
            stderr="\e[0;31m"
            suffix="\e[0m"
        fi

        cmd=$(printf '%15s' "$(basename "$cmd" | tr '[:lower:]' '[:upper:]')")
        # shellcheck disable=SC2068
        $@ \
            1> >(while read line; do echo -e "$prefix${cmd:0:15} $stdout $line$suffix" >&2; done) \
            2> >(while read line; do echo -e "$prefix${cmd:0:15} $stderr $line$suffix" >&2; done)
        return "$?"
    else
        # Wrapping disabled, just run exactly what we were passed
        # shellcheck disable=SC2068
        $@
        return "$?"
    fi
}

function check_perl_version {
    # Return 0 if perl version is greater than or equal to required version
    if [[ $# -eq 1 ]]; then
        perl -e 'use version' >& /dev/null
        if [[ $? -eq 0 ]]; then
            perl -e 'use version; exit ($^V >= version->new('"$1"') ? 0 : 1);'
        else
            echo_error "missing perl and/or perl version module. Assuming this is a very very old OS."
            return 3
        fi
    else
        return 2
    fi
}

function version_gte {
    # Return 0 if the first version passed as an argument is greater than or equal to the second version
    if [[ $# -eq 2 ]]; then
        perl -e 'use version; exit (version->new('"$1"') >= version->new('"$2"') ? 0 : 1);'
    else
        return 2
    fi
}

DISTRO_FAMILY=""
RH_RELEASE=0
DEBIAN_RELEASE=0
PACKAGE_MANAGER=""
USE_EPEL=0

if [[ -e /etc/redhat-release ]]; then
    DISTRO_FAMILY="rhel"

    # Perform RedHat Specific Setup
    echo_info "This appears to be a RedHat compatible distribution"

    # Assume yum is the packager for now
    # TODO: Test on Fedora and handle DNF properly
    PACKAGE_MANAGER="yum"

    MINIMAL_DEPS_PATH="$MINIMAL_DEPS_PATH rpm yum repoquery"

    # The current redhat-release
    RH_RELEASE="$(sed -n "s/.*release \([0-9]\+\).*/\1/p" /etc/redhat-release)"

    # Install and use the epel repo
    if [ "$RH_RELEASE" -eq 5 -o "$RH_RELEASE" -eq 6 ]; then
        USE_EPEL=1
    fi

    # Install and use rpmforge repo (expect rpm conflicts)
    if [ "$RH_RELEASE" -eq 5 ]; then
        # YAML::XS on el5?
        # try with cpan for now
        USE_RPMFORGE=0
    else
        USE_RPMFORGE=0
    fi
elif [[ -e /etc/debian_version ]]; then
    DISTRO_FAMILY="debian"

    # Perform Debian Specific Setup
    echo_info "This appears to be a Debian compatible distribution"

    PACKAGE_MANAGER="apt"

    DEBIAN_RELEASE="$(sed 's/\..*$//g' /etc/debian_version)"

    MINIMAL_DEPS_PATH="$MINIMAL_DEPS_PATH dpkg apt-get apt-cache"

    run_wrapped sudo apt-get -y install \
        libcdb-file-perl \
        libconfig-general-perl \
        libconfig-properties-perl \
        libconfig-tiny-perl \
        libcrypt-openssl-x509-perl \
        libcrypt-ssleay-perl \
        libdata-compare-perl \
        libdata-structure-util-perl \
        libenum-perl \
        libfile-copy-recursive-perl \
        libfile-touch-perl \
        libfile-which-perl \
        libgit-repository-perl \
        libio-string-perl \
        libjson-any-perl \
        libjson-xs-perl \
        liblwp-authen-negotiate-perl \
        libnet-dns-perl \
        libnetaddr-ip-perl \
        libparallel-forkmanager-perl \
        libperl-critic-perl \
        libreadonly-perl \
        librest-client-perl \
        libset-scalar-perl \
        libtaint-runtime-perl \
        libtemplate-perl \
        libtest-deep-perl \
        libtest-mockmodule-perl \
        libtest-mockobject-perl \
        libtest-nowarnings-perl \
        libtest-pod-perl \
        libtext-diff-perl \
        libtext-glob-perl \
        libversion-perl \
        libxml-parser-perl \
        libxml-simple-perl \
        libyaml-libyaml-perl
else
    # Unknown distribution type, bomb out
    echo_error "This does not appear to be a distribution we know how to support"
    exit 2
fi

# Don't add filters here just because something fails
POM_FILTER=""
REPO_FILTER=""

pom_filters=()
repo_filters=()

if ! check_perl_version 5.16.3; then
    # These will not work with el6 since they require perl 5.16.3
    pom_filters+=('openstack')
fi

if ! check_perl_version 5.10.1; then
    # These will not work with el5 since they require perl 5.10.1
    pom_filters+=('opennebula' 'systemd' 'ceph' 'icinga' 'freeipa')
    repo_filters+=('aii')
fi

if [[ ${#pom_filters[@]} -gt 0 ]]; then
    POM_FILTER="$(IFS='|' ; echo ".*\(${pom_filters[*]}\).*")"
fi

if [[ ${#repo_filters[@]} -gt 0 ]]; then
    REPO_FILTER="$(IFS='|' ; echo ".*\(${repo_filters[*]}\).*")"
fi

if [[ "$RH_RELEASE" -eq 7 ]]; then
    AQUILON=1
else
    AQUILON=0
fi

OS_HACK=1

EATMYDATA=${EATMYDATA:-0}

function usage () {
    cat <<EOF
$NAME is a bootstrap script for testing (and packaging) all Quattor repos,
without any Quattor or dependency modules required in the perl INC path(s).
After the script completes, there should be a local environment that can
be used for development.

The minimal requirements of this script are $MINIMAL_DEPS_PATH
(expected to be found in PATH).

The script will try to install as much dependencies and requirements
as possible using yum. When run as non-root, it requires sudo rights
to run 'yum', 'repoquery'.
(It might also add a EPEL maven repo file in /etc/yum.repos.d/ using
curl or wget ad sed; so also sudo rights for that are required).
This makes this user almost root, so be careful.

Installed dependencies are logged in timestamped files under $DEST
($REPODEPS_INSTALL_LIST, $YUM_INSTALL_LIST,
$PERL_CPAN_PERLPKG_INSTALL_LIST, $PERL_CPAN_INSTALL_LIST).

The Quattor git repositories are cloned and the remote 'upstream' is configured
to refer to them.
Any uncomitted changes will be stashed before master is updated. (I.e.
don't work in the master branch!)

For missing perl dependencies that can't be installed with yum, CPAN will
be used.

Environment variables:

DEST: DEST sets the basepath (current DEST=$DEST)

CHECKDEPS: CHECKDEPS=0 if you are running this as regular user and all dependencies
are ok (CHECKDEPS=1 will try to run yum) (current CHECKDEPS=$CHECKDEPS).

VERBOSE: VERBOSE=1 enables verbose logging (current VERBOSE=$VERBOSE)

DEBUGSCRIPT: DEBUGSCRIPT=1 enables debugging this script via set -x

PACKAGE: run 'mvn clean PACKAGE' (use e.g. test or package) (current PACKAGE=$PACKAGE)

ENABLEREPO: include repositories from yum/repoquery

DISABLEREPO: exclude repositories from yum/repoquery

RH_RELEASE: redhat major version (current RH_RELEASE=$RH_RELEASE)

USE_EPEL: install and use the epel-release repo (current USE_EPEL=$USE_EPEL)

USE_RPMFORGE: install and use the rpmforge-release repo (current USE_RPMFORGE=$USE_RPMFORGE)

POM_FILTER: remove matching lines from all pom.xml if not empty (current POM_FILTER=$POM_FILTER)

REPO_FILTER: do not test matching repo(s) (current REPO_FILTER=$REPO_FILTER)

OS_HACK: implement some OS specific hacks to get around some known issues with the OS (current OS_HACK=$OS_HACK)

Dangerous environment variables:

RELEASE: if set to 1, it will remove the existing repositories and do some
other intrusive cleanups. DON'T USE IT if you are not sure you need it.

GITCLEAN: GITCLEAN=0 if you made local modification to the repositories and want
to test with them (otherwise the repositories will be cleaned)
(current GITCLEAN=$GITCLEAN). [TODO: reinvestigate what this means now that we stash]

EATMYDATA: will build and preload the libeatmydata library. Will speed up this script,
but intermediate powercuts might render unusable systems as fsync is mocked.
Default is 0 (set to 1 to enable).


EOF
    exit 2
}

echo_info "$NAME START $(date +%s) $(date)"

# maven-tools is both testonly and packageonly
# due to the build-scripts/package-build-scripts structure

# only testing, and early dependency resolution no package
REPOS_MVN_TESTONLY_ORDERED="maven-tools"
# ordered list of repository names
REPOS_MVN_ORDERED="LC CAF CCM ncm-ncd ncm-lib-blockdevices aii configuration-modules-core configuration-modules-grid cdp-listend ncm-cdispd ncm-query"
# the package only step, no previous testing or dependency resolution is done
REPOS_MVN_PACKAGEONLY_ORDERED="maven-tools"

# pseudo-install dir
INSTALL="$DEST/install"
# perl5lib dir in INSTALL
# LC is under lib/perl, remainder under usr/lib/perl?
CPANINSTALL="$INSTALL/usr"
INSTALLPERL="$INSTALL/lib/perl:$INSTALL/usr/lib/perl:$CPANINSTALL/lib/perl5"

# gather all produced rpms
RPMS="$DEST/rpms"

# the original PERL5LIB
ORIGPERL5LIB="$PERL5LIB"

# repository dir
REPOSITORY="$DEST/repos"
# a checkout in the same base directory is default (but lets set this anyway)
export QUATTOR_TEST_TEMPLATE_LIBRARY_CORE="$REPOSITORY/template-library-core"


if [[ ! -z "$VERBOSE" ]]; then
    # verbose tests
    export QUATTOR_TEST_LOG_CMD_MISSING=1
    export QUATTOR_TEST_LOG_CMD=1
    PROVEARGS="-Dprove.args=-v"
fi

# Dependencies checking
# set to 0 on non-yum systems
CHECKDEPS=${CHECKDEPS:-1}

# Main init binaries
YUM_MAIN_INIT_BIN="repoquery curl wget"

# Binary dependencies (/usr/bin/<name>) to be installed with yum
YUM_DEPS_INIT_BIN="rpmbuild perl tar"

# Dependencies (package names) to be installed
YUM_DEPS_INIT="rpmlint perl-parent perl-IO-Compress-Zlib"

# only major.minor!
PAN_MIN_VERSION=10.7
PAN_MIN_VERSION_RPM_URL="https://github.com/quattor/pan/releases/download/pan-${PAN_MIN_VERSION}/panc-${PAN_MIN_VERSION}-1.noarch.rpm"

# quattor externals repo
USE_QEXT=1
YUM_QEXT_REPO_URL="https://raw.githubusercontent.com/quattor/release/master/quattor-repo/src/quattor.repo"

# the mvn epel url (who has this mirrored/enabled by default?)
YUM_EPEL_MVN_REPO="https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo"

# EPEL repo
YUM_EPEL_REPO_RPM="https://dl.fedoraproject.org/pub/epel/epel-release-latest-${RH_RELEASE}.noarch.rpm"

# repoforge repo
YUM_RPMFORGE_REPO_RPM="http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.3-1.el${RH_RELEASE}.rf.x86_64.rpm"

# noreplace (config) files
NOREPLACE_FILES="/etc/ccm.conf /etc/cdp-listend.conf /etc/ncm-ncd.conf /etc/ncm-cdispd.conf"

IUS_REPO_RPM_EL7=https://dl.iuscommunity.org/pub/ius/stable/CentOS/7/x86_64/ius-release-1.0-15.ius.centos7.noarch.rpm
AQUILON_PROTO_BUILDSCRIPT=https://raw.githubusercontent.com/quattor/release/master/src/scripts/build_last_aq_proto_releases.sh
AQUILON_BUILDSCRIPT=https://raw.githubusercontent.com/quattor/release/master/src/scripts/build_last_aquilon_release.sh

RPMLINT_1_CONFIG=https://raw.githubusercontent.com/quattor/release/master/src/rpmlint/config/quattor.py
RPMLINT_2_CONFIG=https://raw.githubusercontent.com/quattor/release/master/src/rpmlint/config/quattor.toml

if [[ ! -z "$ENABLEREPO" ]]; then
    ENABLEREPOSFULL="--enablerepo=$ENABLEREPO"
fi

if [[ ! -z "$DISABLEREPO" ]]; then
    DISABLEREPOSFULL="--disablerepo=$DISABLEREPO"
fi

function error () {
    # at least 2 arguments: exit code, the remainder is message
    ec=$1
    shift
    echo_info "export PERL5LIB=$PERL5LIB"
    echo_info "export PWD=$PWD"
    echo_info "export PATH=$PATH"
    echo_error "$@"
    exit "$ec"
}

function cerror () {
    # conditional error
    fatal=$1
    shift
    if [[ "$fatal" -gt 0 ]]; then
        error "$@"
    else
        echo_info "$* (not fatal)"
    fi
}

function cd_or_die {
    # Change directory or die trying
    cd "$@" || error 2 "Failed to change directory to $*"
    return 0
}

ID="$(/usr/bin/id -u)"
if [[ -z "$ID" || $ID -ne 0 ]]; then
    SUDO=sudo
else
    SUDO=''
fi

YUMYES="-y $DISABLEREPOSFULL $ENABLEREPOSFULL"

function doyum () {
    echo_info "${1}-ing pkgs with '$SUDO yum $YUMYES $*'"
    # shellcheck disable=SC2086
    $SUDO yum $YUMYES "$@"
    return $?
}


function makecache () {
    if [[ ! -z "$1" ]]; then
        doyum clean "$1"
    fi
    # shellcheck disable=SC2086
    doyum makecache $DISABLEREPOSFULL $ENABLEREPOSFULL
    return $?
}


THEDEPCACHE=""
# Keep bash dependency cache
function add_has_dep () {
    dep="$1"
    add=${2:-0}
    # dep might might contain whitespace
    depname="DEPCACHE $(echo "$dep" | tr '\n' '_') EHCACPED"
    echo $THEDEPCACHE | grep "$depname" >& /dev/null
    has_dep=$?

    msg="in"
    if [[ "$has_dep" -gt 0 ]]; then
        if [[ "$add" -ne 0 ]]; then
            THEDEPCACHE="$THEDEPCACHE $depname"
            msg="added to"
        else
            msg="not in"
        fi
    fi

    echo_info "add_has_dep $dep $msg THEDEPCACHE"

    return $has_dep
}

function get_cpanm () {
    echo_info "Get and install cpanm"

    # Try to get as much as possible via yum
    # CPAN itself should come from yum, no way this will work otherwise
    deps_install_yum 'perl(CPAN)' 1

    deps_install_yum 'perl(JSON::XS)' 0
    deps_install_yum 'perl(App::cpanminus)' 0

    # Some dependencies for building perl modules
    for dep in gcc-c++ make; do
        deps_install_yum "$dep"
    done

    which curl >& /dev/null
    if [[ $? -gt 0 ]]; then
        which wget >& /dev/null
        if [[ $? -gt 0 ]]; then
            error 30 "get_cpanm no curl or wget found"
        else
            wget -O - http://cpanmin.us | perl - --self-upgrade
        fi
    else
        curl -L http://cpanmin.us | perl - --self-upgrade
    fi

    if [[ $? -gt 0 ]]; then
        error 31 "fetch and install cpanm failed"
    else
        echo_info "get_cpanm OK"
    fi

    # Add cpanm (for el5 only?)
    export PATH=$HOME/perl5/bin:$PATH

    return 0
}


function download () {
    url="$1"
    fn="$2"
    sudo="$3"

    which curl >& /dev/null
    if [[ $? -gt 0 ]]; then
        which wget >& /dev/null
        if [[ $? -gt 0 ]]; then
            error 80 "download no curl or wget found"
        else
            exe=wget
            opt=-O
        fi
    else
        exe=curl
        opt="-L -o"
    fi

    echo_info "download with $sudo $exe $opt $fn $url"
    run_wrapped "$sudo $exe" "$opt" "$fn" "$url"
    return $?

}

function has_correct_panc () {
    pancversion="$(panc --version 2>/dev/null | sed -n "s/.*:[ ]*\([0-9]\+\)\.\([0-9]\+\).*/\1.\2/p")"

    if [[ ! -z "$pancversion" ]]; then
        maj1=${pancversion%.*}
        min1=${pancversion#*.}

        maj2=${PAN_MIN_VERSION%.*}
        min2=${PAN_MIN_VERSION#*.}

        if [[ "$maj1" -gt "$maj2" ]]; then
            return 0
        fi

        if [[ "$maj1" -eq "$maj2" ]]; then
            if [[ "$min1" -ge "$min2" ]]; then
                return 0
            fi
        fi
    fi

    return 1
}

function localinstall_url () {
    rpmurl=$1
    localrpm=$2
    installopts=$3

    download "$rpmurl" "$localrpm"
    if [[ $? -ne 0 ]]; then
        error 100 "Failed to download $rpmurl"
    fi
    # panc rpm is not signed
    doyum localinstall "$installopts" "$localrpm"
    if [[ $? -ne 0 ]]; then
        error 101 "Failed to do localinstall of $localrpm from $rpmurl"
    fi
}

function has_panc () {
    has_correct_panc
    if [[ $? -ne 0 ]]; then
        deps_install_yum "panc >= $PAN_MIN_VERSION" 0
        has_correct_panc
        if [[ $? -ne 0 ]]; then
            localinstall_url "$YUM_PAN_MIN_VERSION_RPM_URL" "$DEST/panc-${PAN_MIN_VERSION}.rpm" "--nogpgcheck"
        fi
    fi
}

function check_quattor_externals () {
    if [[ "$USE_QEXT" -gt 0 ]]; then
        fn=/etc/yum.repos.d/quattor.repo
        download "$YUM_QEXT_REPO_URL" "$fn" "$SUDO"
        if [[ $? -gt 0 ]]; then
            error 102 "Failed to download quattor repo $YUM_QEXT_REPO_URL to $fn with '$SUDO $exe $opt'"
        fi
        # remove the quattor and aquilon repos; should only leave the externals
        $SUDO sed -i '/quattor\]/,+5d;/quattor_aquilon\]/,+5d' "$fn"

        makecache expire-cache
    fi
}

function check_epel () {
    if [[ "$USE_EPEL" -gt 0 ]]; then

        if [[ "$RH_RELEASE" -eq 5 ]]; then
            # EPEL5 zombie mode
            YUM_EPEL_REPO_RPM="${YUM_EPEL_REPO_RPM//pub\/epel\//pub\/archive\/epel\/}"
        fi

        localinstall_url "$YUM_EPEL_REPO_RPM" "$DEST/epel-release-$RH_RELEASE.rpm" "--nogpgcheck"

        if [[ "$RH_RELEASE" -eq 5 ]]; then
            # EPEL5 zombie mode
            $SUDO sed '/mirrorlist/d;s/^#baseurl/baseurl/;s#pub/epel/#pub/archive/epel/#' -i /etc/yum.repos.d/epel*.repo
        fi

        makecache expire-cache
    fi
}

function check_rpmforge () {
    if [[ "$USE_RPMFORGE" -gt 0 ]]; then
        localinstall_url "$YUM_RPMFORGE_REPO_RPM" "$DEST/rpmforge-release-$RH_RELEASE.rpm" "--nogpgcheck"
        makecache expire-cache
    fi
}

function has_mvn () {
    mvn="mvn"
    # this one is typically missing from repos etc etc
    which $mvn >& /dev/null
    if [[ $? -gt 0 ]]; then
        echo_info "No maven executable $mvn found in PATH"

        makecache
        deps_install_yum "*bin/mvn" 0
        if [[ $? -gt 0 ]]; then
            fn=/etc/yum.repos.d/check_deps_mvn.repo
            echo_info "Couldn't get mvn $mvn via yum. Going to add the mvn epel repo $YUM_EPEL_MVN_REPO to $fn and retry."
            download "$YUM_EPEL_MVN_REPO" "$fn" "$SUDO"
            if [[ $? -gt 0 ]]; then
                error 84 "Failed to download maven repo $YUM_EPEL_MVN_REPO to $fn with '$SUDO $exe $opt'"
            fi

            # releasever but repos have single digits/RHEL naming
            if [[ -z "$RH_RELEASE" ]]; then
                error 81 "No major release version found via /etc/redhat-release"
            fi
            echo_info "Going to use releasever $RH_RELEASE for this repo"
            $SUDO sed -i "s/\$releasever/$RH_RELEASE/g" "$fn"

            if [[ $? -gt 0 ]]; then
                error 82 "has_mvn fetch mvn epel repo $YUM_EPEL_MVN_REPO failed"
            fi

            makecache
            # now it's fatal
            deps_install_yum "*bin/mvn" 1
        fi
    fi

    # Required on EL5
    if [[ -f /etc/profile.d/apache-maven.sh ]]; then
        . /etc/profile.d/apache-maven.sh
    fi

    return 0
}

function os_hack () {
    if [[ "$RH_RELEASE" -eq 5 ]]; then
        # cpanm sometimes does not install in the directory passed
        export INSTALLPERL="$HOME/perl5/lib/perl5/:$INSTALLPERL"
        export PERL5LIB="$INSTALLPERL"

        # Force recent install of JSON::XS (CCM::Fetch has 'use JSON::XS v2.3.0'
        # but the perl.req script is too buggy to spot the version)

        # Force install very recent Pod::Simple, Test::More and JSON::XS
        # To be fixed in build-scripts
        for dep in "Pod::Simple" "Test::More" "JSON::XS"; do
            get_cpan_dep "perl($dep)"
        done
    else
        if [[ "$RH_RELEASE" -eq 6 ]]; then
            # Force install very recent Pod::Simple
            # To be fixed in build-scripts
            for dep in "Pod::Simple"; do
                get_cpan_dep "perl($dep)"
            done
        fi
    fi
}

function check_deps_minimal () {
    for pkg in $MINIMAL_DEPS_PATH; do
        which "$pkg" >& /dev/null
        if [[ $? -gt 0 ]]; then
            error 60 "Failed minimal dependency $pkg"
        fi
    done
}

function deps_install_yum () {
    dep="$1"
    # default fatal
    fatal=${2:-1}

    ec=0

    if [[ -z "$dep" ]]; then
        echo_info "Trying to install empty dependency."
        return 0
    fi

    echo_info "Searching for dep $dep with $SUDO repoquery -C --qf '%{name}' $DISABLEREPOSFULL $ENABLEREPOSFULL --whatprovides \"$dep\""
    # shellcheck disable=SC2086
    pkgs="$($SUDO repoquery -C --qf '%{name}' $DISABLEREPOSFULL $ENABLEREPOSFULL --whatprovides "$dep" 2>/dev/null | grep -v 'No package provides' | sort | uniq)"
    if [[ -z "$pkgs" ]]; then
        ec=70
        cerror "$fatal" "$ec" "No packages found for dep $dep with repoquery"
    fi

    for pkg in $pkgs; do
        doyum install "$pkg"
        if [[ $? -gt 0 ]]; then
            ec=71
            cerror "$fatal" "$ec" "Failed installation of pkg $pkg with yum"
        else
            echo "$pkg" >> "$YUM_INSTALL_LIST"
            add_has_dep "$dep" 1
        fi
    done

    return $ec
}

function yum_deps_init_bin () {
    makecache expire-cache

    # these are fatal
    echo_info "Checking YUM_DEPS_INIT_BIN $YUM_DEPS_INIT_BIN"
    for bin in $YUM_DEPS_INIT_BIN; do
        deps_install_yum "*bin/$bin" 1
    done

    echo_info "Checking other deps: $YUM_DEPS_INIT"
    for dep in $YUM_DEPS_INIT; do
        deps_install_yum "$dep" 1
    done

    # should be part of rpmbuild dep
    for name in find-requires perl.req find-provides perl.prov; do
        fn=/usr/lib/rpm/$name
        if [[ ! -f "$fn" ]]; then
            deps_install_yum $fn 1
        fi
    done

    echo_info "Done checking DEPS_INIT_BIN $DEPS_INIT_BIN"
    return 0
}

function get_cpan_dep () {
    perldep="$1"

    fatal=${2:-1}

    perlpkg="$(echo "$perldep" | sed -n "s/^perl(\(.*\))\(.*\(\s[0-9]\+.*\)\)\?$/\1\3/p")"

    # No version info
    perlcpan="$(echo "$perldep" | sed -n "s/^perl(\(.*\))\(.*\(\s[0-9]\+.*\)\)\?$/\1/p")"

    echo_info "Looking for CPAN perlcpan $perlcpan for dependency $perldep"

    run_wrapped cpanm --local-lib="$CPANINSTALL" "$perlcpan"

    if [[ $? -eq 0 ]]; then
        echo_info "Perl dependency $perldep installed via CPAN"
        perl -e "use $perlpkg;"
        if [[ $? -eq 0 ]]; then
            echo_info "Dependency $dep is a usable perl package"
            echo "$perlpkg" >> "$PERL_CPAN_PERLPKG_INSTALL_LIST"
            echo "$perlcpan" >> "$PERL_CPAN_INSTALL_LIST"
            add_has_dep "$perldep" 1
        else
            ec="91"
            cerror "$fatal" "$ec" "Dependency $dep installed via CPAN (perlcpan $perlcpan) but not usabele (perlpkg $perlpkg)"
        fi
    else
        ec=90
        cerror "$fatal" "$ec" "Perl dependency $perldep installed via CPAN failed"
    fi

}

function get_repo_deps () {
    repo=$1
    fatal=${2:-1}

    cd_or_die "$REPOSITORY"

    # look for src subdirs (like AII or components)
    subdirs="$(find "$repo" -type d -name src)"

    echo_info "Found subdirs for repository $repo : $subdirs"

    for dir in $subdirs; do
        cd_or_die "$REPOSITORY"
        # use dirname to scan both src/ and target/
        get_repo_deps_subdir "$repo" "$(dirname "$dir")" "$fatal"
    done
}

function get_repo_deps_subdir () {
    repo=$1

    # repo + optional subdir
    dir=${2:-$repo}

    fatal=${3:-1}

    cd_or_die "$dir"

    origIFS="$IFS"
    # newline is the only delimiter for IFS
    fakeIFS="
"
    export IFS="$fakeIFS"

    # only search src and target (there's some legacy code in other dirs)
    # ignore mock modules from test/resources (and assume they have dependencies resolved elsewhere)
    # TT have 'use X', which perl.req thinks are perl modules
    found="$(find {src,target} -type f  ! -regex '.*\.tt' ! -regex '.*src/test/resources/.*')"

    # find-requires doesn't cover perl .t files
    deps="$( (echo "$found" | /usr/lib/rpm/perl.req ; echo "$found" | /usr/lib/rpm/find-requires) | sort | uniq | grep -E '\w')"
    echo_info "Dependencies found for repo $repo (dir $dir): $deps"

    # this is what the current repository provides. they are not to be searched externally
    provs="$( (echo "$found" | /usr/lib/rpm/perl.prov ; echo "$found" | /usr/lib/rpm/find-provides) | sort | uniq | grep -E '\w')"
    echo_info "Provides found for repo $repo (dir $dir): $provs"

    # WARNING dep can have whitespace!
    for dep in $deps; do
        echo_info "Checking dependency '$dep'"
        export IFS="$origIFS"

        add_has_dep "$dep"
        if [[ $? -ne 0 ]]; then
            echo "$provs" | grep "$dep" >& /dev/null
            if [[ $? -eq 0 ]]; then
                echo_info "Dependency $dep is provided by this repository"
            else
                echo "$dep" >> "$REPODEPS_INSTALL_LIST"
                perlpkg="$(echo "$dep" | sed -n "s/^perl(\(.*\))\(.*\(\s[0-9]\+.*\)\)\?$/\1\3/p")"
                if [[ -z "$perlpkg" ]]; then
                    echo_info "Dependency $dep is not a perl package"
                    # is it a full path?
                    if [[ "$dep" == /* ]] && [ -f "$dep" ]; then
                        echo_info "Dependency $dep is a absolute filename and exists"
                        add_has_dep "$dep" 1
                    else
                        deps_install_yum "$dep" "$fatal"
                    fi
                else
                    # Test if the perl module is usable
                    echo_info "Dependency $dep is a perl package"
                    # The unittests run prove with additional paths
                    PERL5LIB="$PERL5LIB:src/test/perl:target/lib/perl" perl -e "use $perlpkg;"
                    if [[ $? -eq 0 ]]; then
                        echo_info "Dependency $dep is a usable perl package"
                        add_has_dep "$dep" 1
                    else
                        # try to get it with yum
                        deps_install_yum "$dep" 0
                        if [[ $? -eq 0 ]]; then
                            echo_info "Dependency $dep is a perl package found with yum"
                        else
                            get_cpan_dep "$dep" "$fatal"
                        fi
                    fi
                fi
            fi
        fi
        export IFS="$fakeIFS"
    done
    export IFS="$origIFS"
}

function reset_perl5lib () {

    unset PERL5LIB

    # add the /_nodir for easy parsing (now all real paths are followed with a :)
    if [[ -z "$ORIGPERL5LIB" ]]; then
        PERL5LIB="$INSTALLPERL:/_nodir"
    else
        PERL5LIB="$INSTALLPERL:$ORIGPERL5LIB:/_nodir"
    fi

    echo_info "reset_perl5lib PERL5LIB $PERL5LIB"
    export PERL5LIB
}

function git_repo () {
    local repo
    repo=$1

    here="$PWD"

    if [[ -z "$repo" ]]; then
        error 20 "No repository passed as argument"
    else
        echo_info "git_repo for repository $repo"
    fi

    if [[ ! -d "$REPOSITORY" ]]; then
        error 21 "No REPOSITORY directory $REPOSITORY"
    fi
    cd_or_die "$REPOSITORY"

    if [[ "$RELEASE" -gt 0 ]]; then
        echo_info "RELEASE Removing repository"
        rm -Rf "./$repo"
    fi

    if [[ ! -d "./$repo" ]]; then
        cmd="git clone https://github.com/quattor/$repo.git"
        # Don't quote arguments as we want to allow the shell to do globbing and word splitting
        # shellcheck disable=SC2086
        run_wrapped $cmd
        if [[ $? -gt 0 ]]; then
	        error 23 "$cmd failed"
        fi

        cd_or_die "$repo"
        run_wrapped git remote rename origin upstream
        if [[ $? -gt 0 ]]; then
	        error 24 "failed to rename origin to upstream"
        fi

        cd_or_die "$REPOSITORY"
    fi

    cd_or_die "$repo"

    # stash any local changes
    run_wrapped git stash

    # maven-tools clone doesn't start in master?
    run_wrapped git checkout master

    if [[ "$GITCLEAN" -gt 0 ]]; then
        echo_info "git clean"
        run_wrapped git clean -fxd
    else
        echo_info "git clean disabled"
    fi

    cmd="git pull upstream master"
    # Don't quote arguments as we want to allow the shell to do globbing and word splitting
    # shellcheck disable=SC2086
    run_wrapped $cmd
    if [[ $? -gt 0 ]]; then
        error 22 "$cmd for repository $repo failed"
    fi

    cd_or_die "$here"
    return 0
}

function prepare_build () {
    local repo
    repo=$1

    if [[ -z "$repo" ]]; then
        error 10 "prepare_build No repository passed as argument"
    else
        echo_info "prepare_build repository $repo"
    fi

    if [[ ! -d "$REPOSITORY" ]]; then
        error 12 "No REPOSITORY directory $REPOSITORY"
    fi

    cd_or_die "$REPOSITORY"
    git_repo "$repo"

    return 0
}

function mvn_compile () {
    local repo
    repo=$1
    shift

    cd_or_die "$REPOSITORY/$repo"

    mvntgt="compile"

    # the PERL5LIB path for this repo during testing
    if [[ "$repo" == "maven-tools" ]]; then
        echo_info "Exception for maven-tools repository: entering subdir build-scripts"
        cd_or_die build-scripts
    fi

    # always clean?
    clean="clean"
    mvn="mvn $clean $mvntgt $PROVEARGS"
    echo_info "mvn_compile for repository $repo in $PWD : $mvn"
    # Don't quote arguments as we want to allow the shell to do globbing and word splitting
    # shellcheck disable=SC2086
    run_wrapped $mvn
    if [[ $? -gt 0 ]]; then
        error 13 "mvn_compile mvn $mvntgt failed for repository $repo (cmd $mvn)"
    fi

    # Configure the PERL5LIB path for this repo during testing
    # Find target perl directories, which may be re-used later (e.g. by AII)
    # As POMs can recurse there may be more than one.
    if [[ "$repo" == "maven-tools" ]]; then
        echo_info "Exception for maven-tools repository: using non-target tgtperl"
        tgtperl="$PWD/src/main/perl/"
    else
        tgtperl="$(find "$PWD" -type d -name perl | grep '/target/lib/perl$' | paste -sd ':' -)"
    fi

    # add the target path to PERL5LIB
    PERL5LIB="$tgtperl:$PERL5LIB"
    # INSTALLPERL is always first dir
    # Substring Replacement cannot be used as search string is a variable
    # shellcheck disable=SC2001
    PERL5LIB="$(echo "$PERL5LIB" | sed "s%$INSTALLPERL:%%")"
    export PERL5LIB="$INSTALLPERL:$PERL5LIB"
    echo_info "Added $tgtperl to PERL5LIB for repository $repo after mvn compile : PERL5LIB $PERL5LIB"

    return 0
}

function mvn_package () {
    local repo
    repo=$1
    mvntgt=${2:-$PACKAGE}

    cd_or_die "$REPOSITORY/$repo"

    tgtperl="$PWD/target/lib/perl/"
    if [[ "$repo" == "maven-tools" ]]; then
        if [[ "$mvntgt" == "$PACKAGE" ]]; then
            echo_info "Exception for maven-tools repository: entering subdir package-build-scripts"
            cd_or_die package-build-scripts
        else
            echo_info "Exception for maven-tools repository: entering subdir build-scripts and using non-target tgtperl"
            cd_or_die build-scripts
            tgtperl="$PWD/src/main/perl/"
        fi
    fi

    # remove compile target from PERL5LIB; this repo should be available via INSTALL at the end
    # Substring Replacement cannot be used as search string is a variable
    # shellcheck disable=SC2001
    PERL5LIB="$(echo "$PERL5LIB" | sed "s%$tgtperl:%%")"
    export PERL5LIB
    echo_info "Removed $tgtperl from PERL5LIB for repository $repo after mvn $PACKAGE. New PERL5LIB $PERL5LIB"

    # always clean?
    clean="clean"
    mvn="mvn $clean $mvntgt $PROVEARGS"
    echo_info "mvn_package for repository $repo in $PWD : $mvn"

    if [[ ! -z "$POM_FILTER" ]]; then
        echo_info "Deleting matching lines with POM_FILTER $POM_FILTER"
        sed -i "/$POM_FILTER/d" pom.xml
    fi

    # Don't quote arguments as we want to allow the shell to do globbing and word splitting
    # shellcheck disable=SC2086
    run_wrapped $mvn
    mvnec=$?

    if [[ ! -z "$POM_FILTER" ]]; then
        # restore pom.xml to avoid later git conflicts
        cp pom.xml "pom.xml.filtered.$(date +%s)"
        git checkout pom.xml
    fi


    if [[ "$mvnec" -gt 0 ]]; then
        error 13 "mvn_package mvn $mvntgt failed for repository $repo (cmd $mvn)"
    fi

    if [[ "$mvntgt" == "package" ]]; then
        echo_info "Looking for rpm in {target,*/target} in $PWD"
        rpms="$(find {target,*/target} -type f -name \*.rpm)"
        if [[ -z "$rpms" ]]; then
            error 14 "No rpms found for repository $repo"
        else
            echo_info "Rpms $rpms build for repository $repo"
            for rpm in $rpms; do
                cp "$rpm" "$RPMS"
                echo_info "Copied rpm $rpm to RPMS $RPMS"
            done
        fi

        echo_info "Looking for tar.gz in {target,*/target} in $PWD"
        tars="$(find {target,*/target} -type f -name \*.tar.gz)"
        if [[ -z "$tars" ]]; then
            error 15 "No tar.gz found for repository $repo"
        else
            echo_info "Found tars $tars"
            for tgz in $tars; do
                run_wrapped tar -C "$INSTALL" -xvzf "$tgz"
                if [[ $? -gt 0 ]]; then
                    error 16 "Failed to unpack tarball for repository $repo in INSTALL $INSTALL"
                else
                    echo_info "unpacked tarball $tgz for repository $repo in INSTALL $INSTALL"
                fi
            done
        fi
    fi

    return 0
}

function YUM_MAIN_INIT_BIN () {
    miby="$*"

    echo_info "Checking YUM_MAIN_INIT_BIN $miby"
    for bin in $miby; do
        binpath="/usr/bin/$bin"
        if [[ ! -f "$binpath" ]]; then
            cmd="$SUDO yum install $YUMYES $binpath"
            # Don't quote arguments as we want to allow the shell to do globbing and word splitting
            # shellcheck disable=SC2086
            run_wrapped $cmd
            if [[ $? -gt 0 ]]; then
                error 19 "Failed to install $bin as part of YUM_MAIN_INIT_BIN $miby"
            else
                echo_info "Installed $bin with $cmd"
            fi
        fi
    done
}

function eatmydata () {
    echo_info "Building libeatmydata"
    local lemd
    lemd="$DEST/libeatmydata"
    mkdir -p "$lemd"
    cd_or_die "$lemd"

    # same as for cpanm + unzip
    for dep in gcc-c++ make unzip; do
        deps_install_yum "$dep"
    done

    download "https://github.com/dmwm/libeatmydata/archive/master.zip" "$lemd/master.zip"
    unzip "$lemd/master.zip"
    cd_or_die "libeatmydata*master"
    if [[ $? -gt 0 ]]; then
        error 130 "Downloading and unpacking libeatmydata failed"
    fi

    run_wrapped make

    LIBEATMYDATA=$PWD/libeatmydata.so
    if [[ ! -f "$LIBEATMYDATA" ]]; then
        error 131 "Cannot find LIBEATMYDATA $LIBEATMYDATA"
    fi

    # enable it
    export LD_PRELOAD=$LIBEATMYDATA

    cd_or_die "$DEST"
}

function main_init () {
    reset_perl5lib

    if [[ "$RH_RELEASE" -eq 5 ]]; then
        # CentOS5 zombie mode: use vault and latest release
        $SUDO sed '/mirrorlist/d;s/^#baseurl/baseurl/;s#mirror.centos.org/centos#vault.centos.org#;s/[$]releasever/5.11/' -i /etc/yum.repos.d/CentOS-*repo
    fi

    makecache all

    # provided by yum-utils
    # Don't quote arguments as we want to allow the shell to do globbing and word splitting
    # shellcheck disable=SC2086
    YUM_MAIN_INIT_BIN $YUM_MAIN_INIT_BIN

    if [[ "$EATMYDATA" -gt 0 ]]; then
        eatmydata
    fi

    # do it separately
    check_quattor_externals
    check_epel
    check_rpmforge

    # get git (EL5 needs epel; to get epel you need curl/wget)
    YUM_MAIN_INIT_BIN git

    check_deps_minimal
    check_deps_init_bin

    has_mvn
    has_panc

    # slowish
    get_cpanm

    if [[ "$OS_HACK" -gt 0 ]]; then
        os_hack
    fi

    # generate the environment
    cat > "$DEST/env.sh" <<EOF
# Source this file to get the proper environment
export PERL5LIB=$INSTALLPERL
export QUATTOR_TEST_TEMPLATE_LIBRARY_CORE=$QUATTOR_TEST_TEMPLATE_LIBRARY_CORE
export PATH=$PATH
EOF

    if [[ "$EATMYDATA" -gt 0 ]]; then
        # commented by default
        echo "#export LD_PRELOAD=$LIBEATMYDATA" >> "$DEST/env.sh"
    fi

}

function test_rpms() {

    # Not the fastest way ever
    for file in $NOREPLACE_FILES; do
        for rpm in $RPMS/*.rpm; do
            decimal_bits=$(rpm -q --qf '[%{filenames}: %{fileflags}\n]' -p "$rpm" | grep -e "^$file:"| sed -e "s#$file: *##;")
            if [[ ! -z "$decimal_bits" ]]; then
                # check for 4th bit
                bitset=$((decimal_bits & 16))
                if [[ "$bitset" -ne 16 ]]; then
                    error 110 "Rpm $rpm provides noreplace file $file without noreplace bits set: $decimal_bits"
                fi
            fi
        done
    done

    rpmlint_cmd="rpmlint"
    read -r rpmlint_major rpmlint_minor _ <<< "$(rpmlint --version | grep -Eo '[0-9]+(\.[0-9]+)+' | tr '.' ' ')"

    # If version 2.4.0 or greater
    if [[ $rpmlint_major -gt 2 || ($rpmlint_major -eq 2 && $rpmlint_minor -ge 4) ]]; then
        rpmlint_dir="$(mktemp -d)"
        run_wrapped wget -P "$rpmlint_dir" "$RPMLINT_2_CONFIG"
        rpmlint_cmd="rpmlint --config $rpmlint_dir"
    elif [[ $rpmlint_major -eq 1 && $rpmlint_minor -ge 5 ]]; then
        rpmlint_dir="$(mktemp -d)"
        run_wrapped wget -P "$rpmlint_dir" "$RPMLINT_1_CONFIG"
        rpmlint_cmd="rpmlint --file $rpmlint_dir/quattor.py"
    fi
    echo_info "Checking rpms in $RPMS with rpmlint"
    run_wrapped "$rpmlint_cmd" "$RPMS"
    if [[ $? -gt 0 ]]; then
        error 111 "rpmlint failed"
    fi
}

function build_aquilon_protocols() {
    # ugly
    local fn ius

    # need very recent git for sorting tags on date
    ius="ius-release"
    download "$IUS_REPO_RPM_EL7" "$ius.rpm"
    doyum localinstall "$ius.rpm"
    doyum remove git git-core-doc git-core
    doyum install git2u
    doyum remove "$ius"
    doyum clean all

    # This is the only requirement
    doyum install protobuf-compiler

    fn=/tmp/aquilon_protocols_build.sh
    download "$AQUILON_PROTO_BUILDSCRIPT" "$fn"
    chmod +x "$fn"

    export BASE=$PWD
    $fn

    # install it, not the src rpm
    latest=$(sed "s/-/_/" "$BASE/latest")
    doyum localinstall "$BASE/aquilon-protocols/dist/*$latest*.noarch.rpm"
}

function build_aquilon() {
    # ugly
    local fn
    doyum install docbook5-style-xsl docbook5-schemas

    fn=/tmp/aquilon_build.sh
    download "$AQUILON_BUILDSCRIPT" "$fn"
    chmod +x "$fn"

    export BASE=$PWD
    $fn

    # get all deps
    doyum localinstall "$BASE/aquilon/dist/*.noarch.rpm"

    # to run tests
    RUNAQTESTS=0
    if [ $RUNAQTESTS -gt 0 ]; then
        $SUDO rpm -e aquilon
        doyum install python-devel libxml2-devel libxslt-devel
        cd "$BASE/aquilon" || exit 1
        # install bunch of test deps, like more recent protobuf?
        # why not setuptools and tests_require?

        for dep in $(git grep ms.version.addpkg tests/ |tr '"' "'"|sed "s/.*addpkg('//;s/', \?'.*//"|sort|uniq); do
            echo "Installing aquilon test python dep $dep using fuzzy yum"
            doyum install "$dep" "python-$dep"
        done

        # some require more recent setuptools?
        #easy_install --user -U setuptools
        for dep in $(git grep ms.version.addpkg tests/ |tr '"' "'"|sed "s/.*addpkg('//;s/')//;s/', \?'/>=/"|sort|uniq); do
            echo "Installing aquilon test python dep $dep"
            easy_install --user "$dep"
        done
        yes yes | PYTHONPATH=$PWD tests/runtests.py
    fi
}

function main() {
    local filtered
    mkdir -p "$DEST"
    if [[ $? -gt 0 ]]; then
	    error 3 "failed to create DEST $DEST"
    fi

    # always cleanup
    rm -Rf "$INSTALL" "$RPMS"
    mkdir -p "$INSTALL"
    if [[ $? -gt 0 ]]; then
	    error 4 "failed to create INSTALL $INSTALL"
    fi

    mkdir -p "$RPMS"
    if [[ $? -gt 0 ]]; then
	    error 5 "failed to create RPMS $RPMS"
    fi

    mkdir -p "$REPOSITORY"
    if [[ $? -gt 0 ]]; then
	    error 6 "failed to create REPOSITORY $REPOSITORY"
    fi

    # give VMs some extra time
    lscpu | grep -qs Hypervisor && sleep 60

    main_init

    if [[ ! -z "$REPO_FILTER" ]]; then
        echo_info "Applying REPO_FILTER $REPO_FILTER to REPOS_MVN_ORDERED $REPOS_MVN_ORDERED"
        for repo in $REPOS_MVN_ORDERED; do
            if [[ "$repo" =~ $REPO_FILTER ]]; then
                echo_info "Skipping filtered repo $repo"
            else
                filtered="$filtered $repo"
            fi
        done
        REPOS_MVN_ORDERED="$filtered"
        echo_info "Filtered REPOS_MVN_ORDERED=$REPOS_MVN_ORDERED"
    fi

    # compile first
    for repo in $REPOS_MVN_ORDERED; do
        prepare_build "$repo"
	    mvn_compile "$repo"
	    if [[ $? -gt 0 ]]; then
	        error 7 "build_and_install compile of repository $repo failed"
	    fi
    done

    # check dependencies
    if [ "$CHECKDEPS" -gt 0 ]; then

        echo_info "Checking dependencies"

        # get the Test::Quattor tools in the PERL5LIB
        pretoolsPERL5LIB="$PERL5LIB"
        for repo in $REPOS_MVN_TESTONLY_ORDERED; do
            prepare_build "$repo"
            mvn_compile "$repo"
        done

        # start with non-fatal to resolve some circular deps
        for repo in $REPOS_MVN_ORDERED $REPOS_MVN_TESTONLY_ORDERED; do
            get_repo_deps "$repo" 0
        done

        # this has to work now
        for repo in $REPOS_MVN_ORDERED $REPOS_MVN_TESTONLY_ORDERED; do
            get_repo_deps "$repo" 1
            if [[ $? -gt 0 ]]; then
                error 9 "check_deps of repository $repo failed"
            fi
        done

        # restore the original PERl5LIb (maven-tools are versioned in the pom.xml)
        export PERL5LIB="$pretoolsPERL5LIB"

    fi

    # The tests require access to core templates
    git_repo template-library-core

    if [[ "$RH_RELEASE" -eq 5 ]]; then
        # CentOS5 cannot have too recent JSON::XS from cpanm
        run_wrapped cpanm "--local-lib=$CPANINSTALL" -f -U JSON::XS
    fi

    # test the maven-tools build scripts repo separately (can't package it)
    for repo in $REPOS_MVN_TESTONLY_ORDERED; do
        mvn_package $repo test
        if [[ $? -gt 0 ]]; then
	        error 8 "build_and_install test of TEST_ONLY repository $repo failed"
        fi
    done

    # with modified PERL5LIB, run the tests
    for repo in $REPOS_MVN_ORDERED $REPOS_MVN_PACKAGEONLY_ORDERED; do
	    mvn_package "$repo" "$PACKAGE"
	    if [[ $? -gt 0 ]]; then
	        error 8 "build_and_install package of repository $repo failed"
	    fi
    done

    test_rpms

    if [[ $AQUILON -gt 0 ]]; then
        build_aquilon_protocols
        build_aquilon
    fi

    if [[ "$EATMYDATA" -gt 0 ]]; then
        unset LD_PRELOAD
        sync
    fi


    return 0
}

main
ec=$?


if [[ $? -gt 0 ]]; then
	msg="FAILED "
else
    msg="SUCCESS"
fi

echo_info "$NAME END $msg DEST $DEST$(date +%s) $(date)"

exit $ec
