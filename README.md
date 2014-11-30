# Introducción

Este repositorio alberga un *contenedor Docker* para montar RoundCube Mail, está automatizado en el Registry Hub de Docker [luispa/base-roundcube](https://registry.hub.docker.com/u/luispa/base-rouncube/) conectado con el el proyecto en [GitHub base-rouncube](https://github.com/LuisPalacios/base-roundcube)


## Ficheros

* **Dockerfile**: Para crear la base de un servicio roundcube mail

## Instalación de la imagen

Para usar la imagen desde el registry de docker hub

  totobo ~ $ docker pull luispa/base-rouncube


## Clonar el repositorio

Este es el comando a ejecutar para clonar el repositorio y poder trabajar con él directamente

  ~ $ clone https://github.com/LuisPalacios/docker-rouncube.git

Luego puedes crear la imagen localmente con el siguiente comando

  $ docker build -t luispa/base-roundcube ./
