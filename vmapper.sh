#!/system/bin/sh
# version 2.40

#Create logfile
if [ ! -e /sdcard/vm.log ] ;then
    touch /sdcard/vm.log
fi

# remove old vmapper_conf file if exists
rm -f /sdcard/vmapper_conf

logfile="/sdcard/vm.log"
pdconf="/data/data/com.mad.pogodroid/shared_prefs/com.mad.pogodroid_preferences.xml"
rgcconf="/data/data/de.grennith.rgc.remotegpscontroller/shared_prefs/de.grennith.rgc.remotegpscontroller_preferences.xml"
puser=$(ls -la /data/data/com.mad.pogodroid/|head -n2|tail -n1|awk '{print $3}')
authpassword=$(grep 'auth_password' $rgcconf | sed -e 's/    <string name="auth_password">\(.*\)<\/string>/\1/')
authuser=$(grep 'auth_username' $rgcconf | sed -e 's/    <string name="auth_username">\(.*\)<\/string>/\1/')
origin=$(grep 'post_origin' $rgcconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/')
postdest=$(grep -w 'post_destination' $rgcconf | sed -e 's/    <string name="post_destination">\(.*\)<\/string>/\1/')
pserver=$(grep -v raw "$rgcconf"|awk -F'>' '/post_destination/{print $2}'|awk -F'<' '{print $1}')


reboot_device(){
echo "`date +%Y-%m-%d_%T` Reboot device" >> $logfile
sleep 2
/system/bin/reboot
}


checkrgcconf(){
if ! [[ -s "$rgcconf" ]] ;then
 echo "`date +%Y-%m-%d_%T` RemoteGpsController not configured, we need those settings" >> $logfile
 return 1
fi
}


get_rgc_user(){
checkrgcconf || return 1
user=$(awk -F'>' '/auth_username/{print $2}' "$rgcconf"|awk -F'<' '{print $1}')
pass=$(awk -F'>' '/auth_password/{print $2}' "$rgcconf"|awk -F'<' '{print $1}')
if [[ "$user" ]] ;then
 printf "-u $user:$pass"
fi
}


case "$(uname -m)" in
 aarch64) arch="arm64_v8a";;
 armv8l)  arch="armeabi-v7a";;
esac


checkupdate(){
# $1 = new version
# $2 = installed version
! [[ "$2" ]] && return 0 # for first installs
i=1
#we start at 1 and go until number of . so we can use our counter as awk position
places=$(awk -F. '{print NF+1}' <<< "$1")
while (( "$i" < "$places" )) ;do
 npos=$(awk -v pos=$i -F. '{print $pos}' <<< "$1")
 ipos=$(awk -v pos=$i -F. '{print $pos}' <<< "$2")
 case "$(( $npos - $ipos ))" in
  -*) return 1 ;;
   0) ;;
   *) return 0 ;;
 esac
 i=$((i+1))
 false
done
}


install_vmapper_wizard(){
## pogodroid disable full daemon + stop pogodroid
sed -i 's,\"full_daemon\" value=\"true\",\"full_daemon\" value=\"false\",g' $pdconf
chmod 660 $pdconf
chown $puser:$puser $pdconf
am force-stop com.mad.pogodroid
# let us kill pogo as well
am force-stop com.nianticlabs.pokemongo
echo "`date +%Y-%m-%d_%T` VM install: pogodroid disabled" >> $logfile

## Install vmapper
/system/bin/rm -f /sdcard/Download/vmapper.apk
/system/bin/curl -k -s -L -o /sdcard/Download/vmapper.apk $(get_rgc_user) -H "origin: $origin" "$pserver/mad_apk/vm/download"
/system/bin/pm install -r /sdcard/Download/vmapper.apk
/system/bin/rm -f /sdcard/Download/vmapper.apk
echo "`date +%Y-%m-%d_%T` VM install: vmapper installed" >> $logfile

## At this stage vmapper isn't in magisk db nor had it generated a config folder
#monkey -p de.goldjpg.vmapper -c android.intent.category.LAUNCHER 1
am start -n de.goldjpg.vmapper/.MainActivity
sleep 2
uid=$(stat -c %u /data/data/de.goldjpg.vmapper/)
am force-stop de.goldjpg.vmapper
sleep 2

## Grant su access
sqlite3 /data/adb/magisk.db "INSERT INTO policies (uid,package_name,policy,until,logging,notification) VALUES(\"$uid\",'de.goldjpg.vmapper',2,0,1,1)"
echo "`date +%Y-%m-%d_%T` VM install: vmapper granted su" >> $logfile

## Create config file
create_vmapper_xml

## Start vmapper
am broadcast -n de.goldjpg.vmapper/.RestartService
sleep 5

## add 55vmapper
mount -o remount,rw /system
/system/bin/curl -L -o /system/etc/init.d/55vmapper -k -s https://raw.githubusercontent.com/v-mapper/vmconf/main/55vmapper
chmod +x /system/etc/init.d/55vmapper
mount -o remount,ro /system
echo "`date +%Y-%m-%d_%T` VM install: 55vmapper added" >> $logfile

## Set for reboot device
reboot=1
}


