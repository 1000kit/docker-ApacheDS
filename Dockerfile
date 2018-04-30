FROM 1000kit/base-jdk

MAINTAINER 1000kit <docker@1000kit.org>


LABEL org.1000kit.vendor="1000kit" \
      org.1000kit.license="GPLv3" \
      org.1000kit.version="1.0.0"

ENV APACHEDS_VERSION="2.0.0-M23" \
    APACHEDS_DATA="/opt/apacheds/" \
    APACHEDS_INSTANCE="default" \
    APACHEDS_BOOTSTRAP="/opt/bootstrap"

# install User
USER root

ADD install/run.sh /opt/run.sh 
ADD install/ldif /opt/ldif

RUN yum -y install openldap-clients gettext \
    && yum clean all \

    && groupadd -r apacheds \
 	&& useradd -l -r -g apacheds -m -d /home/apacheds -s /bin/bash -c "apacheds user" apacheds \
 	&& chmod -R 755 /home/apacheds \
 	&& echo 'apacheds ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \

    && curl -L http://archive.apache.org/dist/directory/apacheds/dist/${APACHEDS_VERSION}/apacheds-${APACHEDS_VERSION}.zip -o /tmp/apacheds-${APACHEDS_VERSION}.zip \
	&& cd /opt \
	&& unzip -q /tmp/apacheds-${APACHEDS_VERSION}.zip \
	&& ln -sf apacheds-${APACHEDS_VERSION} apacheds \
	&& chown -R apacheds:apacheds /opt/apacheds-${APACHEDS_VERSION} /opt/run.sh /opt/ldif \
	&& chmod ug+rwx /opt/run.sh /opt/apacheds/bin/* \
	&& rm -rf /tmp/apacheds-${APACHEDS_VERSION}.zip
	 


RUN    mkdir -p ${APACHEDS_BOOTSTRAP}/cache \
    && mkdir -p ${APACHEDS_BOOTSTRAP}/run \
    && mkdir -p ${APACHEDS_BOOTSTRAP}/conf \
    && mkdir -p ${APACHEDS_BOOTSTRAP}/log \
    && mkdir -p ${APACHEDS_BOOTSTRAP}/partitions \
    && cp ${APACHEDS_DATA}/instances/default/conf/*  ${APACHEDS_BOOTSTRAP}/conf \
    && mkdir -p /opt/ldif_ext \
    && chown -R apacheds:apacheds ${APACHEDS_BOOTSTRAP}

#ADD instance/* ${APACHEDS_BOOTSTRAP}/conf/

# Switch back apacheds user
USER apacheds
WORKDIR ${APACHEDS_DATA}

VOLUME /opt/ldif_ext

#############################################
# ApacheDS wrapper command
#############################################
CMD ["/opt/run.sh"]

####END
