# Introducción

Este repositorio alberga un *contenedor Docker* para montar RoundCube Mail, está automatizado en el Registry Hub de Docker [luispa/base-roundcube](https://registry.hub.docker.com/u/luispa/base-roundcube/) conectado con el el proyecto en [GitHub base-rouncube](https://github.com/LuisPalacios/base-roundcube)

Consulta este [apunte técnico sobre varios servicios en contenedores Docker](http://www.luispa.com/?p=172) para acceder a otros contenedores Docker y sus fuentes en GitHub.

## Ficheros

* **Dockerfile**: Para crear la base de un servicio roundcube mail
* **do.sh**: Script que se ejecutará al arrancar el contenedor. 


## Instalación de la imagen

Para usar la imagen desde el registry de docker hub

    totobo ~ $ docker pull luispa/base-rouncube


## Clonar el repositorio

Este es el comando a ejecutar para clonar el repositorio y poder trabajar con él directamente

    ~ $ clone https://github.com/LuisPalacios/docker-rouncube.git

Luego puedes crear la imagen localmente con el siguiente comando

    $ docker build -t luispa/base-roundcube ./

# Configuración


## Volúmenes

Es importante que prepares un volumen persistente donde imapfilter espera encontrar su(s) fichero(s) de configuración. En mi caso es el siguiente: 

    - /Apps/data/correo/imapfilter/:/root/.imapfilter/
    
Dentro de este directorio DEBES CREAR/EDITAR el fichero con los certificados SSL/TLS de tus servidores y además el(los) fichero(s) de configuraicón

	- certificates
	- config*.lua


## Variables

`MYSQL_LINK`, `SQL_ROOT_PASSWORD`, `SERVICE_DB_USER`, `SERVICE_DB_PASS`, `SERVICE_DB_NAME`

Las siguientes variables se utilizan para identificar dónde (nombre/IP y puerto) está el servidor MySQL  para poder crear la base de datos Roundcube, o emplear la ya existente.

    MYSQL_LINK:          "tuservidor-MySQL.tld.org:33000"
    SQL_ROOT_PASSWORD:   "contraseña_root_en_MySQL"
    SERVICE_DB_USER:     "usuario_roundcube"
    SERVICE_DB_PASS:     "contraseña_usuario_roundcube"
    SERVICE_DB_NAME:     "nombre_base_de_datos_roundcube"
    
Aquí tienes un ejemplo sobre cómo instalarte tu propio servidor MySQL en otro contenedor, échale un vistazo a este proyecto: [servicio-db-correo](https://github.com/LuisPalacios/servicio-db-correo). 

`ROUNDCUBE_SMTP_HOST`, `ROUNDCUBE_IMAP_HOST`,

Estas dos variables permiten al contenedor configurar dónde está el servidor SMTP y el servidor IMAP

    ROUNDCUBE_SMTP_HOST: "tls://<dirección_ip_o_nombre_DNS>"
    ROUNDCUBE_IMAP_HOST: "tls://<dirección_ip_o_nombre_DNS>:143"
  
Aquí tienes un ejemplo sobre cómo instalarte tus propios contenedores con servidores SMTP, IMAP e incluso un "chatarrero" para el spam y los virus, échale un vistazo a este proyecto: [servicio-correo](https://github.com/LuisPalacios/servicio-correo). 

`FLUENTD_LINK`

Es opcional, si quieres activar el envío de logs a un agregador, usa la siguiente variable: 

    FLUENTD_LINK:    "servidor-agregador.tld.org:24224"
    
Aquí tienes un ejemplo sobre cómo instalarte tu propio agregador de Logs, échale un vistazo a este proyecto: [servicio-log](https://github.com/LuisPalacios/servicio-log). 
