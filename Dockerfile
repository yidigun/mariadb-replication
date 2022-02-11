ARG IMG_NAME
ARG IMG_TAG
ARG LANG=ko_KR.UTF-8
ARG TZ=Asia/Seoul

FROM docker.io/library/mariadb:$IMG_TAG

ENV IMG_NAME=$IMG_NAME
ENV IMG_TAG=$IMG_TAG
ENV LANG=$LANG
ENV TZ=$TZ

RUN apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive \
      apt-get -y install locales tzdata iproute2 net-tools telnet \
                         traceroute iputils-ping lsof psmisc && \
    if [ -n "$LANG" ]; then \
          eval `echo $LANG | \
            sed -E -e 's/([a-z]+_[a-z]+)\.([a-z0-9_-]+)/localedef -cf\2 -i\1 \1.\2/i'`; \
    fi; \
    if [ -n "$TZ" -a -f /usr/share/zoneinfo/$TZ ]; then \
          ln -sf /usr/share/zoneinfo/$TZ /etc/localtime; \
    fi; \
    apt-get clean

COPY bin/* /usr/local/bin/
COPY docker-entrypoint-initdb.d/* /docker-entrypoint-initdb.d/
COPY conf.d/* /etc/mysql/conf.d/
RUN mkdir -p /snapshots && \
    (cd /usr/local/bin; \
      for sh in *.sh; do
        ln -s $sh `basename $sh .sh`; \
      done)

EXPOSE 3306/tcp
VOLUME /snapshots

ENTRYPOINT [ "/usr/local/bin/repl-entrypoint.sh" ]
CMD [ "run" ]
