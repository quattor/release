#!/bin/bash 

release_dir_root=/var/www/yum-quattor
nexus_dir=/var/lib/sonatype-work/nexus/storage/quattor-releases/

usage () {
  echo ""
  echo "Usage: $(basename $0) [--list|--force] [--release-pattern pattern] release_number"
  exit 1
}

list_release_rpms=0
force=0
release_pattern=''

while [ -n "`echo $1 | grep '^--'`" ]
do
  case $1 in
  --force)
        force=1
        ;;

  --list)
        list_release_rpms=1
        ;;

  --release-pattern)
        shift
        release_pattern=$1
        ;;

  esac

  shift
done

if [ -z "$1" ]
then
  if [ ${list_release_rpms} -eq 0 -o -z "${release_pattern}" ]
  then
    echo "Error: no release specified"
    usage
  fi
fi

release=$1
release_dir=${release_dir_root}/${release}

if [ -z "${release_pattern}" ]
then
  release_pattern=${release}
fi

if [ ${list_release_rpms} -eq 0 ]
then
  if [ -d ${release_dir} -a ${force} -eq 0 ]
  then
    echo "Error: release already exists. Use --force to proceed anyway."
    exit 2
  else
    mkdir -p ${release_dir}
    cd ${release_dir}
  fi
fi

release_rpms=$(find ${nexus_dir} -name "*${release_pattern}-rpm\.rpm")

if [ ${list_release_rpms} -eq 1 ]
then
  echo "===== List of RPMs in release ${release} ====="
  echo
fi 

for filename in ${release_rpms}
do
  pkgname=`rpm -qp --qf "%{N}-%{V}-%{R}.%{ARCH}.rpm" ${filename}`
  if [ ${list_release_rpms} -eq 1 ]
  then
    echo ${pkgname}
  else
    cp ${filename} ${pkgname}
  fi
done

if [ ${list_release_rpms} -eq 0 ]
then
  createrepo .
fi 



