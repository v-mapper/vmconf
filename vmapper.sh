#!/system/bin/sh
# version 2.40

#Create logfile
if [ ! -e /sdcard/vm.log ] ;then
    touch /sdcard/vm.log
fi

# remove old vmapper_conf file if exists
rm -f /sdcard/vmapper_conf

logfile="/sdcard/vm.log"
puser=$(ls -la /data/data/com.mad.pogodroid/|head -n2|tail -n1|awk '{print $3}')
pdconf="/data/data/com.mad.pogodroid/shared_prefs/com.mad.pogodroid_preferences.xml"
vmconfV6="/data/data/de.goldjpg.vmapper/shared_prefs/config.xml"
vmconfV7="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
lastResort="/sdcard/vm_last_resort"

# stderr to logfile
exec 2>> $logfile

# add vmapper.sh command to log
echo "" >> $logfile
echo "`date +%Y-%m-%d_%T` ## Executing vmapper.sh $@" >> $logfile

# prevent vmconf causing reboot loop
if [ $(cat /sdcard/vm.log | grep `date +%Y-%m-%d` | grep rebooted | wc -l) -gt 20 ] ;then
echo "`date +%Y-%m-%d_%T` Device rebooted over 20 times today, vmapper.sh signing out, see you tomorrow"  >> $logfile
exit 1
fi

