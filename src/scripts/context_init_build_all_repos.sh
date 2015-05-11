#!/bin/bash

USER="quattor"

adduser $USER

TMPSUDOERS="/tmp/sudoers.${RANDOM}.tmp"

cp /etc/sudoers $TMPSUDOERS

sed -e '/Defaults    requiretty/ s/^#*/#/' -i $TMPSUDOERS

cat >> $TMPSUDOERS <<EOF
$USER		ALL= (ALL)	NOPASSWD:	/usr/bin/yum
$USER		ALL= (ALL)	NOPASSWD:	/usr/bin/repoquery
$USER             ALL= (ALL)      NOPASSWD:       /usr/bin/curl
$USER             ALL= (ALL)      NOPASSWD:       /usr/bin/wget
$USER             ALL= (ALL)      NOPASSWD:       /usr/bin/sed
$USER             ALL= (ALL)      NOPASSWD:       /bin/sed

#$USER		ALL= (ALL)	NOPASSWD:	/usr/bin/cp
#$USER             ALL= (ALL)      NOPASSWD:       /bin/cp

EOF

sudoerslock=/tmp/sudoers.lock

if [ -f $sudoerslock ]; then
    exit 1
fi

# not really a lock, but enough for now
touch $sudoerslock

visudo -c -f $TMPSUDOERS
if [ "$?" -eq "0" ]; then
    cp $TMPSUDOERS /etc/sudoers
fi
rm $sudoerslock

if [ -f "/mnt/$SCRIPT" ]; then
    cp /mnt/$SCRIPT /tmp
    chmod +x /tmp/$SCRIPT
    su $USER /tmp/build_all_repos.sh >& /tmp/${SCRIPT}.$$.out
fi

