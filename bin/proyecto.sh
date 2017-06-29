#!/bin/sh

if [ -z "$1" ]; then
    echo "Sintaxis: $0 [-d] nombre"
    exit 1
fi

if [ "$1" = "-d" ]; then
    if [ -z "$2" ]; then
        echo "Sintaxis: $0 [-d] nombre"
        exit 1
    else
        echo "Eliminando proyecto $2..."
        if [ -d $2 ]; then
            sudo rm -rf $2
        fi
        sudo sed -i /$2.local/d /etc/hosts
        sudo a2dissite $2
        sudo rm -f /etc/apache2/sites-available/$2.conf
        sudo service apache2 reload
        exit 0
    fi
fi

echo "Creando el proyecto desde la plantilla básica de Yii2..."
composer create-project --no-install --no-scripts yiisoft/yii2-app-basic $1
echo "Creando repositorio git..."
cd $1
git init
git add .
git commit -m "Carga incial"
cd ..
echo "Extrayendo el esqueleto modificado del proyecto..."
curl -L https://github.com/ricpelo/pre/tarball/master | tar xvz --strip 1 -C $1
cd $1
echo "Modificando configuración del proyecto..."
for p in config/web.php config/console.php
do
    sed -r -zi "s%('log' => )\[.*\],(.*)'db'%\1require(__DIR__ . '/log.php'),\2'db'%" $p
done
echo "\n\n.php_cs.cache" >> .gitignore
echo "Modificando archivos con el nombre del proyecto..."
sed -i s/proyecto/$1/g db/* config/*
mv db/proyecto.sql db/$1.sql
mv proyecto.conf $1.conf
sed -i s/proyecto/$1/g $1.conf
echo "Ejecutando composer install y run-script..."
composer install
composer run-script post-create-project-cmd
if ! grep -qs "$1.local" /etc/hosts
then
    echo "Añadiendo entrada para $1.local en /etc/hosts..."
    if grep -qs "^$" /etc/hosts
    then
        sudo sed -ie "s/^$/127.0.0.1	$1.local\n/" /etc/hosts
    else
        echo "127.0.0.1	$1.local" | sudo tee -a /etc/hosts
    fi
else
    echo "Ya existe una entrada para $1.local en /etc/hosts."
fi
if [ ! -f "/etc/apache2/sites-available/$1.conf" ]
then
    echo "Creando sitio virtual $1.local en Apache2..."
    sudo cp $1.conf /etc/apache2/sites-available/$1.conf
    sudo a2ensite $1
    sudo service apache2 reload
else
    echo "El sitio virtual $1.local ya existe en Apache2."
fi
echo "Creando nuevo commit..."
git add .
git commit -m "Cambios de la plantilla del proyecto"
