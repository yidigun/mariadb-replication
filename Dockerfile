ARG IMG_TAG=latest
FROM docker.io/library/mariadb:$IMG_TAG

ARG IMG_NAME
ARG IMG_TAG

ENV IMG_NAME=$IMG_NAME
ENV IMG_TAG=$IMG_TAG

# 2024-08-26 archive.mariadb.org have a certification problem, so apt can't update database
RUN sed -i -e 's/^deb /deb [trusted=yes] /' /etc/apt/sources.list.d/mariadb.list

RUN apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive \
      apt-get -y install locales tzdata iproute2 net-tools telnet \
                         traceroute iputils-ping lsof psmisc && \
    apt-get clean

COPY bin/* /usr/local/bin/
COPY docker-entrypoint-initdb.d/* /docker-entrypoint-initdb.d/
COPY conf.d/* /etc/mysql/conf.d/
RUN mkdir -p /snapshots && \
    (cd /usr/local/bin; \
      for sh in *.sh; do \
        ln -s $sh `basename $sh .sh`; \
      done)

EXPOSE 3306/tcp
VOLUME /snapshots

ENTRYPOINT [ "/usr/local/bin/repl-entrypoint.sh" ]
CMD [ "run" ]
