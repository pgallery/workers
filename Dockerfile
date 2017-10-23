FROM pgallery/php:latest

LABEL maintainer="Ruzhentsev Alexandr <git@pgallery.ru>"
LABEL version="1.0 beta"
LABEL description="Docker image PHP-CLI 7.1 and Workers pGallery"

RUN apt-get update && apt-get -y upgrade && apt-get install -y git supervisor

COPY scripts/ 			/usr/local/bin/
COPY config/supervisord.conf 	/etc/supervisord.conf

RUN chmod 755 /usr/local/bin/docker-entrypoint.sh

VOLUME /var/www/html

CMD ["/usr/local/bin/docker-entrypoint.sh"]
