FROM 1000kit/base-jdk

MAINTAINER 1000kit <docker@1000kit.org>


LABEL Vendor="1000kit"
LABEL License="GPLv3"
LABEL Version="1.0.0"

ENV APACHEDS_VERSION="2.0.0-M23"

ENV APACHEDS_DATA="/opt/apacheds/"

ENV APACHEDS_INSTANCE="default"
ENV APACHEDS_BOOTSTRAP="/opt/bootstrap"

# install User
USER root

ADD install/run.sh /opt/run.sh 


RUN groupadd -r apacheds \
 	&& useradd -r -g apacheds -m -d /home/apacheds -s /bin/bash -c "apacheds user" apacheds \
 	&& chmod -R 755 /home/apacheds \
 	&& echo 'apacheds ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers \

    && curl -L http://www.eu.apache.org/dist//directory/apacheds/dist/${APACHEDS_VERSION}/apacheds-${APACHEDS_VERSION}.zip -o /tmp/apacheds-${APACHEDS_VERSION}.zip \
	&& cd /opt \
	&& unzip -q /tmp/apacheds-${APACHEDS_VERSION}.zip \
	&& ln -sf apacheds-${APACHEDS_VERSION} apacheds \
	&& chown -R apacheds:apacheds /opt/apacheds-${APACHEDS_VERSION} /opt/run.sh \
	&& chmod ug+rwx /opt/run.sh /opt/apacheds/bin/* \
	&& rm -rf /tmp/apacheds-${APACHEDS_VERSION}.zip \
	&& mkdir -p ${APACHEDS_BOOTSTRAP}/conf/
	 
ADD instance/* ${APACHEDS_BOOTSTRAP}/conf/

RUN    mkdir ${APACHEDS_BOOTSTRAP}/cache \
    && mkdir ${APACHEDS_BOOTSTRAP}/run \
    && mkdir ${APACHEDS_BOOTSTRAP}/log \
    && mkdir ${APACHEDS_BOOTSTRAP}/partitions \
    && chown -R apacheds:apacheds ${APACHEDS_BOOTSTRAP}
    
    
    
# Switch back apacheds user
USER apacheds
WORKDIR /opt/apacheds

#############################################
# ApacheDS wrapper command
#############################################
CMD ["/run.sh"]

####END
