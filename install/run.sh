#!/bin/bash

# Environment variables:
# APACHEDS_INSTANCE
# APACHEDS_BOOTSTRAP
# APACHEDS_DATA


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
cd /opt/apacheds/bin
./apacheds.sh ${APACHEDS_INSTANCE} start
sleep 10
#exec

## now configure server

if [ -n "${ADMIN_PASSWORD}" ]; then
	echo "set password"
	envsubst < "/opt/ldif/admin_password.ldif" > "/tmp/admin_password.ldif"
	ldapmodify -c -a -f /tmp/admin_password.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w secret	
else
	export ADMIN_PASSWORD='secret'	
fi
echo "password done"
echo "VAR PART  #${DOMAIN_NAME}# #${DOMAIN_SUFFIX}#"
if [ -n "${DOMAIN_NAME}" ] && [ -n "${DOMAIN_SUFFIX}" ]; then
	echo "create partition  ${DOMAIN_NAME} ${DOMAIN_SUFFIX}"
	envsubst < "/opt/ldif//partition.ldif" > "/tmp/partition.ldif"
	ldapmodify -c -a -f /tmp/partition.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}
	ldapdelete "ads-partitionId=example,ou=partitions,ads-directoryServiceId=default,ou=config" -r -p 10389 -h localhost -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}
	ldapdelete "dc=example,dc=com" -p 10389 -h localhost -D "uid=admin,ou=system" -r -w ${ADMIN_PASSWORD}
	cd /opt/apacheds/bin
	./apacheds.sh ${APACHEDS_INSTANCE} stop
	./apacheds.sh ${APACHEDS_INSTANCE} start
	sleep 10
fi
ls -la  /opt/ldif/
if [ -e /opt/ldif/structure.ldif ]; then
	echo "import structure"
	ldapmodify -c -a -f /opt/ldif/structure.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}
fi

if [ -e /opt/ldif/schema.ldif ]; then
	echo "import schema"
	ldapmodify -c -a -f /opt/ldif/schema.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}
fi

if [ -e /opt/ldif/users.ldif ]; then
	echo "import users"
	ldapmodify -c -a -f /opt/ldif/users.ldif -h localhost -p 10389 -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}
fi
#end