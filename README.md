# Introducción

Este repositorio alberga un *contenedor Docker* para montar RoundCube Mail, está automatizado en el Registry Hub de Docker [luispa/base-roundcube](https://registry.hub.docker.com/u/luispa/base-roundcube/) conectado con el el proyecto en [GitHub base-rouncube](https://github.com/LuisPalacios/base-roundcube)

Consulta este [apunte técnico sobre varios servicios en contenedores Docker](http://www.luispa.com/?p=172) para acceder a otros contenedores Docker y sus fuentes en GitHub.

## Ficheros

* **Dockerfile**: Para crear la base de un servicio roundcube mail
* **do.sh**: Script que se ejecutará al arrancar el contenedor. 


## Instalación de la imagen

Para usar la imagen desde el registry de docker hub

    totobo ~ $ docker pull luispa/base-roundcube


## Clonar el repositorio

Este es el comando a ejecutar para clonar el repositorio y poder trabajar con él directamente

    ~ $ clone https://github.com/LuisPalacios/docker-roundcube.git

Luego puedes crear la imagen localmente con el siguiente comando

    $ docker build -t luispa/base-roundcube ./


# Configuración


## Volúmenes

Directorio persistente para configurar el Timezone. Crear el directorio /Apps/data/tz y dentro de él crear el fichero timezone. Luego montarlo con -v o con fig.yml

    Montar:
       "/Apps/data/tz:/config/tz"  
    Preparar: 
       $ echo "Europe/Madrid" > /config/tz/timezone

## Variables


Las siguientes variables se utilizan para identificar dónde (nombre/IP y puerto) está el servidor MySQL  para poder crear la base de datos Roundcube, o emplear la ya existente.

    MYSQL_LINK:          "tuservidor-MySQL.tld.org:33000"
    SQL_ROOT_PASSWORD:   "contraseña_root_en_MySQL"
    SERVICE_DB_USER:     "usuario_roundcube"
    SERVICE_DB_PASS:     "contraseña_usuario_roundcube"
    SERVICE_DB_NAME:     "nombre_base_de_datos_roundcube" 
    ROUNDCUBE_SMTP_HOST: "tls://x.x.x.x   Dirección IP del SMTP Host"
    ROUNDCUBE_IMAP_HOST: "tls://x.x.x.x:143 IP y puerto del IMAP Server"

`FLUENTD_LINK`

Es opcional, si quieres activar el envío de logs a un agregador, usa la siguiente variable: 

    FLUENTD_LINK:    "servidor-agregador.tld.org:24224"
    
Aquí tienes un ejemplo sobre cómo instalarte tu propio agregador de Logs, échale un vistazo a este proyecto: [servicio-log](https://github.com/LuisPalacios/servicio-log). 
