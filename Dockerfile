#
# Roundcube container by Luispa, Nov 2014
#
# -----------------------------------------------------
#

# Desde donde parto...
#
FROM luispa/base-apache

# Autor
#
MAINTAINER Luis Palacios <luis@luispa.com>

# Pido que el frontend de Debian no sea interactivo
ENV DEBIAN_FRONTEND noninteractive

# Instalo mysql client para poder crear la base de datos roundcube si no existe
#
RUN apt-get update && \
	apt-get -y install mysql-client

# Directorio de trabajo
#
WORKDIR /root

# Pongo un fichero de virtual host personalizado para apache
#
ADD ./000-default.conf /etc/apache2/sites-available/000-default.conf

# Descargo roundcubemail
#
RUN wget http://freefr.dl.sourceforge.net/project/roundcubemail/roundcubemail/1.0.3/roundcubemail-1.0.3.tar.gz -O - | tar xz ;
ADD config.inc.php /root/roundcubemail-1.0.3/config/

# Copia el 404.php
#
RUN rm -f /var/www/html/index.html
ADD 404.php /var/www/html/404.php

# Ejecutable a arrancar siempre
#
ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Punto de entrada al contendor
ENTRYPOINT ["/entrypoint.sh"]

# Comando a ejecutar por defecto (si no se especifica)
CMD ["/usr/sbin/apache2ctl", "-D FOREGROUND"]