vmapper_wizard(){
#check update vmapper and download from wizard
checkrgcconf || return 1
! [[ "$pserver" ]] && echo "`date +%Y-%m-%d_%T` RemoteGpsController endpoint not configured yet, cannot contact the wizard" >> $logfile && return 1

newver="$(/system/bin/curl -s -k -L $(get_rgc_user) -H "origin: $origin" "$pserver/mad_apk/vm/noarch" | awk '{print substr($1,2); }')"
installedver="$(dumpsys package de.goldjpg.vmapper|awk -F'=' '/versionName/{print $2}'|head -n1 | awk '{print substr($1,2); }')"

if checkupdate "$newver" "$installedver" ;then
 echo "`date +%Y-%m-%d_%T` New vmapper version detected in wizard, updating $installedver=>$newver" >> $logfile
 /system/bin/rm -f /sdcard/Download/vmapper.apk
 until /system/bin/curl -k -s -L -o /sdcard/Download/vmapper.apk $(get_rgc_user) -H "origin: $origin" "$pserver/mad_apk/vm/download" ;do
  /system/bin/rm -f /sdcard/Download/vmapper.apk
  sleep
 done

 # set vmapper to be installed
 vm_install="install"

 else
 vm_install="skip"
 echo "`date +%Y-%m-%d_%T` Vmapper already on latest version" >> $logfile
fi
}


update_vmapper_wizard(){
vmapper_wizard
if [ "$vm_install" = "install" ]; then
 echo "`date +%Y-%m-%d_%T` Installing vmapper" >> $logfile
 # install vmapper
 /system/bin/pm install -r /sdcard/Download/vmapper.apk
 /system/bin/rm -f /sdcard/Download/vmapper.apk
 # new vmapper version in wizzard, so we replace xml
 create_vmapper_xml
 reboot=1
fi
}


pogo_wizard(){
#check pogo and download from wizard
checkrgcconf || return 1
! [[ "$pserver" ]] && echo "`date +%Y-%m-%d_%T` RemoteGpsController endpoint not configured yet, cannot contact the wizard" >> $logfile && return 1

newver="$(/system/bin/curl -s -k -L $(get_rgc_user) -H "origin: $origin" "$pserver/mad_apk/pogo/$arch")"
installedver="$(dumpsys package com.nianticlabs.pokemongo|awk -F'=' '/versionName/{print $2}')"

if checkupdate "$newver" "$installedver" ;then
 echo "`date +%Y-%m-%d_%T` New pogo version detected in wizard, updating $installedver=>$newver" >> $logfile
 /system/bin/rm -f /sdcard/Download/pogo.apk
 until /system/bin/curl -k -s -L -o /sdcard/Download/pogo.apk $(get_rgc_user) -H "origin: $origin" "$pserver/mad_apk/pogo/$arch/download" ;do
  /system/bin/rm -f /sdcard/Download/pogo.apk
  sleep
 done

 # set pogo to be installed
 pogo_install="install"

 else
 pogo_install="skip"
 echo "`date +%Y-%m-%d_%T` PoGo already on latest version" >> $logfile
fi
}


update_pogo_wizard(){
pogo_wizard
if [ "$pogo_install" = "install" ]; then
 echo "`date +%Y-%m-%d_%T` Installing pogo" >> $logfile
 # install pogo
 /system/bin/pm install -r /sdcard/Download/pogo.apk
 /system/bin/rm -f /sdcard/Download/pogo.apk
 reboot=1
fi
}


