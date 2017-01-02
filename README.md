# ApacheDS docker image

This Docker image provides an [ApacheDS](https://directory.apache.org/apacheds/) LDAP server.
The project sources can be found on [GitHub](https://github.com/1000kit/docker-ApacheDS).

#Build
 use build.sh
 
#run
The container can be started issuing the following command:

~~~~
$ docker run --name ldap -d -p 389:10389 1000kit/apacheds
~~~~
    
alternative run docker-compose:
~~~~
$ docker-compose up
~~~~

#Customization 

Start your own defined Apache DS *instance* with your own configuration for *partitions* and *services*.  You need to mount your [config.ldif](https://github.com/g17/ApacheDS/blob/master/instance/config.ldif) file and set the *APACHEDS_INSTANCE* environment variable properly.

~~~~
$ docker run --name ldap -d -p 10389:10389 -e APACHEDS_INSTANCE=<INSTANCE_NAME> -v /path/to/your/config.ldif:/opt/bootstrap/conf/config.ldif:ro 1000kit/apacheds
~~~~
  
###Variables:
Configuration of own admin password
* ADMIN_PASSWORD=secret
Configuration for new partition which will be created on startup.
* DOMAIN_NAME=1000kit
* DOMAIN_SUFFIX=de  

### Volumes:
add volume /opt/ldif_exit to import ldif file on startup. Files will be included in schema `[0-9][0-9]*.ldif` , e.g.:
* 10_structure.ldif
* 20_schema.ldif
* 30_users.ldif



  

    