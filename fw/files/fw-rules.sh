#!/bin/sh

# Alejandro García, Jorge Jiménez, Javier Selva

# Script de reglas personales de iptables.
#Variables ip
ip_lan='192.168.105.0/24'
ip_wan='10.3.4.0/24'
ip_dmz='172.20.105.0/24'

# Variables interface
ilan='ens10'
iwan='ens9'
idmz='ens3'


# función para inicializar el FW.

inicia() {

#activar enrutado

echo 1 > /proc/sys/net/ipv4/ip_forward


#Borrar las reglas iptables existentes

iptables -F

#Reglas por defecto

iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

#Reglas input

# Reglas de acceso SSH
#LAN
iptables -A INPUT -s $ip_lan -i $ilan -p tcp --dport 2222 -j ACCEPT
iptables -A OUTPUT -d $ip_lan -o $ilan -p tcp --sport 2222 -j ACCEPT
#WAN
iptables -A INPUT -s $ip_wan -i $iwan -p tcp --dport 2222 -j ACCEPT
iptables -A OUTPUT -d $ip_wan -o $iwan -p tcp --sport 2222 -j ACCEPT
#DMZ 
iptables -A INPUT -s $ip_dmz -i $idmz -p tcp --dport 2222 -j ACCEPT
iptables -A OUTPUT -d $ip_dmz -o $idmz -p tcp --sport 2222 -j ACCEPT


# Reglas del servicio DHCPD

iptables -A INPUT -i $ilan -p udp --dport 68 --sport 67 -j ACCEPT
iptables -A OUTPUT -o $ilan -p udp --sport 67 --dport 68 -j ACCEPT

iptables -A INPUT -i $idmz -p udp --dport 68 --sport 67 -j ACCEPT
iptables -A OUTPUT -o $idmz -p udp --sport 67 --dport 68 -j ACCEPT


# Reglas del cliente DHCP
iptables -A OUTPUT -o $iwan -p udp --dport 67 --sport 68 -j ACCEPT
iptables -A INPUT -i $iwan -p udp --sport 68 --dport 67 -j ACCEPT

#ssh de la lan a la dmz

iptables -A FORWARD -s $ip_lan -d $ip_dmz -p tcp --dport 22 -j ACCEPT
iptables -A FORWARD -d $ip_lan -s $ip_dmz -p tcp --sport 22 -j ACCEPT

#dns lan a la dmz

iptables -A FORWARD -s $ip_lan -d $ip_dmz -p udp --dport 53 -j ACCEPT
iptables -A FORWARD -d $ip_lan -s $ip_dmz -p udp --sport 53 -j ACCEPT

#http a la dmz

iptables -A FORWARD -i $idmz -d $ip_dmz -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -o $idmz -s $ip_dmz -p tcp --sport 80 -j ACCEPT

#acceso desde la dmz a servidor web en la wan

iptables -A FORWARD -i $idmz -s $ip_dmz -o $iwan -p tcp --dport 80 -j ACCEPT
iptables -A FORWARD -i $iwan -d $ip_dmz -o $idmz -p tcp --sport 80 -j ACCEPT

#https a la dmz
iptables -A FORWARD -d $ip_dmz -p tcp --dport 443 -j ACCEPT
iptables -A FORWARD -s $ip_dmz -p tcp --sport 443 -j ACCEPT

#ping
iptables -A OUTPUT -p icmp -j ACCEPT
iptables -A INPUT -p icmp -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT

# Acceso al servidor web

iptables -t nat -A PREROUTING -i $iwan -p tcp --dport 80 -j DNAT --to 172.20.105.22

# salida a repositorios de servidores de la dmz

iptables -t nat -A POSTROUTING -s $ip_dmz -o $iwan -p tcp --dport 80 -j SNAT --to 10.3.4.199
iptables -A FORWARD -s $ip_dmz  -p tcp --dport 80 -o $idmz -j ACCEPT

#salida a internet de la LAN

iptables -t nat -A POSTROUTING -s$ip_lan -p tcp --dport 80 -j SNAT --to 10.3.4.199
iptables -A FORWARD -s $ip_lan  -p tcp --dport 80 -o $ilan -j ACCEPT

#ssh a la dmz

iptables -t nat -A PREROUTING -i $iwan -d 10.3.4.199 -p tcp --dport 2222 -j DNAT --to 172.20.105.22

# DNS dmz

iptables -A OUTPUT -i $idmz -s 172.20.105.254 -p udp --dport 53 -d 172.20.105.22 -j ACCEPT
iptables -A INPUT -o $idmz -d 172.20.105.254 -p udp --sport 53 -s 172.20.105.22 -j ACCEPT

#dns wan
iptables -A OUTPUT -i $iwan -s 10.3.4.199 -p udp --dport 53 -j ACCEPT
iptables -A INPUT -o $iwan -d 10.3.4.199 -p udp --sport 53 -j ACCEPT



}

#función para parar el FW

para() {

# Limpieza tabla
iptables -F

# Reglas generales

iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD ACCEPT
}


# Operación principal del script
# Para comprobar que eres root averiguamos si el id es 0
# [ $(id -u) -eq 0 ]

# Comprobamos los parámetros y seleccionamos la opción correcta.



if [ $# -ne 1 ]
        then
                echo "Número de parámetros incorrectos. Escriba start o stop"
                exit 23
fi

case $1 in
        'start') inicia;;
        'stop') para;;
        *) echo "parámetro incorrecto";exit 24;;
esac

exit 0
