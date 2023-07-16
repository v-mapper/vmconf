#!/system/bin/sh
# version 1.7.2

source /data/local/ATVdetailsWebhook.config
logfile="/sdcard/vm.log"

if [ -z $WH_RECEIVER_HOST ] ;then
  WH_RECEIVER_HOST=$(grep -w 'postdest' /data/data/de.vahrmap.vmapper/shared_prefs/config.xml | sed -e 's/    <string name="postdest">\(.*\):.*<\/string>/\1/' )
fi

#Configs
vmconf=/data/data/de.vahrmap.vmapper/shared_prefs/config.xml
vmstore=/data/data/de.vahrmap.vmapper/shared_prefs/store.xml
vmlog=/sdcard/vm.log
vmapperlog=/sdcard/vmapper.log

while true
  do
    [ ! -f /sdcard/sendwebhook ] && echo "`date +%Y-%m-%d_%T` WHsender: sender stopped" >> $logfile && exit 1

# generic
    datetime=`date "+%Y-%m-%d %T"`
    RPL=$(($SENDING_INTERVAL_SECONDS/60))
    origin=$(grep -w 'origin' $vmconf | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/')
    arch=$(uname -m)
    productmodel=$(getprop ro.product.model)
    vm_script=$(head -2 /system/bin/vmapper.sh | grep '# version' | awk '{ print $NF }')
    vmapper55=$([ -f /system/etc/init.d/55vmapper ] && head -2 /system/etc/init.d/55vmapper | grep '# version' | awk '{ print $NF }' || echo 'na')
    vmapper42=$([ -f /system/etc/init.d/42vmapper ] && head -2 /system/etc/init.d/42vmapper | grep '# version' | awk '{ print $NF }' || echo 'na')
    vmwatchdog56=$([ -f /system/etc/init.d/56vmwatchdog ] && head -2 /system/etc/init.d/56vmwatchdog | grep '# version' | awk '{ print $NF }' || echo 'na')
    whversion=$([ -f /system/bin/ATVdetailsSender.sh ] && head -2 /system/bin/ATVdetailsSender.sh | grep '# version' | awk '{ print $NF }' || echo 'na')
    pogo=$(dumpsys package com.nianticlabs.pokemongo | grep versionName | head -n1 | sed 's/ *versionName=//')
    vmapper=$(dumpsys package de.vahrmap.vmapper | grep versionName | head -n1 | sed 's/ *versionName=//')
    pogo_update=$([ -f /sdcard/disableautopogoupdate ] && echo disabled || echo enabled)
    vm_update=$([ -f /sdcard/disableautovmapperupdate ] && echo disabled || echo enabled)
    playstore=$([ -n "$(ps | grep com.android.vending)" ] && echo 'enabled' || echo 'disabled')
    wh_enabled=$([ -f /sdcard/sendwebhook ] && echo 'enabled' || echo 'disabled')
    temperature=$(cat /sys/class/thermal/thermal_zone0/temp | cut -c -2)
    magisk=$(magisk -c | sed 's/:.*//')
    magisk_modules=$(ls -1 /sbin/.magisk/img | xargs | sed -e 's/ /, /g' 2>/dev/null)
    macw=$([ -d /sys/class/net/wlan0 ] && ifconfig wlan0 |grep 'HWaddr' |awk '{ print ($NF) }' || echo 'na')
    mace=$(ifconfig eth0 |grep 'HWaddr' |awk '{ print ($NF) }')
    ip=$(ifconfig wlan0 |grep 'inet addr' |cut -d ':' -f2 |cut -d ' ' -f1 && ifconfig eth0 |grep 'inet addr' |cut -d ':' -f2 |cut -d ' ' -f1)
    ext_ip=$(curl -k -s https://ifconfig.me/)
    proxy=$(settings list global | grep "http_proxy=" | awk -F= '{ print $NF }')
    hostname=$(getprop net.hostname)
    bootdelay=$(grep -w 'bootdelay' $vmconf | awk -F "\"" '{print tolower($4)}')
# settings
    gzip=$(grep -w 'gzip' $vmconf | awk -F "\"" '{print tolower($4)}')
    betamode=$(grep -w 'betamode' $vmconf | awk -F "\"" '{print tolower($4)}')
    selinux=$(grep -w 'selinux' $vmconf | awk -F "\"" '{print tolower($4)}')
    daemon=$(grep -w 'daemon' $vmconf | awk -F "\"" '{print tolower($4)}')
    authpassword=$(grep -w 'authpassword' $vmconf | sed -e 's/    <string name="authpassword">\(.*\)<\/string>/\1/')
    authuser=$(grep -w 'authuser' $vmconf | sed -e 's/    <string name="authuser">\(.*\)<\/string>/\1/')
#    injector=$(grep -w 'injector' $vmstore | sed -e 's/    <string name="injector">\(.*\)<\/string>/\1/')
    authid=$(grep -w 'authid' $vmconf | sed -e 's/    <string name="authid">\(.*\)<\/string>/\1/')
    postdest=$(grep -w 'postdest' $vmconf | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/')
    fridastarted=$(grep -w 'fridastarted' $vmstore | awk -F "\"" '{print tolower($4)}')
    patchedpid=$(grep -w 'patchedpid' $vmstore | awk -F "\"" '{print tolower($4)}')
#    fridaver=$(grep -w 'fridaver' $vmstore | awk -F "\"" '{print tolower($4)}')
    openlucky=$(grep -w 'openlucky' $vmconf | awk -F "\"" '{print tolower($4)}')
    rebootminutes=$(grep -w 'rebootminutes' $vmconf | awk -F "\"" '{print tolower($4)}')
    deviceid=$(grep -w 'deviceid' $vmstore | sed -e 's/    <string name="deviceid">\(.*\)<\/string>/\1/')
    websocketurl=$(grep -w 'websocketurl' $vmconf | sed -e 's/    <string name="websocketurl">\(.*\)<\/string>/\1/')
    catchPokemon=$(grep -w 'catchPokemon' $vmconf | awk -F "\"" '{print tolower($4)}')
    launcherver=$(grep -w 'launcherver' $vmstore | awk -F "\"" '{print tolower($4)}')
    rawpostdest=$(grep -w 'rawpostdest' $vmconf | sed -e 's/    <string name="rawpostdest">\(.*\)<\/string>/\1/')
    lat=$(grep -w 'lat' $vmstore | sed -e 's/    <string name="lat">\(.*\)<\/string>/\1/')
    lon=$(grep -w 'lon' $vmstore | sed -e 's/    <string name="lon">\(.*\)<\/string>/\1/')
    catchRare=$(grep -w 'catchRare' $vmconf | awk -F "\"" '{print tolower($4)}')
    overlay=$(grep -w 'overlay' $vmconf | awk -F "\"" '{print tolower($4)}')
# atv
    memTot=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
    memFree=$(cat /proc/meminfo | grep MemFree | awk '{print $2}')
    memAv=$(cat /proc/meminfo | grep MemAvailable | awk '{print $2}')
    memPogo=$(dumpsys meminfo 'com.nianticlabs.pokemongo' | grep -m 1 "TOTAL" | awk '{print $2}')
    memVM=$(dumpsys meminfo 'de.vahrmap.vmapper' | grep -m 1 "TOTAL" | awk '{print $2}')
    cpuSys=$(top -n 1 | grep -m 1 "System" | awk '{print substr($2, 1, length($2)-2)}')
    cpuUser=$(top -n 1 | grep -m 1 "User" | awk '{print substr($2, 1, length($2)-2)}')
    cpuL5=$(dumpsys cpuinfo | grep "Load" | awk '{ print $2 }')
    cpuL10=$(dumpsys cpuinfo | grep "Load" | awk '{ print $4 }')
    cpuLavg=$(dumpsys cpuinfo | grep "Load" | awk '{ print $6 }')
    cpuPogoPct=$(dumpsys cpuinfo | grep 'com.nianticlabs.pokemongo' | awk '{print substr($1, 1, length($1)-1)}')
    cpuVmPct=$(dumpsys cpuinfo | grep 'de.vahrmap.vmapper' | awk '{print substr($1, 1, length($1)-1)}')
    diskSysPct=$(df -h | grep /sbin/.magisk/mirror/system | awk '{print substr($5, 1, length($5)-1)}')
    diskDataPct=$(df -h | grep /sbin/.magisk/mirror/data | awk '{print substr($5, 1, length($5)-1)}')
    numPogo=$(ls -l /sbin/.magisk/mirror/data/app/ | grep com.nianticlabs.pokemongo | wc -l)
# vm.log
    vmc_reboot=$(grep 'Device rebooted' $vmlog | wc -l)
# vmapper.log
    vm_patcher_restart=$(grep 'Patcher (re)started' $vmapperlog | wc -l)
    vm_pogo_restart=$(grep 'Restarting game' $vmapperlog | wc -l)
    vm_crash_dialog=$(grep 'Found crash dialog' $vmapperlog | wc -l)
    vm_injection=$(grep 'Injection successful' $vmapperlog | wc -l)
    vm_injectTimeout=$(grep 'Injection timeout' $vmapperlog | wc -l)
    vm_consent=$(grep 'consent dialog' $vmapperlog | wc -l)
    vm_ws_stop_pogo=$(grep 'WS: stopped app' $vmapperlog | wc -l)
    vm_ws_start_pogo=$(grep 'WS: started' $vmapperlog | wc -l)
    vm_authStart=$(grep 'Starting authentication' $vmapperlog | wc -l)
    vm_authSuccess=$(grep 'Authentication was successful' $vmapperlog | wc -l)
    vm_authFailed=$(grep 'Login failed' $vmapperlog | wc -l)
    vm_Gtoken=$(grep 'New Google auth token is needed' $vmapperlog | wc -l)
    vm_Ptoken=$(grep 'New PTC auth token is needed' $vmapperlog | wc -l)
    vm_PtokenMaster=$(grep 'New PTC master token is needed' $vmapperlog | wc -l)
    vm_died=$(grep 'The service died. We will restart' $vmapperlog | wc -l)


#    set -o posix; set | sort

    curl -k -X POST $WH_RECEIVER_HOST:$WH_RECEIVER_PORT/webhook -H "Accept: application/json" -H "Content-Type: application/json" --data-binary @- <<DATA
{
    "datetime": "${datetime}",
    "RPL": "${RPL}",
    "origin": "${origin}",
    "arch": "${arch}",
    "productmodel": "${productmodel}",
    "vm_script": "${vm_script}",
    "vmapper55": "${vmapper55}",
    "vmapper42": "${vmapper42}",
    "vmwatchdog56": "${vmwatchdog56}",
    "whversion": "${whversion}",
    "pogo": "${pogo}",
    "vmapper": "${vmapper}",
    "pogo_update": "${pogo_update}",
    "vm_update": "${vm_update}",
    "playstore": "${playstore}",
    "wh_enabled": "${wh_enabled}",
    "temperature": "${temperature}",
    "magisk": "${magisk}",
    "magisk_modules": "${magisk_modules}",
    "macw": "${macw}",
    "mace": "${mace}",
    "ip": "${ip}",
    "ext_ip": "${ext_ip}",
    "proxy": "${proxy}",
    "bootdelay": "${bootdelay}",
    "gzip": "${gzip}",
    "betamode": "${betamode}",
    "selinux": "${selinux}",
    "daemon": "${daemon}",
    "authpassword": "${authpassword}",
    "authuser": "${authuser}",
    "injector": "${injector}",
    "authid": "${authid}",
    "postdest": "${postdest}",
    "fridastarted": "${fridastarted}",
    "patchedpid": "${patchedpid}",
    "fridaver": "${fridaver}",
    "openlucky": "${openlucky}",
    "rebootminutes": "${rebootminutes}",
    "deviceid": "${deviceid}",
    "websocketurl": "${websocketurl}",
    "catchPokemon": "${catchPokemon}",
    "launcherver": "${launcherver}",
    "rawpostdest": "${rawpostdest}",
    "lat": "${lat}",
    "lon": "${lon}",
    "catchRare": "${catchRare}",
    "overlay": "${overlay}",
    "memTot": "${memTot}",
    "memFree": "${memFree}",
    "memAv": "${memAv}",
    "memPogo": "${memPogo}",
    "memVM": "${memVM}",
    "cpuSys": "${cpuSys}",
    "cpuUser": "${cpuUser}",
    "cpuL5": "${cpuL5}",
    "cpuL10": "${cpuL10}",
    "cpuLavg": "${cpuLavg}",
    "cpuPogoPct": "${cpuPogoPct}",
    "cpuVmPct": "${cpuVmPct}",
    "diskSysPct": "${diskSysPct}",
    "diskDataPct": "${diskDataPct}",
    "numPogo": "${numPogo}",
    "vmc_reboot": "${vmc_reboot}",
    "vm_patcher_restart": "${vm_patcher_restart}",
    "vm_pogo_restart": "${vm_pogo_restart}",
    "vm_crash_dialog": "${vm_crash_dialog}",
    "vm_injection": "${vm_injection}",
    "vm_injectTimeout": "${vm_injectTimeout}",
    "vm_consent": "${vm_consent}",
    "vm_ws_stop_pogo": "${vm_ws_stop_pogo}",
    "vm_ws_start_pogo": "${vm_ws_start_pogo}",
    "vm_authStart": "${vm_authStart}",
    "vm_authSuccess": "${vm_authSuccess}",
    "vm_authFailed": "${vm_authFailed}",
    "vm_Gtoken": "${vm_Gtoken}",
    "vm_Ptoken": "${vm_Ptoken}",
    "vm_PtokenMaster": "${vm_PtokenMaster}",
    "vm_died": "${vm_died}"

}
DATA
    sleep $SENDING_INTERVAL_SECONDS
  done;
