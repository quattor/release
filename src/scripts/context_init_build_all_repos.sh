#!/bin/bash

# user to run everything under
USER="quattor"

# initial sleep (some OSes need some extra time)
SLEEP=30

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

if [ -f "/tmp/sudoers.lock" ]; then
    exit 1
fi
touch /tmp/sudores.lock
visudo -c -f $TMPSUDOERS
if [ "$?" -eq "0" ]; then
    cp $TMPSUDOERS /etc/sudoers
fi
rm /tmp/sudores.lock

if [ -f "/mnt/$SCRIPT" ]; then
    cp /mnt/$SCRIPT /tmp
    chmod +x /tmp/$SCRIPT
    # background the tests, allows to start other services like sshd in parallel in non-systemd
    su - $USER -c "sleep $SLEEP ; /tmp/build_all_repos.sh >& /tmp/${SCRIPT}.$$.out" &
fi

