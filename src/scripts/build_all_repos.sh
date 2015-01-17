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

function error () {
    # at least 2 arguments: exit code, the remainder is message
    ec=$1
    shift
    echo $@
    exit $ec
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
