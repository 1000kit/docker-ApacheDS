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

#### Check if Server was configured already (restart)
if [ -e /opt/apacheds/CONFIGURED ]; then
	echo "    Server already configured - no configuration started"
	cd /opt/apacheds/bin
	./apacheds.sh ${APACHEDS_INSTANCE} run
	exit 0
fi


#### configure server....

APACHEDS_INSTANCE_DIRECTORY=${APACHEDS_DATA}/instances/${APACHEDS_INSTANCE}
echo ${APACHEDS_INSTANCE_DIRECTORY}

# When a fresh data folder is detected then bootstrap the instance configuration.
if [ ! -d ${APACHEDS_INSTANCE_DIRECTORY} ]; then
    mkdir ${APACHEDS_INSTANCE_DIRECTORY}
    cp -rv ${APACHEDS_BOOTSTRAP}/* ${APACHEDS_INSTANCE_DIRECTORY}
    chown -v -R apacheds:apacheds ${APACHEDS_INSTANCE_DIRECTORY}
fi

# Clean left over pid file
pidFile=${APACHEDS_INSTANCE_DIRECTORY}/run/apacheds-${APACHEDS_INSTANCE}.pid
[[ -e $pidFile ]] && rm $pidFile

gosu root chown apacheds:apacheds /opt/ldif_ext
gosu root chmod 775 /opt/ldif_ext

#### rename example partition with new partition name:
echo "VAR PART  #${DOMAIN_NAME}# #${DOMAIN_SUFFIX}#"
if [ -n "${DOMAIN_NAME}" ] && [ -n "${DOMAIN_SUFFIX}" ]; then

	echo "==> update config.ldif for new domain ..."
	
	UPPER_DN=$(echo "${DOMAIN_NAME}" | tr "[:lower:]" "[:upper:]")
	UPPER_SX=$(echo "${DOMAIN_SUFFIX}" | tr "[:lower:]" "[:upper:]")
	pushd 	${APACHEDS_DATA}/instances/default/conf/
	mv config.ldif config.ldif_ORIG
	cat config.ldif_ORIG  | sed -e "s/dc=example,dc=com/dc=${DOMAIN_NAME},dc=${DOMAIN_SUFFIX}/g" | \
						sed -e "s/example\.com/${DOMAIN_NAME}\.${DOMAIN_SUFFIX}/g" |\
						sed -e "s/example/${DOMAIN_NAME}/g" | \
						sed -e "s/EXAMPLE\.COM/${UPPER_DN}\.${UPPER_SX}/g" > config.ldif
	
	envsubst < /opt/ldif/domain.ldif >> /opt/ldif_ext/00_domain.ldif
	
	popd
	echo "--> done"
	
fi




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

echo "==> import external ldif files from /opt/ldif_ext"
if [ -d /opt/ldif_ext ]; then
	cd /opt/ldif_ext
	gosu root mkdir /opt/ldif_ext/log
	gosu root chown apacheds:apacheds /opt/ldif_ext/log
	for ldifFile in `ls [0-9]*_*.ldif | sort -n`; do
	    echo "==> import $ldifFile"
		ldapmodify -c -a -f /opt/ldif_ext/${ldifFile} -h localhost -p 10389 -D "uid=admin,ou=system" -w ${ADMIN_PASSWORD}  | tee /opt/ldif_ext/log/${ldifFile}.log 2>&1
	done
else
	echo "==> no external ldif dir found in /opt/ldif_ext - skipping "

fi

echo "==> import ready"
#ldapsearch -h localhost -p 10389 -D 'uid=admin,ou=system' -w ${ADMIN_PASSWORD} "dc=${DOMAIN_NAME},dc=${DOMAIN_SUFFIX}";

touch /opt/apacheds/CONFIGURED
cd /opt/apacheds/bin
./apacheds.sh ${APACHEDS_INSTANCE} stop

echo "==> start apache server for use...."
./apacheds.sh ${APACHEDS_INSTANCE} run

#end

