#!/bin/bash
#
# ENTRYPOINT script for "ROUNDCUBE" Service
#
#set -eux

## Compruebo que se ha hecho el Link:
#
#
if [ -z "${MYSQL_PORT_3306_TCP}" ]; then
	echo >&2 "error: falta la variable MYSQL_PORT_3306_TCP"
	echo >&2 "  Olvidaste --link un_contenedor_mysql:mysql ?"
	exit 1
fi
#  La dirección IP del HOST donde reside MySQL se calcula automáticamente
mysqlLink="${MYSQL_PORT_3306_TCP#tcp://}"
mysqlHost=${mysqlLink%%:*}
mysqlPort=${mysqlLink##*:}

## Conseguir la password de root desde el Link con el contenedor MySQL
#
#  Tiene que estar hecho el Link con el contenedor MySQL y desde él
#  averiguo la contraseña de root (MYSQL_ENV_MYSQL_ROOT_PASSWORD)
#
: ${SQL_ROOT:="root"}
if [ "${SQL_ROOT}" = "root" ]; then
	: ${SQL_ROOT_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
fi
if [ -z "${SQL_ROOT_PASSWORD}" ]; then
	echo >&2 "error: falta la variable MYSQL_ROOT_PASSWORD"
	exit 1
fi

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


echo >&2 "Tengo todas las variables"
echo >&2 "SERVICE_DB_USER: ${SERVICE_DB_USER}"
echo >&2 "SERVICE_DB_PASS: ${SERVICE_DB_PASS}"
echo >&2 "SERVICE_DB_NAME: ${SERVICE_DB_NAME}"
echo >&2 "ROUNDCUBE_SMTP_HOST: ${ROUNDCUBE_SMTP_HOST}"
echo >&2 "SQL_ROOT: ${SQL_ROOT}"
echo >&2 "SQL_ROOT_PASSWORD: ${SQL_ROOT_PASSWORD}"
echo >&2 "mysqlHost: ${mysqlHost}"
echo >&2 "mysqlPort: ${mysqlPort}"
echo >&2 "-----------------------------------------------------------"


# Instalo roundcube si no existe
#
if [ ! -f "${ROUNDCUBE_CONFIG_FILE}" ];then 
	cp -R /root/roundcube*/* /var/www/html/
	chown -R www-data:www-data /var/www/html/*
	chmod -R 775 /var/www/html/temp
	chmod -R 775 /var/www/html/logs
	
	echo >&2 "He instalado roundcube en /var/www/html"
	echo >&2 "-----------------------------------------------------------"
fi
	

# Modifico el fichero de configuración de Roundcube
#
if [ -n "${SERVICE_DB_PASS}" ]; then
	if [ -f "${ROUNDCUBE_CONFIG_FILE}" ];then 
   		sed -i "s/^\$config\['db_dsnw'\].*/\$config\['db_dsnw'\] = 'mysql:\/\/${SERVICE_DB_USER}:${SERVICE_DB_PASS}@${mysqlHost}\/roundcube';/g" ${ROUNDCUBE_CONFIG_FILE}
   	fi
fi
if [ -n "${ROUNDCUBE_IMAP_HOST}" ]; then
	if [ -f "${ROUNDCUBE_CONFIG_FILE}" ];then 
	   sed -i "s/^\$config\['default_host'\].*/\$config\['default_host'\] = '${ROUNDCUBE_IMAP_HOST}';/g" ${ROUNDCUBE_CONFIG_FILE}
   	fi
fi
if [ -n "${ROUNDCUBE_SMTP_HOST}" ]; then
	if [ -f "${ROUNDCUBE_CONFIG_FILE}" ];then 
	   sed -i "s/^\$config\['smtp_server'\].*/\$config\['smtp_server'\] = '${ROUNDCUBE_SMTP_HOST}';/g" ${ROUNDCUBE_CONFIG_FILE}
   	fi
fi
echo >&2 "He modificado el fichero ${ROUNDCUBE_CONFIG_FILE}"
echo >&2 "-----------------------------------------------------------"

## Si no existe, creo la base de datos en el servidor MySQL, notar
#  que debemos tener las variables que indican el nombre de la DB, 
#  y el usuario/contraseña
#

# Ejecuto la creación de la base de datos 
#
TERM=dumb php -- "${mysqlLink}" "${SQL_ROOT}" "${SQL_ROOT_PASSWORD}" "${SERVICE_DB_NAME}" "${SERVICE_DB_USER}" "${SERVICE_DB_PASS}" <<'EOPHP'
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
if [ $(mysql -h ${mysqlHost} -P ${mysqlPort}  -N -s -u ${SQL_ROOT} --password=${SQL_ROOT_PASSWORD} -e "select count(*) from information_schema.tables where table_schema='${SERVICE_DB_NAME}' and table_name='cache';") -eq 0 ]; then
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


## Ejecuto el comando que me pasan
#
#
exec "$@"