rgc_wizard(){
#check update rgc and download from wizard
checkrgcconf || return 1
! [[ "$pserver" ]] && echo "RemoteGpsController endpoint not configured yet, cannot contact the wizard" && return 1

newver="$(curl -s -k -L $(get_rgc_user) -H "origin: $origin" "$pserver/mad_apk/rgc/noarch")"
installedver="$(dumpsys package de.grennith.rgc.remotegpscontroller 2>/dev/null|awk -F'=' '/versionName/{print $2}'|head -n1)"

if checkupdate "$newver" "$installedver" ;then
 echo "`date +%Y-%m-%d_%T` New rgc version detected in wizard, updating $installedver=>$newver" >> $logfile
 rm -f /sdcard/Download/RemoteGpsController.apk
 until curl -o /sdcard/Download/RemoteGpsController.apk  -s -k -L $(get_rgc_user) -H "origin: $origin" "$pserver/mad_apk/rgc/download" ;do
  rm -f /sdcard/Download/RemoteGpsController.apk
  sleep 2
 done

 # set rgc to be installed
 rgc_install="install"

 else
 rgc_install="skip"
 echo "`date +%Y-%m-%d_%T` RGC already on latest version" >> $logfile
fi
}


update_rgc_wizard(){
rgc_wizard
if [ "$rgc_install" = "install" ]; then
 echo "`date +%Y-%m-%d_%T` Installing rgc" >> $logfile
 # install rgc
 /system/bin/pm install -r /sdcard/Download/RemoteGpsController.apk
 /system/bin/rm -f /sdcard/Download/RemoteGpsController.apk
 reboot=1
fi
}


update_all(){
rgc_wizard
vmapper_wizard
pogo_wizard
if [ ! -z "$vm_install" ] && [ ! -z "$rgc_install" ] && [ ! -z "$pogo_install" ]; then
    echo "`date +%Y-%m-%d_%T` All updates checked and downloaded if needed" >> $logfile
    if [ "$rgc_install" = "install" ]; then
      echo "`date +%Y-%m-%d_%T` Installing rgc" >> $logfile
      # install rgc
      /system/bin/pm install -r /sdcard/Download/RemoteGpsController.apk
      /system/bin/rm -f /sdcard/Download/RemoteGpsController.apk
      reboot=1
    fi
    if [ "$vm_install" = "install" ]; then
      echo "`date +%Y-%m-%d_%T` Installing vmapper" >> $logfile
      # install vmapper
      /system/bin/pm install -r /sdcard/Download/vmapper.apk
      /system/bin/rm -f /sdcard/Download/vmapper.apk
      # new vmapper version in wizzard, so we replace xml
      create_vmapper_xml
      reboot=1
    fi
    if [ "$pogo_install" = "install" ]; then
      echo "`date +%Y-%m-%d_%T` Installing pogo" >> $logfile
      # install pogo
      /system/bin/pm install -r /sdcard/Download/pogo.apk
      /system/bin/rm -f /sdcard/Download/pogo.apk
      reboot=1
    fi
    if [ "$vm_install" != "install" ] && [ "$pogo_install" != "install" ] && [ "$rgc_install" != "install" ]; then
      echo "`date +%Y-%m-%d_%T` Nothing to install, no reboot" >> $logfile
    fi
fi
}


