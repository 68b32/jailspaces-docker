#!/bin/bash

BASEDIR="$1"

if [ -d "${BASEDIR}/user" -a -d "${BASEDIR}/conf/nginx/conf.d" -a -d "${BASEDIR}/conf/php5/fpm/pool.d" ]; then
	# Create system user from configuration
	(ls -1d "${BASEDIR}/user/"* | cut -d'/' -f4; \
	ls -1 "${BASEDIR}/conf/nginx/conf.d/" | cut -d. -f1; \
	ls -1 "${BASEDIR}/conf/php5/fpm/pool.d/" | cut -d. -f1) 2> /dev/null | sort | uniq -d | while read username; do
		echo -n "User $username: "
		if id "$username" &> /dev/null; then
			echo "Exists"
		else
			uid="`stat -c %u \"${BASEDIR}/user/${username}\"`"
			gid="`stat -c %g \"${BASEDIR}/user/${username}\"`"
			groupadd -g "$gid" "$username"
			useradd -b "${BASEDIR}/user" -M -G webspaceuser -g "$gid" -u "$uid" "$username"
			usermod -a -G "${username}" nginx
			echo "Created [UID: $uid, GID: $gid]"
		fi
	done;
	echo "Groups of NGINX:"
	groups nginx
else
	# Move configuration to data directory
	mkdir -p "$BASEDIR/conf"
	for d in nginx php5 jailspaces; do
		mv "/etc/${d}" "${BASEDIR}/conf/${d}"
	done;
fi

# Link configuration
for d in nginx php5 jailspaces; do
	rm -rf "/etc/${d}"
	ln -s "${BASEDIR}/conf/${d}" "/etc/${d}"
done;

# Check for user directory
! [ -d "${BASEDIR}/user" ] && mkdir "${BASEDIR}/user"

# Check for cert directory
! [ -d "${BASEDIR}/cert" ] && mkdir "${BASEDIR}/cert" && chown cert:cert "${BASEDIR}/cert"

# Check for log directory
! [ -d "${BASEDIR}/log" ] && mkdir -p "${BASEDIR}/log/nginx" "${BASEDIR}/log/php5-fpm"
! [ -f "${BASEDIR}/log/CertWatch.log" ] && touch "${BASEDIR}/log/CertWatch.log" && chown cert:cert "${BASEDIR}/log/CertWatch.log"

# Generate keys and setup environment if not in place
js tls init

# Place CertWatch config
if [ ! -d "${BASEDIR}/cert/.certconf" ]; then
	cp -r /root/init/certconf "${BASEDIR}/cert/.certconf"
	chown -R cert:cert "${BASEDIR}/cert/.certconf"
fi

# Start the services
service php5-fpm restart
service nginx restart

# Setup chroots and refresh certificates
js list | while read webspace; do
	echo
	echo "###"
	echo "# Setup JailSpace $webspace"
	echo "##"
	echo
	js binds bind "$webspace"
	js tls refresh "$webspace" -n
done;

service nginx restart
service cron start
# Launch shell
/bin/bash
