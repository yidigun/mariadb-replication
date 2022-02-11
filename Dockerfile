ARG IMG_NAME
ARG IMG_TAG
ARG LANG=ko_KR.UTF-8
ARG TZ=Asia/Seoul

FROM docker.io/library/mariadb:$IMG_TAG

ENV IMG_NAME=$IMG_NAME
ENV IMG_TAG=$IMG_TAG
ENV LANG=$LANG
ENV TZ=$TZ

COPY entrypoint.sh /entrypoint.sh
COPY docker-entrypoint-initdb.d/* /docker-entrypoint-initdb.d/
COPY conf.d/* /etc/mysql/conf.d/
RUN mkdir -p /snapshots

EXPOSE 3306/tcp
VOLUME /snapshots

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "run" ]
