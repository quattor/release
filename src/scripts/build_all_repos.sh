#!/bin/bash

NAME=`basename ${0%.sh}`

function usage () {
    cat <<EOF
$NAME builds packages for all Quattor repos, without any quattor modules 
required in the perl INC path(s).

The script currently assumes that all non-Quattor dependencies for running 
the unittests are present (e.g. panc, mvn, git, the perl test modules, ...).

EOF
    exit 2
}

echo "$NAME START "`date +%s` `date`

# ordered list of repository names
REPOS_MVN_ORDERED="LC CAF CCM ncm-ncd ncm-lib-blockdevices aii configuration-modules-core configuration-modules-grid cdp-listend ncm-cdispd ncm-query"

# base destination directory, base for all other 
DEST=$HOME/quattor_test/$NAME

# pseudo-install dir
INSTALL=$DEST/install
# perl5lib dir in INSTALL
# LC is under lib/perl, remainder under usr/lib/perl?
INSTALLPERL=$INSTALL/lib/perl:$INSTALL/usr/lib/perl

# gather all produced rpms
RPMS=$DEST/rpms

# the original PERL5LIB
ORIGPERL5LIB=$PERL5LIB

# repository dir
REPOSITORY=$DEST/repos

# if set to 1, cleans up more
RELEASE=0

# verbose tests
export QUATTOR_TEST_LOG_CMD_MISSING=1
export QUATTOR_TEST_LOG_CMD=1
PROVEARGS="-Dprove.args=-v"

# Dependencies checking
# set to 0 on non-yum systems
CHECKDEPS=1

# Binary dependencies to be installed with yum                                                                                                        
DEPS_INIT_BIN_YUM="rpmbuild perl panc mvn git"

# the mvn epel url (who has this mirrored/enabled by default?)                                                                                        
EPEL_MVN_REPO=https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo

