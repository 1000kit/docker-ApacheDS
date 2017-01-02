#!/bin/bash

# Environment variables:
# APACHEDS_INSTANCE
# APACHEDS_BOOTSTRAP
# APACHEDS_DATA
function wait_for_ldap {
	lpwd=$1
	echo "Waiting for LDAP to be available "
	c=0

	ldapsearch -h localhost -p 10389 -D 'uid=admin,ou=system' -w ${lpwd} ou=system;
    
    while [ $? -ne 0 ]; do
        echo "LDAP not up yet... retrying... ($c/20)"
        sleep 4
 		
 		if [ $c -eq 20 ]; then
 			echo "TROUBLE!!! After [${c}] retries LDAP is still dead :("
 			exit 2
 		fi
 		c=$((c+1))
    	
    	ldapsearch -h localhost -p 10389 -D 'uid=admin,ou=system' -w ${lpwd} ou=system;
    done 
}

APACHEDS_INSTANCE_DIRECTORY=${APACHEDS_DATA}/instances/${APACHEDS_INSTANCE}

# When a fresh data folder is detected then bootstrap the instance configuration.
if [ ! -d ${APACHEDS_INSTANCE_DIRECTORY} ]; then
    mkdir ${APACHEDS_INSTANCE_DIRECTORY}
    cp -rv ${APACHEDS_BOOTSTRAP}/* ${APACHEDS_INSTANCE_DIRECTORY}
    chown -v -R apacheds:apacheds ${APACHEDS_INSTANCE_DIRECTORY}
fi

# Clean left over pid file
pidFile=${APACHEDS_INSTANCE_DIRECTORY}/run/apacheds-${APACHEDS_INSTANCE}.pid
[[ -e $pidFile ]] && rm $pidFile

# Execute the server in console mode and not as a daemon.
echo "==> start apacheds"
cd /opt/apacheds/bin
./apacheds.sh ${APACHEDS_INSTANCE} start

wait_for_ldap "secret"
echo "    started"


## now configure server
if [ -n "${ADMIN_PASSWORD}" ]; then
	echo "==> set password"
	envsubst < "/opt/ldif/admin_password.ldif" > "/tmp/admin_password.ldif"
	ldapmodify -c -a -f /tmp/admin_password.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w secret	
else
	export ADMIN_PASSWORD='secret'	
fi

echo "==>password done"
echo "VAR PART  #${DOMAIN_NAME}# #${DOMAIN_SUFFIX}#"
if [ -n "${DOMAIN_NAME}" ] && [ -n "${DOMAIN_SUFFIX}" ]; then
	echo "==> create partition  ${DOMAIN_NAME} ${DOMAIN_SUFFIX}"
	envsubst < "/opt/ldif//partition.ldif" > "/tmp/partition.ldif"
	ldapmodify -c -a -f /tmp/partition.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}
	ldapdelete "ads-partitionId=example,ou=partitions,ads-directoryServiceId=default,ou=config" -r -p 10389 -h localhost -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}
	ldapdelete "dc=example,dc=com" -p 10389 -h localhost -D "uid=admin,ou=system" -r -w ${ADMIN_PASSWORD}
	cd /opt/apacheds/bin
	echo "==>RESTART ApacheDS"
	./apacheds.sh ${APACHEDS_INSTANCE} stop
	./apacheds.sh ${APACHEDS_INSTANCE} start
	wait_for_ldap "${ADMIN_PASSWORD}"
	echo "    started"
fi

echo "==> import external ldif files from /opt/ldif_ext"
if [ -d /opt/ldif_ext ]; then
	cd /opt/ldif_ext
	for ldifFile in `ls [0-9]*_*.ldif | sort -n`; do
	    echo "==> import $ldifFile"
		ldapmodify -c -a -f /opt/ldif_ext/${ldifFile} -h localhost -p 10389 -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}  | tee /opt/ldif_ext/${ldifFile}.log >&2
	done
else
	echo "==> no external ldif dir found in /opt/ldif_ext - skipping "

fi

echo "==> import ready"
ldapsearch -h localhost -p 10389 -D 'uid=admin,ou=system' -w secret "dc=${DOMAIN_NAME},dc=${DOMAIN_SUFFIX}";

echo "==> READY FOR USE NOW ...." 
# simple wait
tail -f /dev/null

#end