# Get MADmin credentials and origin
if [ -f "$vmconfV7" ] && [ ! -z $(grep -w 'origin' $vmconfV7 | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/') ] ; then
  server=$(grep -w 'postdest' $vmconfV7 | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/')
  authuser=$(grep -w 'authuser' $vmconfV7 | sed -e 's/    <string name="authuser">\(.*\)<\/string>/\1/')
  authpassword=$(grep -w 'authpassword' $vmconfV7 | sed -e 's/    <string name="authpassword">\(.*\)<\/string>/\1/')
  origin=$(grep -w 'origin' $vmconfV7 | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/')
  echo "`date +%Y-%m-%d_%T` Using vahrmap.vmapper settings" >> $logfile
elif [ -f "$vmconfV6" ] && [ ! -z $(grep -w 'origin' $vmconfV6 | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/') ]; then
  server=$(grep -w 'postdest' $vmconfV6 | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/')
  authuser=$(grep -w 'authuser' $vmconfV6 | sed -e 's/    <string name="authuser">\(.*\)<\/string>/\1/')
  authpassword=$(grep -w 'authpassword' $vmconfV6 | sed -e 's/    <string name="authpassword">\(.*\)<\/string>/\1/')
  origin=$(grep -w 'origin' $vmconfV6 | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/')
  echo "`date +%Y-%m-%d_%T` Using goldjpg.vmapper settings" >> $logfile
elif [ -f "$pdconf" ] && [ ! -z $(grep -w 'post_origin' $pdconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/') ]; then
  server=$(grep -w 'post_destination' $pdconf | sed -e 's/    <string name="post_destination">\(.*\)<\/string>/\1/')
  authuser=$(grep -w 'auth_username' $pdconf | sed -e 's/    <string name="auth_username">\(.*\)<\/string>/\1/')
  authpassword=$(grep -w 'auth_password' $pdconf | sed -e 's/    <string name="auth_password">\(.*\)<\/string>/\1/')
  origin=$(grep -w 'post_origin' $pdconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/')
  echo "`date +%Y-%m-%d_%T` Using pogodroid settings" >> $logfile
elif [ -f "$lastResort" ]; then
  server=$(awk '{print $1}' "$lastResort")
  authuser=$(awk '{print $2}' "$lastResort")
  authpassword=$(awk '{print $3}' "$lastResort")
  origin=$(awk '{print $4}' "$lastResort")
  echo "`date +%Y-%m-%d_%T` Using settings stored in /sdcard/vm_last_resort"  >> $logfile
else
  echo "`date +%Y-%m-%d_%T` No settings found to connect to MADmin, exiting vmapper.sh" >> $logfile
  exit 1
fi

# store settings as last resort
if [[ ! -z ${server+x} || ! -z ${authuser+x} || ! -z ${authpassword+x} || ! -z ${origin+x} ]] ; then
/system/bin/rm -f "$lastResort"
touch "$lastResort"
echo "$server $authuser $authpassword $origin" >> "$lastResort"
fi

reboot_device(){
echo "`date +%Y-%m-%d_%T` Reboot device" >> $logfile
sleep 2
/system/bin/reboot
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
/system/bin/curl -k -s -L -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download"
/system/bin/pm install -r /sdcard/Download/vmapper.apk
/system/bin/rm -f /sdcard/Download/vmapper.apk
echo "`date +%Y-%m-%d_%T` VM install: vmapper installed" >> $logfile

## At this stage vmapper isn't in magisk db nor had it generated a config folder
am start -n de.vahrmap.vmapper/.MainActivity
sleep 2
uid=$(stat -c %u /data/data/de.vahrmap.vmapper/)
am force-stop de.vahrmap.vmapper
sleep 2

## Grant su access
sqlite3 /data/adb/magisk.db "INSERT INTO policies (uid,package_name,policy,until,logging,notification) VALUES(\"$uid\",'de.vahrmap.vmapper',2,0,1,1)"
echo "`date +%Y-%m-%d_%T` VM install: vmapper granted su" >> $logfile

## Create config file
create_vmapper_xml

## Start vmapper
am broadcast -n de.vahrmap.vmapper/.RestartService
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
! [[ "$server" ]] && echo "`date +%Y-%m-%d_%T` no MADmin endpoint configured, cannot contact the wizard" >> $logfile && return 1

newver="$(/system/bin/curl -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/noarch" | awk '{print substr($1,2); }')"
installedver="$(dumpsys package de.vahrmap.vmapper|awk -F'=' '/versionName/{print $2}'|head -n1 | awk '{print substr($1,2); }')"

if [ "$installedver" = "" ] ;then
installedver="$(dumpsys package de.goldjpg.vmapper|awk -F'=' '/versionName/{print $2}'|head -n1 | awk '{print substr($1,2); }')"
fi

if [ "$newver" = "" ] ;then
vm_install="skip"
echo "`date +%Y-%m-%d_%T` Vmapper not found in MADmin, skipping version check" >> $logfile
else
  if checkupdate "$newver" "$installedver" ;then
    vold="$(echo $installedver | awk '{print substr($1,1,1); }')"
    vnew="$(echo $newver | awk '{print substr($1,1,1); }')"
    if [[ "$vold" = 6 ]] && [[ "$vnew" = 7 ]] ;then
          echo "`date +%Y-%m-%d_%T` New vmapper version detected in wizard, $installedver=>$newver, oeps we uninstall and install" >> $logfile
          # Its not a downgrade, but this should work and we cancel the the default update routine
		  am force-stop de.goldjpg.vmapper
		  /system/bin/pm uninstall de.goldjpg.vmapper
		  sqlite3 /data/adb/magisk.db "DELETE FROM policies WHERE package_name = 'de.goldjpg.vmapper'"
          downgrade_vmapper_wizard
          vm_install="skip"
        else
      echo "`date +%Y-%m-%d_%T` New vmapper version detected in wizard, updating $installedver=>$newver" >> $logfile
      /system/bin/rm -f /sdcard/Download/vmapper.apk
      until /system/bin/curl -k -s -L -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download" ;do
       /system/bin/rm -f /sdcard/Download/vmapper.apk
       sleep
      done

      # set vmapper to be installed
      vm_install="install"
    fi
  else
    vm_install="skip"
    echo "`date +%Y-%m-%d_%T` Vmapper already on latest version" >> $logfile
  fi
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


downgrade_vmapper_wizard(){
# remove vmapper
am force-stop com.nianticlabs.pokemongo
am force-stop de.vahrmap.vmapper
sleep 2
/system/bin/pm uninstall de.vahrmap.vmapper
echo "`date +%Y-%m-%d_%T` VM downgrade: vmapper removed" >> $logfile

# install vmapper from wizard
/system/bin/rm -f /sdcard/Download/vmapper.apk
/system/bin/curl -k -s -L -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download"
/system/bin/pm install -r /sdcard/Download/vmapper.apk
/system/bin/rm -f /sdcard/Download/vmapper.apk
echo "`date +%Y-%m-%d_%T` VM downgrade: vmapper installed" >> $logfile

# grant SU
am start -n de.vahrmap.vmapper/.MainActivity
sleep 5
uid=$(stat -c %u /data/data/de.vahrmap.vmapper/)
am force-stop de.vahrmap.vmapper
sleep 2
sqlite3 /data/adb/magisk.db "INSERT INTO policies (uid,package_name,policy,until,logging,notification) VALUES(\"$uid\",'de.vahrmap.vmapper',2,0,1,1)"
echo "`date +%Y-%m-%d_%T` VM downgrade: vmapper granted SU access" >> $logfile

# (re)create xml and start vmapper+pogo
create_vmapper_xml_no_reboot
echo "`date +%Y-%m-%d_%T` VM downgrade: xml re-created and vmapper+pogo re-started" >> $logfile
}


pogo_wizard(){
#check pogo and download from wizard
! [[ "$server" ]] && echo "`date +%Y-%m-%d_%T` no MADmin endpoint configured, cannot contact the wizard" >> $logfile && return 1

if [ -z ${force_pogo_update+x} ]; then
  newver="$(/system/bin/curl -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/pogo/$arch")"
else
  newver="1.599.1"
fi
installedver="$(dumpsys package com.nianticlabs.pokemongo|awk -F'=' '/versionName/{print $2}')"

if checkupdate "$newver" "$installedver" ;then
 echo "`date +%Y-%m-%d_%T` New pogo version detected in wizard, updating $installedver=>$newver" >> $logfile
 /system/bin/rm -f /sdcard/Download/pogo.apk
 until /system/bin/curl -k -s -L -o /sdcard/Download/pogo.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/pogo/$arch/download" ;do
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
! [[ "$server" ]] && echo "`date +%Y-%m-%d_%T` no MADmin endpoint configured, cannot contact the wizard" >> $logfile && return 1

newver="$(curl -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/rgc/noarch")"
installedver="$(dumpsys package de.grennith.rgc.remotegpscontroller 2>/dev/null|awk -F'=' '/versionName/{print $2}'|head -n1)"

if checkupdate "$newver" "$installedver" ;then
 echo "`date +%Y-%m-%d_%T` New rgc version detected in wizard, updating $installedver=>$newver" >> $logfile
 rm -f /sdcard/Download/RemoteGpsController.apk
 until curl -o /sdcard/Download/RemoteGpsController.apk  -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/rgc/download" ;do
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
      echo "`date +%Y-%m-%d_%T` Install vmapper and recreate xml" >> $logfile
      # kill pogo
      am force-stop com.nianticlabs.pokemongo
      # install vmapper
      /system/bin/pm install -r /sdcard/Download/vmapper.apk
      /system/bin/rm -f /sdcard/Download/vmapper.apk
      # new vmapper version in wizzard, replace xml
      vmapper_xml
      # if no pogo update we restart both now
      if [ "$pogo_install" != "install" ];then
        echo "`date +%Y-%m-%d_%T` No pogo update, starting vmapper+pogo" >> $logfile
        am broadcast -n de.vahrmap.vmapper/.RestartService        
        sleep 5
        monkey -p com.nianticlabs.pokemongo -c android.intent.category.LAUNCHER 1
      fi
    fi
    if [ "$pogo_install" = "install" ]; then
      echo "`date +%Y-%m-%d_%T` Install pogo, restart vmapper and start pogo" >> $logfile
      # install pogo
      /system/bin/pm install -r /sdcard/Download/pogo.apk
      /system/bin/rm -f /sdcard/Download/pogo.apk
      # restart vmapper + start pogo
      am broadcast -n de.vahrmap.vmapper/.RestartService        
      sleep 5
      monkey -p com.nianticlabs.pokemongo -c android.intent.category.LAUNCHER 1
    fi
    if [ "$vm_install" != "install" ] && [ "$pogo_install" != "install" ] && [ "$rgc_install" != "install" ]; then
      echo "`date +%Y-%m-%d_%T` Nothing to install" >> $logfile
    fi
fi
}


vmapper_xml(){
vmconf="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.vahrmap.vmapper/|head -n2|tail -n1|awk '{print $3}')

/system/bin/curl -k -s -L -o $vmconf -u $authuser:$authpassword -H "origin: $origin" "$server/vm_conf"

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
am force-stop de.vahrmap.vmapper
vmapper_xml
am broadcast -n de.vahrmap.vmapper/.RestartService
sleep 5
monkey -p com.nianticlabs.pokemongo -c android.intent.category.LAUNCHER 1
}


pd_to_vm(){
vmconf="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.vahrmap.vmapper/|head -n2|tail -n1|awk '{print $3}')
# disable pd daemon
sed -i 's,\"full_daemon\" value=\"true\",\"full_daemon\" value=\"false\",g' $pdconf
chmod 660 $pdconf
chown $puser:$puser $pdconf

# enable vm daemon
sed -i 's,\"daemon\" value=\"false\",\"daemon\" value=\"true\",g' $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf

# kill pd & start vm
am force-stop com.mad.pogodroid
am broadcast -n de.vahrmap.vmapper/.RestartService
sleep 5

echo "`date +%Y-%m-%d_%T` VM daemon enable and PD daemon disable" >> $logfile

reboot=1
}


vm_to_pd(){
vmconf="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.vahrmap.vmapper/|head -n2|tail -n1|awk '{print $3}')
# disable vm daemon
sed -i 's,\"daemon\" value=\"true\",\"daemon\" value=\"false\",g' $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf

# enable pd daemon
sed -i 's,\"full_daemon\" value=\"false\",\"full_daemon\" value=\"true\",g' $pdconf
chmod 660 $pdconf
chown $puser:$puser $pdconf

#kill vm & start pd
am force-stop de.vahrmap.vmapper
sleep 2
monkey -p com.mad.pogodroid 1
sleep 2
am start -n com.mad.pogodroid/.SplashPermissionsActivity
sleep 5

echo "`date +%Y-%m-%d_%T` VM daemon disable and PD daemon enable" >> $logfile

reboot=1
}


force_pogo_update(){
force_pogo_update=true
}

for i in "$@" ;do
 case "$i" in
 -ivw) install_vmapper_wizard ;;
 -uvw) update_vmapper_wizard ;;
 -dvw) downgrade_vmapper_wizard ;;
 -upw) update_pogo_wizard ;;
 -urw) update_rgc_wizard ;;
 -ua) update_all ;;
 -uanr) update_all_no_reboot ;;
 -uvx) create_vmapper_xml ;;
 -uvxnr) create_vmapper_xml_no_reboot ;;
 -spv) pd_to_vm ;;
 -svp) vm_to_pd ;;
 -fp) force_pogo_update ;;
 esac
done


(( $reboot )) && reboot_device
exit
