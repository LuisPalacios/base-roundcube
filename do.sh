#!/bin/bash
#
# Punto de entrada para el servicio roundcube
#
# Activar el debug de este script:
# set -eux

##################################################################
#
# main
#
##################################################################

# Averiguar si necesito configurar por primera vez
#
CONFIG_DONE="/.config_roundcube_done"
NECESITA_PRIMER_CONFIG="si"
if [ -f ${CONFIG_DONE} ] ; then
    NECESITA_PRIMER_CONFIG="no"
fi

##################################################################
#
# VARIABLES OBLIGATORIAS
#
##################################################################

## Servidor:Puerto por el que conectar con el servidor MYSQL
#
if [ -z "${MYSQL_LINK}" ]; then
	echo >&2 "error: falta el Servidor:Puerto del servidor MYSQL: MYSQL_LINK"
	exit 1
fi
mysqlHost=${MYSQL_LINK%%:*}
mysqlPort=${MYSQL_LINK##*:}

## Contraseña del usuario root en MySQL Server
#
if [ -z "${SQL_ROOT_PASSWORD}" ]; then
	echo >&2 "error: falta la contraseña de root para MYSQL: SQL_ROOT_PASSWORD"
	exit 1
fi

## Servidor:Puerto por el que escucha el agregador de Logs (fluentd)
#
if [ -z "${FLUENTD_LINK}" ]; then
	echo >&2 "error: falta el Servidor:Puerto por el que escucha fluentd, variable: FLUENTD_LINK"
	exit 1
fi
fluentdHost=${FLUENTD_LINK%%:*}
fluentdPort=${FLUENTD_LINK##*:}

## Variables para crear la BD del servicio
#
if [ -z "${SERVICE_DB_USER}" ]; then
	echo >&2 "error: falta la variable SERVICE_DB_USER"
	exit 1
fi
if [ -z "${SERVICE_DB_PASS}" ]; then
	echo >&2 "error: falta la variable SERVICE_DB_PASS"
	exit 1
fi
if [ -z "${SERVICE_DB_NAME}" ]; then
	echo >&2 "error: falta la variable SERVICE_DB_NAME"
	exit 1
fi

## Servidor imap
#
if [ -z "${ROUNDCUBE_IMAP_HOST}" ]; then
	echo >&2 "error: falta la variable ROUNDCUBE_IMAP_HOST"
	exit 1
fi
## Servidor smtp
#
if [ -z "${ROUNDCUBE_SMTP_HOST}" ]; then
	echo >&2 "error: falta la variable ROUNDCUBE_SMTP_HOST"
	exit 1
fi

# Variables fijas
#
ROUNDCUBE_CONFIG_FILE="/var/www/html/config/config.inc.php"

# Algo de Log...
echo >&2 "Tengo todas las variables"
echo >&2 "SERVICE_DB_USER: ${SERVICE_DB_USER}"
echo >&2 "SERVICE_DB_PASS: ${SERVICE_DB_PASS}"
echo >&2 "SERVICE_DB_NAME: ${SERVICE_DB_NAME}"
echo >&2 "ROUNDCUBE_SMTP_HOST: ${ROUNDCUBE_SMTP_HOST}"
echo >&2 "ROUNDCUBE_IMAP_HOST: ${ROUNDCUBE_IMAP_HOST}"
echo >&2 "SQL_ROOT: root"
echo >&2 "SQL_ROOT_PASSWORD: ${SQL_ROOT_PASSWORD}"
echo >&2 "mysqlHost: ${mysqlHost}"
echo >&2 "mysqlPort: ${mysqlPort}"
echo >&2 "FLUENTD_LINK: ${FLUENTD_LINK}"
echo >&2 "-----------------------------------------------------------"

##################################################################
#
# Instalación de Roundcube
#
##################################################################

# Instalo roundcube si no existe
#
if [ ! -f "${ROUNDCUBE_CONFIG_FILE}" ];then 
	cp -R /root/roundcube*/* /var/www/html/
	chown -R www-data:www-data /var/www/html/*
	chmod -R 775 /var/www/html/temp
	chmod -R 775 /var/www/html/logs
	cp /404.php /var/www/html/
	rm -fr /var/www/html/installer
	
	echo >&2 "He instalado roundcube en /var/www/html"
	echo >&2 "-----------------------------------------------------------"
fi
	
##################################################################
#
# Fichero de configuración de roundcube
#
# ROUNDCUBE_CONFIG_FILE="/var/www/html/config/config.inc.php"
#
##################################################################
#
#  ToDo: Implementar un contenedor externo con davical y configurar
#        roundcube con el plugin CardDAV Backend para que lo utilice
#
cat > ${ROUNDCUBE_CONFIG_FILE} <<EOF_RC_CONFIG_FILE
<?php

\$config = array();

// Base de datos 'roundcube'
//
\$config['db_dsnw'] = 'mysql://${SERVICE_DB_USER}:${SERVICE_DB_PASS}@${mysqlHost}:${mysqlPort}/roundcube';

// Servidor IMAP
// ==============
// (nota: en mi caso desactivo verificación SSL/TLS)
// NOTA: Ojo que es peligroso desactivar la verificación del certificado SSL/TLS del 
//       servidor IMAP. Solo te recomiendo hacerlo en caso de usarlo contra tu propio servidor IMAP
//
\$config['default_host'] = '${ROUNDCUBE_IMAP_HOST}';
\$config['imap_conn_options'] = array(
 'ssl'         => array(
    'verify_peer'  => false,
    'verify_peer_name'  => false,
  ),
);

// Servidor SMTP
//
\$config['smtp_server'] = '${ROUNDCUBE_SMTP_HOST}';
\$config['smtp_port'] = 25;
\$config['smtp_user'] = '';
\$config['smtp_pass'] = '';

// Logging. Lo configuro para syslog. Activo la variable FLUENTD_LINK y 
// recibo los logs en un contenedor diseñado con fluentd, elasticsearch y
// kibana para la gestión de logs. Ver https://github.com/LuisPalacios/servicio-log
//
\$config['log_driver'] = 'syslog';
\$config['log_date_format'] = 'd-M-Y H:i:s O';
\$config['syslog_id'] = 'roundcube';
\$config['syslog_facility'] = LOG_USER;
\$config['smtp_log'] = true;
\$config['log_logins'] = true;
\$config['log_session'] = true;


// Plugings que activo en mi contenedor roundcube
//
\$config['plugins'] = array(
    'archive',
    'zipdownload',
    'emoticons',
);

EOF_RC_CONFIG_FILE

echo >&2 "He modificado el fichero ${ROUNDCUBE_CONFIG_FILE}"
echo >&2 "-----------------------------------------------------------"

## Si no existe, creo la base de datos en el servidor MySQL, notar
#  que debemos tener las variables que indican el nombre de la DB, 
#  y el usuario/contraseña
#

# Ejecuto la creación de la base de datos 
#
TERM=dumb php -- "${MYSQL_LINK}" "root" "${SQL_ROOT_PASSWORD}" "${SERVICE_DB_NAME}" "${SERVICE_DB_USER}" "${SERVICE_DB_PASS}" <<'EOPHP'
<?php
////
//
// docker_sql.php
//
// Gestor de creación de la base de datos, usuario y contraseña.
// Si ya existe la base de datos entonces no se hace nada.
//
// Argumentos que se esperan: 
//
// argv[1] : Servidor MySQL en formato X.X.X.X:PPPP
// argv[2] : SQL_ROOT 			--> "root"  Usuario root
// argv[3] : SQL_ROOTPASSWORD	--> "<contraseña_de_root>
// argv[4] : SERVICE_DB_NAME	--> Nombre de la base de datos
// argv[5] : SERVICE_DB_USER	--> Usuario a crear
// argv[6] : SERVICE_DB_PASS	--> Contraseña de dicho usuario
//
// Ejemplo: 
//   php -f sql_test.php 192.168.1.245:3306 root rootpass mi_db mi_user mi_user_pass
//
// Autor: Luis Palacios (Nov 2014)
//

// Consigo la direccio IP y el puerto
list($host, $port) = explode(':', $argv[1], 2);

// Conecto con el servidor MySQL como root
$mysql = new mysqli($host, $argv[2], $argv[3], '', (int)$port);
if ($mysql->connect_error) {
   file_put_contents('php://stderr', '*** MySQL *** | MySQL - Error de conexión: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
   exit(1);
} else {
	printf("*** MySQL *** | MySQL Server: %s - La conexión ha sido un éxito\n", $mysql->real_escape_string($host) ); 
}

// Informo sobre la existencia de la base de datos

if ( $resultado = $mysql->query('SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME ="' . $mysql->real_escape_string($argv[4]) . '"') ) {
 if( mysqli_num_rows($resultado)>=1) {
	printf("*** MySQL *** | La base de datos '%s' ya existe, termino la ejecución\n", $mysql->real_escape_string($argv[4]) ); 
	exit(0);
 } else {
	printf("*** MySQL *** | La base de datos '%s' NO existe, voy a crearla\n", $mysql->real_escape_string($argv[4]) ); 
 }
}

// Creo la base de datos si no existia 
if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
	file_put_contents('php://stderr', '*** MySQL *** | MySQL - Error de creación de la base de datos: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
}

// Doble comprobación, de que efectivamente existe la base de datos
if ( $resultado = $mysql->query('SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME ="' . $mysql->real_escape_string($argv[4]) . '"') ) {
 if( !mysqli_num_rows($resultado)>=1) {
	file_put_contents('php://stderr', '*** MySQL *** | La base de datos no existe, no puedo seguir, error: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
 }
}

// Selecciono la base de datos
$mysql->select_db( 'mysql' ) or die('*** MySQL *** | No se pudo seleccionar la base de datos mysql');

// Averiguo
if ( $resultado = $mysql->query('SELECT User FROM user WHERE User="' . $mysql->real_escape_string($argv[5]) . '"') ) {
 if( !mysqli_num_rows($resultado)>=1) {

 	// No existe, lo creo
	printf("*** MySQL *** | El usuario '%s' no existe, voy a crearlo\n", $mysql->real_escape_string($argv[5]) ); 
	if (!$mysql->query('CREATE USER "' . $mysql->real_escape_string($argv[5]) . '"@"%" IDENTIFIED BY "' . $mysql->real_escape_string($argv[6]) . '"')) {
		file_put_contents('php://stderr', '*** MySQL *** | MySQL - Error al intentar crear el usuario: ' . $mysql->error . "\n");
		$mysql->close();
		exit(1);
	} else {
		printf("*** MySQL *** | La creación del usuario '%s' fue un éxito\n", $mysql->real_escape_string($argv[5]) ); 
	}
  }  else {
	printf("*** MySQL *** | El usuario '%s' ya existe\n", $mysql->real_escape_string($argv[5]) ); 
  }
	
  // Asigno al propietario todos los privilegios sobre la nueva BD
  if (!$mysql->query('GRANT ALL ON ' . $mysql->real_escape_string($argv[4]) . '.* TO "' . $mysql->real_escape_string($argv[5]) . '"@"%"')) {
	file_put_contents('php://stderr', '*** MySQL *** | MySQL - Error al intentar darle todos los permisos al usuario: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
  } else {
	printf("*** MySQL *** | Asignados con éxito los permisos para el usuario '%s' en la base de datos '%s'\n", $mysql->real_escape_string($argv[5]) , $mysql->real_escape_string($argv[4]) ); 
  }
	
} else {
	file_put_contents('php://stderr', '*** MySQL *** | La búsqueda del usuario devolvió error: ' . $mysql->error . "\n");
	$mysql->close();
	exit(1);
}

$mysql->close();
exit(0);

?>
EOPHP

## Creo (si hace falta) la estructura de tablas 
#
if [ $(mysql -h ${mysqlHost} -P ${mysqlPort}  -N -s -u root --password=${SQL_ROOT_PASSWORD} -e "select count(*) from information_schema.tables where table_schema='${SERVICE_DB_NAME}' and table_name='cache';") -eq 0 ]; then
    mysql -h mysql -P 3306 -u ${SERVICE_DB_USER} --password=${SERVICE_DB_PASS} -D ${SERVICE_DB_NAME} < /var/www/html/SQL/mysql.initial.sql
	echo >&2 "He creado las tablas de la base de datos"
	echo >&2 "-----------------------------------------------------------"
else
	echo >&2 "La base de datos ya tiene las tablas creadas"
	echo >&2 "-----------------------------------------------------------"
fi

echo >&2 "-----------------------------------------------------------"
echo >&2 "Terminó la verificación de la base de datos"
echo >&2 "-----------------------------------------------------------"


##################################################################
#
# PREPARAR LA SECCIÓN DE SUPERVISOR Y LOGGING
#
##################################################################

# Necesito configurar por primera vez?
#
if [ ${NECESITA_PRIMER_CONFIG} = "si" ] ; then

	############
	#
	# rsyslogd
	#
	############
	# Configurar rsyslogd para que envíe logs a un agregador remoto
	echo "Configuro rsyslog.conf"

	### 
	### INICIO FICHERO /etc/rsyslog.conf 
	### ------------------------------------------------------------------------------------------------
    cat > /etc/rsyslog.conf <<-EOF_RSYSLOG
	
	\$LocalHostName roundcube
	\$ModLoad imuxsock # provides support for local system logging
	#\$ModLoad imklog   # provides kernel logging support
	#\$ModLoad immark  # provides --MARK-- message capability
	
	# provides UDP syslog reception
	#\$ModLoad imudp
	#\$UDPServerRun 514
	
	# provides TCP syslog reception
	#\$ModLoad imtcp
	#\$InputTCPServerRun 514
	
	# Activar para debug interactivo
	#
	#\$DebugFile /var/log/rsyslogdebug.log
	#\$DebugLevel 2
	
	\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
	
	\$FileOwner root
	\$FileGroup adm
	\$FileCreateMode 0640
	\$DirCreateMode 0755
	\$Umask 0022
	
	#\$WorkDirectory /var/spool/rsyslog
	#\$IncludeConfig /etc/rsyslog.d/*.conf
	
	# Dirección del Host:Puerto agregador de Log's con Fluentd
	#
	*.* @@${fluentdHost}:${fluentdPort}
	
	# Activar para debug interactivo
	#
	# *.* /var/log/syslog
	
	EOF_RSYSLOG
	### ------------------------------------------------------------------------------------------------
	### FIN FICHERO /etc/rsyslog.conf  
	### 



	############
	#
	# Supervisor
	# 
	############
	echo "Configuro supervisord.conf"

	### 
	### INICIO FICHERO /etc/supervisor/conf.d/supervisord.conf  
	### ------------------------------------------------------------------------------------------------
	cat > /etc/supervisor/conf.d/supervisord.conf <<-EOF_SUPERVISOR
	
	[unix_http_server]
	file=/var/run/supervisor.sock 					; Path al fichero socket
	
	[inet_http_server]
	port = 0.0.0.0:9001								; Permitir la conexión desde el browser
	
	[supervisord]
	logfile=/var/log/supervisor/supervisord.log 	; Fichero de log
	logfile_maxbytes=10MB 							; Tamaño máximo del log antes de rotarlo
	logfile_backups=2 								; Número de logfiles que se guardan
	loglevel=error 									; info, debug, warn, trace
	pidfile=/var/run/supervisord.pid 				; localización del pidfile
	minfds=1024 									; número de startup file descriptors
	minprocs=200 									; número de process descriptors
	user=root 										; usuario por defecto
	childlogdir=/var/log/supervisor/ 				; dónde vivirán los logs de los childs
	
	nodaemon=false 									; Ejecutar supervisord como un daemon (util para debugging)
	;nodaemon=true 									; Ejecutar supervisord interactivo (producción)
	
	[rpcinterface:supervisor]
	supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface
	
	[supervisorctl]
	serverurl=unix:///var/run/supervisor.sock		; Usar URL unix:// para un socket unix

	[program:apache]
	process_name = apache
	directory = /var/www/html
	command = /usr/sbin/apache2ctl -D FOREGROUND
	startsecs = 0
	autorestart = false
	
	[program:rsyslog]
	process_name = rsyslogd
	command=/usr/sbin/rsyslogd -n
	startsecs = 0
	autorestart = true
	
	#
	# DESCOMENTAR PARA DEBUG o SI QUIERES SSHD
	#	
	#[program:sshd]
	#process_name = sshd
	#command=/usr/sbin/sshd -D
	#startsecs = 0
	#autorestart = true
	
	EOF_SUPERVISOR
	### ------------------------------------------------------------------------------------------------
	### FIN FICHERO /etc/supervisor/conf.d/supervisord.conf  
	### 

    #
    # Creo el fichero de control para que el resto de 
    # ejecuciones no realice la primera configuración
    > ${CONFIG_DONE}
	echo "Termino la primera configuración del contenedor"
	
fi

##################################################################
#
# EJECUCIÓN DEL COMANDO SOLICITADO
#
##################################################################
#
exec "$@"
