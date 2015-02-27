#!/bin/bash

NAME=`basename ${0%.sh}`

# base destination directory, base for all other
DEST=${DEST:-$HOME/quattordev}

# if set to 1, cleans up more e.g. the repositories
RELEASE=${RELEASE:-0}

# Run a git clean on each repo
GITCLEAN=${GITCLEAN:-1}

# Run verbose
VERBOSE=${VERBOSE:-0}

# mvn clean PACKAGE
PACKAGE=${PACKAGE:-package}

MINIMAL_DEPS_PATH="which rpm yum repoquery";

now=`date +%s`
# List with all yum install
YUM_INSTALL_LIST=$DEST/yum_install_list.$now
# Perl with all perl packages (incl version requirements) installed by cpan
PERL_CPAN_PERLPKG_INSTALL_LIST=$DEST/perl_cpan_perlpkg_install_list.$now
# List with all cpanm install
PERL_CPAN_INSTALL_LIST=$DEST/perl_cpan_install_list.$now


function usage () {
    cat <<EOF
$NAME builds packages for all Quattor repos, without any quattor modules
required in the perl INC path(s).

The minimal requirements of this script are $MINIMAL_DEPS_PATH
(expected to be found in PATH).

The script will try to install as much dependencies and requirements
as possible using yum. If run as non-root, it requires sudo rights
to run 'yum' and 'repoquery'.
(It might also add a EPEL maven repo file in /etc/yum.repos.d/ using
curl or wget; so also sudo rights for that are required).
Installed dependencies are logged in timestamped files under $DEST
($YUM_INSTALL_LIST, $PERL_CPAN_PERLPKG_INSTALL_LIST, $PERL_CPAN_INSTALL_LIST).

The Quattor git repositories are cloned and point to remote 'upstream'.
Any uncomiited changes will be stashed before master is updated. (I.e.
don't work in the master branch!)

For missing perl dependencies that can't be installed with yum, CAPN will
be used.

Environment variables:

DEST: DEST sets the basepath (current DEST=$DEST)

CHECKDEPS: CHECKDEPS=0 if you are running this as regular user and all dependencies
are ok (CHECKDEPS=1 will try to run yum) (current CHECKDEPS=$CHECKDEPS).

VERBOSE: VERBOSE=1 enables verbose logging (current VERBOSE=$VERBOSE)

PACKAGE: run 'mvn clean PACKAGE' (use e.g. test or package) (current PACKAGE=$PACKAGE)

Dangerous environment variables:

RELEASE: WARNING if set to 1, it will remove the repositories and some other intrusive cleanup.

GITCLEAN: GITCLEAN=0 if you made local modification to the repositories and want
to test with them (otherwise the repositories will be cleaned)
(current GITCLEAN=$GITCLEAN). [TODO: reinvestigate what this means now that we stash]


EOF
    exit 2
}

echo "$NAME START "`date +%s` `date`

# ordered list of repository names
REPOS_MVN_ORDERED="LC CAF CCM ncm-ncd ncm-lib-blockdevices aii configuration-modules-core configuration-modules-grid cdp-listend ncm-cdispd ncm-query"
REPOS_MVN_TESTONLY_ORDERED="maven-tools"

# pseudo-install dir
INSTALL=$DEST/install
# perl5lib dir in INSTALL
# LC is under lib/perl, remainder under usr/lib/perl?
CPANINSTALL=$INSTALL/usr
INSTALLPERL=$INSTALL/lib/perl:$INSTALL/usr/lib/perl:$CPANINSTALL/lib/perl5

# gather all produced rpms
RPMS=$DEST/rpms

# the original PERL5LIB
ORIGPERL5LIB=$PERL5LIB

# repository dir
REPOSITORY=$DEST/repos

if [ ! -z "$VERBOSE" ]; then
    # verbose tests
    export QUATTOR_TEST_LOG_CMD_MISSING=1
    export QUATTOR_TEST_LOG_CMD=1
    PROVEARGS="-Dprove.args=-v"
fi

# Dependencies checking
# set to 0 on non-yum systems
CHECKDEPS=${CHECKDEPS:-1}

# Main init binaries
MAIN_INIT_BIN_YUM="repoquery git"

# Binary dependencies to be installed with yum
DEPS_INIT_BIN_YUM="rpmbuild perl"

# Use newline separator to allow version statements
DEPS_INIT_YUM="panc >= 10.2
"

# the mvn epel url (who has this mirrored/enabled by default?)
EPEL_MVN_REPO=https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo

function error () {
    # at least 2 arguments: exit code, the remainder is message
    ec=$1
    shift
    echo "export PERL5LIB=$PERL5LIB"
    echo "export PWD=$PWD"
    echo $@
    exit $ec
}

function cerror () {
    # conditional error
    fatal=$1
    shift
    if [ $fatal -gt 0 ]; then
        error $@
    else
        echo $@
    fi
}

ID=`/usr/bin/id -u`
if [ -z "$ID" -o $ID -ne 0 ]; then
    SUDO=sudo
else
    SUDO=''
fi


THEDEPCACHE=""
# Keep bash dependency cache
function add_has_dep () {
    dep="$1"
    add=${2:-0}
    # dep might might contain whitespace
    depname="DEPCACHE `echo $dep | tr '\n' '_'` EHCACPED"
    echo $THEDEPCACHE | grep "$depname" >& /dev/null
    has_dep=$?

    msg="in"
    if [ $has_dep -gt 0 ]; then
        if [ $add -ne 0 ]; then
            THEDEPCACHE="$THEDEPCACHE $depname"
            msg="added to"
        else
            msg="not in"
        fi
    fi

    echo "add_has_dep $dep $msg THEDEPCACHE"

    return $has_dep
}

function get_cpanm () {
    echo "Get and install cpanm"

    # Try to get as much as possible via yum
    deps_install_yum 'perl(App::cpanminus)' 0

    # Some dependencies for build ing perl modules
    for dep in gcc-c++ make; do
        deps_install_yum "$dep"
    done

    which curl >& /dev/null
    if [ $? -gt 0 ]; then
        which wget >& /dev/null
        if [ $? -gt 0 ]; then
            error 30 "get_cpanm no curl or wget found"
        else
            wget -O - http://cpanmin.us | perl - --self-upgrade
        fi
    else
        curl -L http://cpanmin.us | perl - --self-upgrade
    fi

    if [ $? -gt 0 ]; then
        error 31 "fetch and install cpanm failed"
    else
        echo "get_cpanm OK"
    fi

    return 0
}

function has_mvn () {
    mvn="mvn"
    # this one is typically missing from repos etc etc
    which $mvn >& /dev/null
    if [ $? -gt 0 ]; then
        echo "No maven executable $mvn found in PATH"

        deps_install_yum "*bin/mvn" 0
        if [ $? -gt 0 ]; then
            fn=/etc/yum.repos.d/check_deps_mvn.repo
            echo "Couldn't get mvn $mvn via yum. Going to add the mvn epel repo $EPEL_MVN_REPO to $fn and retry."

            which curl >& /dev/null
            if [ $? -gt 0 ]; then
                which wget >& /dev/null
                if [ $? -gt 0 ]; then
                    error 80 "has_mvn no curl or wget found"
                else
                    exe=wget
                    opt=-O
                fi
            else
                exe=curl
                opt=-o
            fi

            $SUDO $exe $opt $fn "$EPEL_MVN_REPO"
            if [ $? -gt 0 ]; then
                error 84 "Failed to download maven repo $EPEL_MVN_REPO to $fn with '$SUDO $exe $opt'"
            fi

            # releasever but repos have single digits/RHEL naming
            major=`cat /etc/redhat-release | sed -n "s/.*release \([0-9]\+\)\..*/\1/p"`
            if [ -z "$major" ]; then
                error 81 "No major release version found via /etc/redhat-release"
            fi
            echo "Going to use releasever $major for this repo"
            sed -i "s/\$releasever/$major/g" $fn

            if [ $? -gt 0 ]; then
                error 82 "has_mvn fetch mvn epel repo $EPEL_MVN_REPO failed"
            fi

            # now it's fatal
            deps_install_yum "*bin/mvn" 1
        fi
    fi

    # Required on EL5
    if [ -f /etc/profile.d/apache-maven.sh ]; then
        . /etc/profile.d/apache-maven.sh
    fi

    return 0
}

function check_deps_minimal () {
    for pkg in $MINIMAL_DEPS_PATH; do
        which $pkg >& /dev/null
        if [ $? -gt 0 ]; then
            error 60 "Failed minimal dependency $pkg"
        fi
    done
}

function deps_install_yum () {
    dep="$1"
    # default fatal
    fatal=${2:-1}

    ec=0

    echo "Searching for dep $dep"
    pkgs=`$SUDO repoquery --qf '%{name}' --whatprovides "$dep" | sort| uniq`
    if [ -z "$pkgs" ]; then
        ec=70
        cerror $fatal $ec "No packages found for dep $dep with repoquery"
    fi

    # e.g. quattor unittest repo
    enablerepos=""

    # yum command (e.g. add sudo or something like that)
    yum="$SUDO yum"

    for pkg in $pkgs; do
        echo "Installing pkg $pkg with yum"
        cmd="$yum install -y $enablerepos $pkg"
        $cmd
        if [ $? -gt 0 ]; then
            ec=71
            cerror $fatal $ec "Failed installation of pkg $pkg with yum : $cmd"
        else
            echo "$pkg" >> $YUM_INSTALL_LIST
            add_has_dep "$dep" 1
        fi
    done

    return $ec
}

function check_deps_init_bin () {
    # these are fatal
    echo "Checking DEPS_INIT_BIN_YUM $DEPS_INIT_BIN_YUM"
    for bin in $DEPS_INIT_BIN_YUM; do
        deps_install_yum "*bin/$bin" 1
    done
    echo "Checking other deps: $DEPS_INIT_YUM"
    for dep in "$DEPS_INIT_YUM"; do
        deps_install_yum "$dep" 1
    done

    # should be part of rpmbuild dep
    for name in find-requires perl.req find-provides perl.prov; do
        deps_install_yum /usr/lib/rpm/$name 1
    done

    echo "Done checking DEPS_INIT_BIN $DEPS_INIT_BIN"
    return 0
}

function get_cpan_dep () {
    perldep="$1"

    fatal=${2:-1}

    perlpkg=`echo $perldep | sed -n "s/^perl(\(.*\))\(.*\(\s[0-9]\+.*\)\)\?$/\1\3/p"`

    # No version info
    perlcpan=`echo $perldep | sed -n "s/^perl(\(.*\))\(.*\(\s[0-9]\+.*\)\)\?$/\1/p"`

    echo "Looking for CPAN perlcpan $perlcpan for dependency $perldep"

    cpanm --local-lib=$CPANINSTALL $perlcpan

    if [ $? -eq 0 ]; then
        echo "Perl dependency $perldep installed via CPAN"
        perl -e "use $perlpkg;"
        if [ $? -eq 0 ]; then
            echo "Dependency $dep is a usable perl package"
            echo "$perlpkg" >> $PERL_CPAN_PERLPKG_INSTALL_LIST
            echo "$perlcpan" >> $PERL_CPAN_INSTALL_LIST
            add_has_dep "$perldep" 1
        else
            ec=91
            cerror $fatal $ec "Dependency $dep installed via CPAN (perlcpan $perlcpan) but not usabele (perlpkg $perlpkg)"
        fi
    else
        ec=90
        cerror $fatal $ec "Perl dependency $perldep installed via CPAN failed"
    fi

}

function get_repo_deps () {
    repo=$1
    fatal=${2:-1}

    cd $REPOSITORY

    # look for src subdirs (like AII or components)
    subdirs=`find $repo -type d -name src`

    echo "Found subdirs for repository $repo : $subdirs"

    for dir in $subdirs; do
        cd $REPOSITORY
        # use dirname to scan both src/ and target/
        get_repo_deps_subdir $repo `dirname $dir` $fatal
    done
}

function get_repo_deps_subdir () {
    repo=$1

    # repo + optional subdir
    dir=${2:-$repo}

    fatal=${3:-1}

    cd $dir

    origIFS="$IFS"
    # newline is the only delimiter for IFS
    fakeIFS="
"
    export IFS=$fakeIFS

    # only search src and target (there's some legacy code in other dirs)
    # TT have 'use X', which perl.req things are perl modules
    found=`find {src,target} -type f  ! -regex '.*\.tt'`

    # find-requires doesn't cover perl .t files
    deps=`(echo "$found" | /usr/lib/rpm/perl.req ; echo "$found" | /usr/lib/rpm/find-requires) | sort | uniq | grep -E '\w'`
    echo "Dependencies found for repo $repo (dir $dir): $deps"

    # this is what the current repository provides. they are not to be searched externally
    provs=`(echo "$found" | /usr/lib/rpm/perl.prov ; echo "$found" | /usr/lib/rpm/find-provides) |sort | uniq | grep -E '\w'`
    echo "Provides found for repo $repo (dir $dir): $provs"

    # WARNING dep can have whitespace!
    for dep in $deps; do
        echo "Checking dependency '$dep'"
        export IFS=$origIFS

        add_has_dep "$dep"
        if [ $? -ne 0 ]; then
            echo $provs |grep "$dep" >& /dev/null
            if [ $? -eq 0 ]; then
                echo "Dependency $dep is provided by this repository"
            else
                perlpkg=`echo $dep | sed -n "s/^perl(\(.*\))\(.*\(\s[0-9]\+.*\)\)\?$/\1\3/p"`
                if [ -z "$perlpkg" ]; then
                    echo "Dependency $dep is not a perl package"
                    # is it a full path?
                    if [[ "$dep" == /* ]] && [ -f "$dep" ]; then
                        echo "Dependency $dep is a absolute filename and exists"
                        add_has_dep "$dep" 1
                    else
                        deps_install_yum "$dep" $fatal
                    fi
                else
                    # Test if the perl module is usable
                    echo "Dependency $dep is a perl package"
                    # The unittests run prove with additional paths
                    PERL5LIB="$PERL5LIB:src/test/perl:src/test/resources:target/lib/perl" perl -e "use $perlpkg;"
                    if [ $? -eq 0 ]; then
                        echo "Dependency $dep is a usable perl package"
                        add_has_dep "$dep" 1
                    else
                        # try to get it with yum
                        deps_install_yum "$dep" 0
                        if [ $? -eq 0 ]; then
                            echo "Dependency $dep is a perl package found with yum"
                        else
                            get_cpan_dep "$dep" $fatal
                        fi
                    fi
                fi
            fi
        fi
        export IFS=$fakeIFS
    done
    export IFS=$origIFS
}

function reset_perl5lib () {

    unset PERL5LIB

    # add the /_nodir for easy parsing (now all real paths are followed with a :)
    if [ -z "$ORIGPERL5LIB" ]; then
        PERL5LIB="$INSTALLPERL:/_nodir"
    else
        PERL5LIB="$INSTALLPERL:$ORIGPERL5LIB:/_nodir"
    fi

    echo "reset_perl5lib PERL5LIB $PERL5LIB"
    export PERL5LIB
}

function git_repo () {
    local repo
    repo=$1

    here=$PWD

    if [ -z "$repo" ]; then
        error 20 "No repository passed as argument"
    else
        echo "git_repo for repository $repo"
    fi

    if [ ! -d $REPOSITORY ]; then
        error 21 "No REPOSITORY directory $REPOSITORY"
    fi
    cd $REPOSITORY

    if [ $RELEASE -gt 0 ]; then
        echo "RELEASE Revoming repository"
        rm -Rf ./$repo
    fi

    if [ ! -d ./$repo ]; then
        cmd="git clone https://github.com/quattor/$repo.git"
        $cmd
        if [ $? -gt 0 ]; then
	        error 23 "$cmd failed"
        fi

        cd $repo
        git remote rename origin upstream
        if [ $? -gt 0 ]; then
	        error 24 "failed to rename origin to upstream"
        fi

        cd $REPOSITORY
    fi

    cd $repo

    # stash any local changes
    git stash

    # maven-tools clone doesn't start in master?
    git checkout master

    if [ $GITCLEAN -gt 0 ]; then
        echo "git clean"
        git clean -fxd
    else
        echo "git clean disabled"
    fi

    cmd="git pull upstream master"
    $cmd
    if [ $? -gt 0 ]; then
        error 22 "$cmd for repository $repo failed"
    fi

    cd $here
    return 0
}

function prepare_build () {
    local repo
    repo=$1

    if [ -z "$repo" ]; then
        error 10 "prepare_build No repository passed as argument"
    else
        echo "prepare_build repository $repo"
    fi

    if [ ! -d $REPOSITORY ]; then
        error 12 "No REPOSITORY directory $REPOSITORY"
    fi

    cd $REPOSITORY
    git_repo $repo

    return 0
}

function mvn_compile () {
    local repo
    repo=$1
    shift

    cd $REPOSITORY/$repo

    mvntgt="compile"

    # the PERL5LIB path for this repo during testing
    if [ "$repo" == "maven-tools" ]; then
        echo "Exception for maven-tools repository: entering subdir build-scripts and using non-target tgtperl"
        cd build-scripts
        tgtperl="$PWD/src/main/perl/"
    else
        tgtperl="$PWD/target/lib/perl/"
    fi

    # always clean?
    clean=clean
    mvn="mvn $clean $mvntgt $PROVEARGS"
    echo "mvn_compile for repository $repo in $PWD : $mvn"
    $mvn
    if [ $? -gt 0 ]; then
        error 13 "mvn_compile mvn $mvntgt failed for repository $repo (cmd $mvn)"
    fi

    # add the target path to PERL5LIB
    PERL5LIB="$tgtperl:$PERL5LIB"
    # INSTALLPERL is always first dir
    PERL5LIB=`echo $PERL5LIB | sed "s%$INSTALLPERL:%%"`
    export PERL5LIB="$INSTALLPERL:$PERL5LIB"
    echo "Added $tgtperl to PERL5LIB for repository $repo after mvn compile : PERL5LIB $PERL5LIB"

    return 0
}

function mvn_package () {
    local repo
    repo=$1
    mvntgt=${2:-$PACAKGE}

    cd $REPOSITORY/$repo

    if [ "$repo" == "maven-tools" ]; then
        echo "Exception for maven-tools repository: entering subdir build-scripts and using non-target tgtperl"
        cd build-scripts
        tgtperl="$PWD/src/main/perl/"
    else
        tgtperl="$PWD/target/lib/perl/"
    fi

    # remove compile target from PERL5LIB; this repo should be available via INSTALL at the end
    export PERL5LIB=`echo $PERL5LIB | sed "s%$tgtperl:%%"`
    echo "Removed $tgtperl from PERL5LIB for repository $repo after mvn $PACKAGE. New PERL5LIB $PERL5LIB"

    # always clean?
    clean=clean
    mvn="mvn $clean $mvntgt $PROVEARGS"
    echo "mvn_package for repository $repo in $PWD : $mvn"
    $mvn
    if [ $? -gt 0 ]; then
        error 13 "mvn_package mvn $mvntgt failed for repository $repo (cmd $mvn)"
    fi

    if [ $mvntgt == "package" ]; then
        echo "Looking for rpm in {target,*/target} in $PWD"
        rpms=`find {target,*/target} -type f -name \*.rpm`
        if [ -z "$rpms" ]; then
            error 14 "No rpms found for repository $repo"
        else
            echo "Rpms $rpms build for repository $repo"
            for rpm in $rpms; do
                cp $rpm $RPMS
                echo "Copied rpm $rpm to RPMS $RPMS"
            done
        fi

        echo "Looking for tar.gz in {target,*/target} in $PWD"
        tars=`find {target,*/target} -type f -name \*.tar.gz`
        if [ -z "$tars" ]; then
            error 15 "No tar.gz found for repository $repo"
        else
            echo "Found tars $tars"
            for tgz in $tars; do
                tar -C $INSTALL -xvzf $tgz
                if [ $? -gt 0 ]; then
                    error 16 "Failed to unpack tarball for repository $repo in INSTALL $INSTALL"
                else
                    echo "unpacked tarball $tgz for repository $repo in INSTALL $INSTALL"
                fi
            done
        fi
    fi

    return 0
}

function main_init () {
    reset_perl5lib

    $SUDO yum clean all

    # provided by yum-utils
    echo "Checking MAIN_INIT_BIN_YUM $MAIN_INIT_BIN_YUM"
    for bin in $MAIN_INIT_BIN_YUM; do
        binpath="/usr/bin/$bin"
        if [ ! -f $binpath ]; then
            cmd="$SUDO yum install -y $binpath"
            if [ $? -gt 0 ]; then
                error 19 "Failed to install $bin as part of MAIN_INIT_BIN_YUM $MAIN_INIT_BIN_YUM"
            else
                echo "Installed $bin with $cmd"
            fi
        fi
    done

    # do it separately
    has_mvn
}

function main() {
    mkdir -p $DEST
    if [ $? -gt 0 ]; then
	    error 3 "failed to create DEST $DEST"
    fi

    # always cleanup
    rm -Rf $INSTALL $RPMS
    mkdir -p $INSTALL
    if [ $? -gt 0 ]; then
	    error 4 "failed to create INSTALL $INSTALL"
    fi

    mkdir -p $RPMS
    if [ $? -gt 0 ]; then
	    error 5 "failed to create RPMS $RPMS"
    fi

    mkdir -p $REPOSITORY
    if [ $? -gt 0 ]; then
	    error 6 "failed to create REPOSITORY $REPOSITORY"
    fi

    main_init

    # compile first
    for repo in $REPOS_MVN_ORDERED; do
        prepare_build $repo
	    mvn_compile $repo
	    if [ $? -gt 0 ]; then
	        error 7 "build_and_install compile of repository $repo failed"
	    fi
    done

    # check dependencies
    if [ $CHECKDEPS -gt 0 ]; then

        echo "Checking dependencies"

        # slowish
        get_cpanm

        check_deps_minimal
        check_deps_init_bin

        # get the Test::Quattor tools in the PERL5LIB
        pretoolsPERL5LIB=$PERL5LIB
        for repo in $REPOS_MVN_TESTONLY_ORDERED; do
            prepare_build $repo
            mvn_compile $repo
        done

        # start with non-fatal to resolve some circular deps
        for repo in $REPOS_MVN_ORDERED $REPOS_MVN_TESTONLY_ORDERED; do
            get_repo_deps $repo 0
        done

        # this has to work now
        for repo in $REPOS_MVN_ORDERED $REPOS_MVN_TESTONLY_ORDERED; do
            get_repo_deps $repo 1
            if [ $? -gt 0 ]; then
                error 9 "check_deps of repository $repo failed"
            fi
        done

        # restore the original PERl5LIb (maven-tools are versioned in the pom.xml)
        export PERL5LIB=$pretoolsPERL5LIB

    fi

    # The tests require access to core templates
    git_repo template-library-core
    # a checkout in the same base directory is default (but lets set this anyway)
    export QUATTOR_TEST_TEMPLATE_LIBRARY_CORE=$REPOSITORY/template-library-core

    # test the maven-tools build scripts repo separately (can't package it)
    for repo in $REPOS_MVN_TESTONLY_ORDERED; do
        mvn_package $repo test
        if [ $? -gt 0 ]; then
	        error 8 "build_and_install test of TEST_ONLY repository $repo failed"
        fi
    done

    # with modified PERL5LIB, run the tests
    for repo in $REPOS_MVN_ORDERED; do
	    mvn_package $repo $PACKAGE
	    if [ $? -gt 0 ]; then
	        error 8 "build_and_install package of repository $repo failed"
	    fi
    done

    return 0
}

main
ec=$?


if [ $? -gt 0 ]; then
	msg="FAILED "
else
    msg="SUCCESS"
fi

echo "$NAME END $msg DEST $DEST"`date +%s` `date`

exit $ec