update_all_no_reboot(){
rgc_wizard
vmapper_wizard
pogo_wizard
if [ ! -z "$vm_install" ] && [ ! -z "$rgc_install" ] && [ ! -z "$pogo_install" ]; then
    echo "`date +%Y-%m-%d_%T` All updates checked and downloaded if needed" >> $logfile
    if [ "$rgc_install" = "install" ]; then
      echo "`date +%Y-%m-%d_%T` Install and start rgc" >> $logfile
      # install rgc
      /system/bin/pm install -r /sdcard/Download/RemoteGpsController.apk
      /system/bin/rm -f /sdcard/Download/RemoteGpsController.apk
      # start rgc
      monkey -p de.grennith.rgc.remotegpscontroller 1
    fi
    if [ "$vm_install" = "install" ]; then
      echo "`date +%Y-%m-%d_%T` Install and start vmapper" >> $logfile
      # kill pogo
      am force-stop com.nianticlabs.pokemongo
      # install vmapper
      /system/bin/pm install -r /sdcard/Download/vmapper.apk
      /system/bin/rm -f /sdcard/Download/vmapper.apk
      # new vmapper version in wizzard, replace xml
      vmapper_xml
      # start vmapper
      am broadcast -n de.goldjpg.vmapper/.RestartService
      # if no pogo update we restart it now
      if [ "$pogo_install" != "install" ];then
        echo "`date +%Y-%m-%d_%T` No pogo update, start pogo" >> $logfile 
        sleep 5
        monkey -p com.nianticlabs.pokemongo -c android.intent.category.LAUNCHER 1
      fi
    fi
    if [ "$pogo_install" = "install" ]; then
      echo "`date +%Y-%m-%d_%T` Install and start pogo" >> $logfile
      # install pogo
      /system/bin/pm install -r /sdcard/Download/pogo.apk
      /system/bin/rm -f /sdcard/Download/pogo.apk
      # start pogo
      monkey -p com.nianticlabs.pokemongo -c android.intent.category.LAUNCHER 1
    fi
    if [ "$vm_install" != "install" ] && [ "$pogo_install" != "install" ] && [ "$rgc_install" != "install" ]; then
      echo "`date +%Y-%m-%d_%T` Nothing to install" >> $logfile
    fi
fi
}


vmapper_xml(){
vmconf="/data/data/de.goldjpg.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.goldjpg.vmapper/|head -n2|tail -n1|awk '{print $3}')

/system/bin/curl -k -s -L -o $vmconf $(get_rgc_user) -H "origin: $origin" "$pserver/vm_conf"

chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf
echo "`date +%Y-%m-%d_%T` Vmapper config.xml (re)created" >> $logfile
}


create_vmapper_xml(){
vmapper_xml
reboot=1
}


create_vmapper_xml_no_reboot(){
am force-stop com.nianticlabs.pokemongo
am force-stop de.goldjpg.vmapper
vmapper_xml
am broadcast -n de.goldjpg.vmapper/.RestartService
sleep 5
monkey -p com.nianticlabs.pokemongo -c android.intent.category.LAUNCHER 1
}


pd_to_vm(){
vmconf="/data/data/de.goldjpg.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.goldjpg.vmapper/|head -n2|tail -n1|awk '{print $3}')
# disable pd daemon
sed -i 's,\"full_daemon\" value=\"true\",\"full_daemon\" value=\"false\",g' $rgcconf
chmod 660 $rgcconf
chown $puser:$puser $rgcconf

# enable vm daemon
sed -i 's,\"daemon\" value=\"false\",\"daemon\" value=\"true\",g' $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf

# kill pd & start vm
am force-stop com.mad.pogodroid
am broadcast -n de.goldjpg.vmapper/.RestartService
sleep 5

echo "`date +%Y-%m-%d_%T` VM daemon enable and PD daemon disable" >> $logfile

reboot=1
}


vm_to_pd(){
vmconf="/data/data/de.goldjpg.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.goldjpg.vmapper/|head -n2|tail -n1|awk '{print $3}')
# disable vm daemon
sed -i 's,\"daemon\" value=\"true\",\"daemon\" value=\"false\",g' $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf

# enable pd daemon
sed -i 's,\"full_daemon\" value=\"false\",\"full_daemon\" value=\"true\",g' $pdconf
chmod 660 $pdconf
chown $puser:$puser $pdconf

#kill vm & start pd
am force-stop de.goldjpg.vmapper
sleep 2
monkey -p com.mad.pogodroid 1
sleep 2
am start -n com.mad.pogodroid/.SplashPermissionsActivity
sleep 5

echo "`date +%Y-%m-%d_%T` VM daemon disable and PD daemon enable" >> $logfile

reboot=1
}


for i in "$@" ;do
 case "$i" in
 -ivw) install_vmapper_wizard ;;
 -uvw) update_vmapper_wizard ;;
 -upw) update_pogo_wizard ;;
 -urw) update_rgc_wizard ;;
 -ua) update_all ;;
 -uanr) update_all_no_reboot ;;
 -uvx) create_vmapper_xml ;;
 -uvxnr) create_vmapper_xml_no_reboot ;;
 -spv) pd_to_vm ;;
 -svp) vm_to_pd ;;
 esac
done


(( $reboot )) && reboot_device
exit