function error () {
    # at least 2 arguments: exit code, the remainder is message
    ec=$1
    shift
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

function get_cpanm () {
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
                    wget -O $fn "$EPEL_MVN_REPO"
                fi
            else
                curl -o $fn "$EPEL_MVN_REPO"
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

    return 0
}

function check_deps_minimal () {
    for pkg in which rpm yum repoquery; do
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
    pkgs=`repoquery --qf '%{name}' --whatprovides "$dep" | sort| uniq`
    if [ -z "$pkgs" ]; then
        ec=70
        cerror $fatal $ec "No packages found for dep $dep with repoquery"
    fi

    # e.g. quattor unittest repo
    enablerepos=""

    # yum command (e.g. add sudo or something like that)
    yum="yum"

    for pkg in $pkgs; do
        echo "Installing pkg $pkg with yum"
        cmd="$yum install -y $enablerepos $pkg"
        $cmd
        if [ $? -gt 0 ]; then
            ec=71
            cerror $fatal $ec "Failed installation of pkg $pkg with yum : $cmd"
        fi
    done

    return $ec
}

function check_deps_init_bin () {
    echo "Checking DEPS_INIT_BIN_YUM $DEPS_INIT_BIN_YUM"

    # do it separately
    has_mvn

    for bin in $DEPS_INIT_BIN; do
        # these are fatal
        deps_install_yum "*bin/$bin" 1
    done

    # should be part of rpmbuild dep
    deps_install_yum /usr/lib/rpm/find-requires 1

    echo "Done checking DEPS_INIT_BIN $DEPS_INIT_BIN"    
    return 0
}

function get_cpan_dep () {
    perlpkg="$1"
    
    echo "Looking for CPAN perlpkg $perlpkg"
    
    # TODO actually implement this
    CPAN="$CPAN $perlpkg"
}

function get_repo_deps () {
    repo=$1
    
    cd $REPOSITORY

    # look for src subdirs (like AII or components)
    subdirs=`find $repo -type d -name src`

    echo "Found subdirs for repository $repo : $subdirs"
    
    for dir in $subdirs; do
        cd $REPOSITORY
        get_repo_deps_subdir $repo $dir
    done
}

function get_repo_deps_subdir () {
    repo=$1

    # repo + optional subdir
    dir=${2:-$repo}

    # no src or target, just search the whole repo/subdir
    cd $dir

    origIFS="$IFS"
    # newline is th eonly delimiter for IFS
    fakeIFS="
"
    export IFS=$fakeIFS
    deps=`find . -type f | /usr/lib/rpm/find-requires | sort | uniq`

    echo "Deps found for repo $repo: $deps"

    # WARNING dep can have whitespace!
    for dep in $deps; do
        export IFS=$origIFS 
        echo "Checking dependency '$dep'"
        perlpkg=`echo $dep | sed -n "s/^perl(\(.*\))\(.*\(\s[0-9]\+.*\)\)\?$/\1\3/p"`
        if [ -z "$perlpkg" ]; then
            echo "Dependency $dep is not a perl package"
            # is it a full path?
            if [[ "$dep" == /* ]] && [ -f "$dep" ]; then
                echo "Dependency $dep is a absolute filename and exists"
            else
                deps_install_yum "$dep" 1
            fi
        else
            # Test if is usable
            echo "Dependency $dep is a perl package"
            # The unittests run prove with additional paths
            PERL5LIB="$PERL5LIB:src/test/perl:src/test/resources" perl -e "use $perlpkg;" >& /dev/null
            if [ $? -eq 0 ]; then
                echo "Dependency $dep is a usable perl package"                
            else 
                # try to get it with yum
                deps_install_yum "$dep" 0                
                if [ $? -eq 0 ]; then
                    echo "Dependency $dep is a perl package found with yum"                
                else
                    get_cpan_dep "$dep"
                fi
            fi
        fi
        # Is thisone really necessary?
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

    if [ -d ./$repo ]; then
        cd $repo
        git clean -fxd
        cmd="git pull origin master"
        $cmd
        if [ $? -gt 0 ]; then
	        error 22 "$cmd for repository $repo failed"
        fi        
    else
        cmd="git clone https://github.com/quattor/$repo.git"
        $cmd
        if [ $? -gt 0 ]; then
	        error 23 "$cmd failed"
        fi
    fi

    cd $here
    return 0
}

function build_and_install () {
    local repo
    repo=$1
    shift

    mvntgt="$@"

    if [ -z "$repo" ]; then
        error 10 "build_and_install No repository passed as argument"
    fi

    if [ -z "$mvntgt" ]; then
        error 11 "build_and_install No maven target passed as argument"
    fi

    echo "build_and_install maven target $mvntgt repository $repo"

    if [ ! -d $REPOSITORY ]; then
        error 12 "No REPOSITORY directory $REPOSITORY"
    fi

    cd $REPOSITORY
    git_repo $repo

    cd $repo

    # the PERL5LIB path for this repo during testing
    tgtperl="$PWD/target/lib/perl/"

    if [ "$mvntgt" == "package" ]; then
        # remove compile target from PERL5LIB; this repo should be available via INSTALL at the end
        export PERL5LIB=`echo $PERL5LIB | sed "s%$tgtperl:%%"`
        echo "Removed $tgtperl from PERL5LIB for repository $repo after mvn package. New PERL5LIB $PERL5LIB"            
    fi

    # always clean?
    clean=clean
    mvn="mvn $clean $mvntgt $PROVEARGS"
    echo "build_install for repository $repo in $PWD : $mvn"
    $mvn
    if [ $? -gt 0 ]; then
	    error 13 "build_and_install mvn $mvntgt failed for repository $repo (cmd $mvn)"
    fi    

    if [ "$mvntgt" == "compile" ]; then
        # add the target path to PERL5LIB
        PERL5LIB="$tgtperl:$PERL5LIB"
        # INSTALLPERL is always first dir
        PERL5LIB=`echo $PERL5LIB | sed "s%$INSTALLPERL:%%"`
        export PERL5LIB="$INSTALLPERL:$PERL5LIB"
        echo "Added $tgtperl to PERL5LIB for repository $repo after mvn compile : PERL5LIB $PERL5LIB"
    else
        if [ "$mvntgt" == "package" ]; then
            rpms=`find target/ -type f -name \*.rpm`
            if [ -z "$rpms" ]; then
	            error 14 "No rpms found for repository $repo"
            else
	            echo "Rpms $rpms build for repository $repo"
                for rpm in $rpms; do
                    cp $rpm $RPMS
                    echo "Copied rpm $rpm to RPMS $RPMS"
                done
            fi

            tars=`find target/ -type f -name \*.tar.gz`
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
    fi

    return 0
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
    # always cleanup
    mkdir -p $RPMS
    if [ $? -gt 0 ]; then
	    error 5 "failed to create RPMS $RPMS"
    fi

    mkdir -p $REPOSITORY
    if [ $? -gt 0 ]; then
	    error 6 "failed to create REPOSITORY $REPOSITORY"
    fi

    reset_perl5lib

    # compile first
    for repo in $REPOS_MVN_ORDERED; do
	    build_and_install $repo compile
	    if [ $? -gt 0 ]; then
	        error 7 "build_and_install compile of repository $repo failed"
	    fi
    done

    # check dependencies
    if [ $CHECKDEPS -gt 0 ]; then

        echo "Checking dependencies"

        check_deps_minimal
        check_deps_init_bin

        for repo in $REPOS_MVN_ORDERED; do
            get_repo_deps $repo
            if [ $? -gt 0 ]; then
                error 9 "check_deps of repository $repo failed"
            fi
        done

        # TODO needs to be implemented. for now we gather the deps
        if [ ! -z "$CPAN" ]; then
            # fatal for now?
            error 9 "Missing CPAN packages $CPAN"
        fi
    fi

    # with modified PERL5LIB, run the tests
    for repo in $REPOS_MVN_ORDERED; do
	    build_and_install $repo package
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
