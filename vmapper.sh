#!/system/bin/sh
# version 3.00

#Create logfile
if [ ! -e /sdcard/vm.log ] ;then
    touch /sdcard/vm.log
fi

# remove old vmapper_conf file if exists
rm -f /sdcard/vmapper_conf

logfile="/sdcard/vm.log"
puser=$(ls -la /data/data/com.mad.pogodroid/|head -n2|tail -n1|awk '{print $3}')
pdconf="/data/data/com.mad.pogodroid/shared_prefs/com.mad.pogodroid_preferences.xml"
ruser=$(ls -la /data/data/de.grennith.rgc.remotegpscontroller/|head -n2|tail -n1|awk '{print $3}')
rgcconf="/data/data/de.grennith.rgc.remotegpscontroller/shared_prefs/de.grennith.rgc.remotegpscontroller_preferences.xml"
vmconfV6="/data/data/de.goldjpg.vmapper/shared_prefs/config.xml"
vmconfV7="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
lastResort="/sdcard/vm_last_resort"

# stderr to logfile
exec 2>> $logfile

# add vmapper.sh command to log
echo "" >> $logfile
echo "`date +%Y-%m-%d_%T` ## Executing vmapper.sh $@" >> $logfile

#wait on internet
until ping -c1 8.8.8.8 >/dev/null 2>/dev/null; do
    sleep 10
done
echo "`date +%Y-%m-%d_%T` Internet connection available" >> $logfile

#download latest vmapper.sh and 55vmapper
old55=$(head -5 /system/etc/init.d/55vmapper | grep '# version' | awk '{ print $NF }')
oldsh=$(grep '# version' /system/bin/vmapper.sh | awk '{ print $NF }')

mount -o remount,rw /system
if [ -f /sdcard/useVMCdevelop ]; then
  /system/bin/curl -s -k -L -o /system/bin/vmapper.sh https://raw.githubusercontent.com/v-mapper/vmconf/develop/vmapper.sh
  chmod +x /system/bin/vmapper.sh
  /system/bin/curl -s -k -L -o /system/etc/init.d/55vmapper https://raw.githubusercontent.com/v-mapper/vmconf/develop/55vmapper
  chmod +x /system/etc/init.d/55vmapper
else
  /system/bin/curl -s -k -L -o /system/bin/vmapper.sh https://raw.githubusercontent.com/v-mapper/vmconf/main/vmapper.sh
  chmod +x /system/bin/vmapper.sh
  /system/bin/curl -s -k -L -o /system/etc/init.d/55vmapper https://raw.githubusercontent.com/v-mapper/vmconf/main/55vmapper
  chmod +x /system/etc/init.d/55vmapper
fi
mount -o remount,ro /system

new55=$(head -5 /system/etc/init.d/55vmapper | grep '# version' | awk '{ print $NF }')
newsh=$(grep '# version' /system/bin/vmapper.sh | awk '{ print $NF }')

if [[ $old55 != $new55 || $oldsh != $newsh ]] ;then
  echo "`date +%Y-%m-%d_%T` 55vmapper $old55=>$new55, vmapper.sh $oldsh=>$newsh" >> $logfile
fi

# check if vmapper.sh was already on latest else restart command
if [[ $oldsh != $newsh ]] ;then
  echo "`date +%Y-%m-%d_%T` vmapper.sh has been updated, restarting script" >> $logfile
  folder=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
  $folder/$(basename $0) $@ && exit
fi


# check rgc deactivated and vmapper not installed (properly) or empty config.xml
if [[ $(grep -w 'boot_startup' $rgcconf | awk -F "\"" '{print $4}') == "false" ]] ;then
  if [ ! -f "$vmconfV7" ] || [ -z $(grep -w 'websocketurl' $vmconfV7 | sed -e 's/    <string name="websocketurl">\(.*\)<\/string>/\1/') ] ; then
    sed -i 's,\"autostart_services\" value=\"false\",\"autostart_services\" value=\"true\",g' $rgcconf
    sed -i 's,\"boot_startup\" value=\"false\",\"boot_startup\" value=\"true\",g' $rgcconf
    chmod 660 $rgcconf
    chown $ruser:$ruser $rgcconf
    monkey -p de.grennith.rgc.remotegpscontroller 1
    reboot=1
    echo "`date +%Y-%m-%d_%T` VMconf check: rgc deactivated and either vmapper was not installed or config was empty, enabled rgc settings and started rgc " >> $logfile
  fi
fi

# check vmapper mockgps active and rgc active
if [ -f "$vmconfV7" ] && [[ $(grep -w 'mockgps' $vmconfV7 | awk -F "\"" '{print $4}') == "true" ]] && [[ $(grep -w 'boot_startup' $rgcconf | awk -F "\"" '{print $4}') == "true" ]] ;then
# echo "deactivate rgc settings and kill rgc"
am force-stop de.grennith.rgc.remotegpscontroller
sed -i 's,\"autostart_services\" value=\"true\",\"autostart_services\" value=\"false\",g' $rgcconf
sed -i 's,\"boot_startup\" value=\"true\",\"boot_startup\" value=\"false\",g' $rgcconf
chmod 660 $rgcconf
chown $ruser:$ruser $rgcconf
echo "`date +%Y-%m-%d_%T` VMconf check: vmapper mockgps was active as well as rgc, disabled rgc settings and stopped rgc" >> $logfile
fi

# check vmapper useApi active and rgc active
if [ -f "$vmconfV7" ] && [[ $(grep -w 'useApi' $vmconfV7 | awk -F "\"" '{print $4}') == "true" ]] && [[ $(grep -w 'boot_startup' $rgcconf | awk -F "\"" '{print $4}') == "true" ]] ;then
#  echo "deactivate rgc settings and kill rgc"
am force-stop de.grennith.rgc.remotegpscontroller
sed -i 's,\"autostart_services\" value=\"true\",\"autostart_services\" value=\"false\",g' $rgcconf
sed -i 's,\"boot_startup\" value=\"true\",\"boot_startup\" value=\"false\",g' $rgcconf
chmod 660 $rgcconf
chown $ruser:$ruser $rgcconf
echo "`date +%Y-%m-%d_%T` VMconf check: vmapper useApi was active as well as rgc, disabled rgc settings and stopped rgc" >> $logfile
fi

# check rgc deactivated and vmapper mockgps disabled
if [[ $(grep -w 'boot_startup' $rgcconf | awk -F "\"" '{print $4}') == "false" ]] && [[ $(grep -w 'mockgps' $vmconfV7 | awk -F "\"" '{print $4}') == "false" ]] ;then
sed -i 's,\"mockgps\" value=\"false\",\"mockgps\" value=\"true\",g' $vmconfV7
am force-stop de.vahrmap.vmapper
am broadcast -n de.vahrmap.vmapper/.RestartService
echo "`date +%Y-%m-%d_%T` VMconf check: rgc deactivated and vmapper mockgps disabled, enabled mockgps and restarted vmapper" >> $logfile
fi

# ensure vmapper mockgps is active for useApi
if [ -f "$vmconfV7" ] && [[ $(grep -w 'useApi' $vmconfV7 | awk -F "\"" '{print $4}') == "true" ]] && [[ $(grep -w 'mockgps' $vmconfV7 | awk -F "\"" '{print $4}') == "false" ]] ;then
sed -i 's,\"mockgps\" value=\"false\",\"mockgps\" value=\"true\",g' $vmconfV7
am force-stop de.vahrmap.vmapper
am broadcast -n de.vahrmap.vmapper/.RestartService
echo "`date +%Y-%m-%d_%T` VMconf check: vmapper useApi activated and vmapper mockgps disabled, enabled mockgps and restarted vmapper" >> $logfile
fi

# check owner of vmapper config.xml
vmuser=$(ls -la /data/data/de.vahrmap.vmapper/|head -n2|tail -n1|awk '{print $3}')
vmconfiguser=$(ls -la /data/data/de.vahrmap.vmapper/shared_prefs/config.xml |head -n2|tail -n1|awk '{print $3}')
if [ -f "$vmconfV7" ] && [[ $vmuser != $vmconfiguser ]] ;then
chmod 660 $vmconfV7
chown $vmuser:$vmuser $vmconfV7
am force-stop de.vahrmap.vmapper
am broadcast -n de.vahrmap.vmapper/.RestartService
echo "`date +%Y-%m-%d_%T` VMconf check: vmapper config.xml user incorrect, changed it and restarted vmapper" >> $logfile
fi


# Get MADmin credentials and origin
if [ -f "$vmconfV7" ] && [ ! -z $(grep -w 'postdest' $vmconfV7 | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/') ] ; then
  server=$(grep -w 'postdest' $vmconfV7 | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/')
  authuser=$(grep -w 'authuser' $vmconfV7 | sed -e 's/    <string name="authuser">\(.*\)<\/string>/\1/')
  authpassword=$(grep -w 'authpassword' $vmconfV7 | sed -e 's/    <string name="authpassword">\(.*\)<\/string>/\1/')
  origin=$(grep -w 'origin' $vmconfV7 | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/')
  echo "`date +%Y-%m-%d_%T` Using vahrmap.vmapper settings" >> $logfile
elif [ -f "$vmconfV6" ] && [ ! -z $(grep -w 'postdest' $vmconfV6 | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/') ]; then
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
  echo "No settings found to connect to MADmin, exiting vmapper.sh"
  exit 1
fi

# verify endpoint and store settings as last resort
statuscode=$(/system/bin/curl -k -s -L --fail --show-error -o /dev/null -u $authuser:$authpassword -H "origin: $origin" "$server/vm_conf" -w '%{http_code}')
if [ $statuscode != 200 ] ;then
  echo "Unable to reach MADmin endpoint, status code $statuscode, exit vmapper.sh"
  echo "`date +%Y-%m-%d_%T` Unable to reach MADmin endpoint, status code $statuscode, exiting vmapper.sh" >> $logfile
  exit 1
else
  /system/bin/rm -f "$lastResort"
  touch "$lastResort"
  echo "$server $authuser $authpassword $origin" >> "$lastResort"
fi

# prevent vmconf causing reboot loop. Bypass check by executing, vmapper.sh -nrc -whatever
if [ $1 != "-nrc" ] ;then
  if [ $(cat /sdcard/vm.log | grep `date +%Y-%m-%d` | grep rebooted | wc -l) -gt 20 ] ;then
  echo "`date +%Y-%m-%d_%T` Device rebooted over 20 times today, vmapper.sh signing out, see you tomorrow"  >> $logfile
  echo "Device rebooted over 20 times today, vmapper.sh signing out, see you tomorrow.....add -nrc to job or (re)move /sdcard/vm.log then try again"
  exit 1
  fi
fi

# temp check on v6 in MADmin => exit
newver="$(/system/bin/curl -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/noarch" | awk '{print substr($1,2); }')"
vnew="$(echo $newver | awk '{print substr($1,1,1); }')"
if [[ "$vnew" = 6 ]] ;then
echo "`date +%Y-%m-%d_%T` Vmapper $newver detected in wizard, exiting vmapper.sh" >> $logfile
exit 1
fi


# set hostname = origin, wait till next reboot for it to take effect
if [ $(cat /system/build.prop | grep net.hostname | wc -l) = 0 ]; then
  echo "`date +%Y-%m-%d_%T` No hostname set, setting it to $origin" >> $logfile
  mount -o remount,rw /system
  echo "net.hostname=$origin" >> /system/build.prop
  mount -o remount,ro /system
else
  hostname=$(grep net.hostname /system/build.prop | awk 'BEGIN { FS = "=" } ; { print $2 }')
  if [[ $hostname != $origin ]]; then
    echo "`date +%Y-%m-%d_%T` Changing hostname, from $hostname to $origin" >> $logfile
    mount -o remount,rw /system
    sed -i -e "s/^net.hostname=.*/net.hostname=$origin/g" /system/build.prop
    mount -o remount,ro /system
  fi
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
# disable pd autoupdate
touch /sdcard/disableautopogodroidupdate

## Install vmapper
/system/bin/rm -f /sdcard/Download/vmapper.apk
/system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download"
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
/system/bin/curl -L --fail --show-error -o /system/etc/init.d/55vmapper -k -s https://raw.githubusercontent.com/v-mapper/vmconf/main/55vmapper
chmod +x /system/etc/init.d/55vmapper
mount -o remount,ro /system
echo "`date +%Y-%m-%d_%T` VM install: 55vmapper added" >> $logfile

## check vmapper mockgps active
if [ -f "$vmconfV7" ] && [[ $(grep -w 'mockgps' $vmconfV7 | awk -F "\"" '{print $4}') == "true" ]] ;then
rgc_to_vm
fi

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
      until /system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download" ;do
       /system/bin/rm -f /sdcard/Download/vmapper.apk
       sleep 2
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
 if [[ -f /sdcard/disableautoxml ]] ;then
   echo "`date +%Y-%m-%d_%T` Skipping update config.xml" >> $logfile
 else
   create_vmapper_xml
 fi
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
/system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download"
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
 until /system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/pogo.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/pogo/$arch/download" ;do
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


downgrade_pogo_wizard_no_reboot(){
/system/bin/rm -f /sdcard/Download/pogo.apk
/system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/pogo.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/pogo/$arch/download"
echo "`date +%Y-%m-%d_%T` PoGo downgrade: pogo downloaded from wizard" >> $logfile
/system/bin/pm uninstall com.nianticlabs.pokemongo
echo "`date +%Y-%m-%d_%T` PoGo downgrade: pogo removed" >> $logfile
/system/bin/pm install -r /sdcard/Download/pogo.apk
/system/bin/rm -f /sdcard/Download/pogo.apk
echo "`date +%Y-%m-%d_%T` PoGo downgrade: pogo installed" >> $logfile
monkey -p com.nianticlabs.pokemongo -c android.intent.category.LAUNCHER 1
echo "`date +%Y-%m-%d_%T` PoGo downgrade: pogo started" >> $logfile
}


rgc_wizard(){
#check update rgc and download from wizard
! [[ "$server" ]] && echo "`date +%Y-%m-%d_%T` no MADmin endpoint configured, cannot contact the wizard" >> $logfile && return 1

newver="$(curl -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/rgc/noarch")"
installedver="$(dumpsys package de.grennith.rgc.remotegpscontroller 2>/dev/null|awk -F'=' '/versionName/{print $2}'|head -n1)"

if checkupdate "$newver" "$installedver" ;then
 echo "`date +%Y-%m-%d_%T` New rgc version detected in wizard, updating $installedver=>$newver" >> $logfile
 rm -f /sdcard/Download/RemoteGpsController.apk
 until curl -o /sdcard/Download/RemoteGpsController.apk  -s -k -L --fail --show-error -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/rgc/download" ;do
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
      if [[ -f /sdcard/disableautoxml ]] ;then
        echo "`date +%Y-%m-%d_%T` Skipping update config.xml" >> $logfile
      else
        create_vmapper_xml
      fi
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
      if [[ -f /sdcard/disableautoxml ]] ;then
        echo "`date +%Y-%m-%d_%T` Skipping update config.xml" >> $logfile
      else
        vmapper_xml
      fi
      # if no pogo update we restart both now
      if [ "$pogo_install" != "install" ];then
        echo "`date +%Y-%m-%d_%T` No pogo update, starting vmapper+pogo" >> $logfile
        am force-stop de.vahrmap.vmapper
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
      am force-stop de.vahrmap.vmapper
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

/system/bin/curl -k -s -L --fail --show-error -o $vmconf -u $authuser:$authpassword -H "origin: $origin" "$server/vm_conf"

chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf
echo "`date +%Y-%m-%d_%T` Vmapper config.xml (re)created" >> $logfile
}


create_vmapper_xml(){
vmapper_xml
reboot=1
}


create_vmapper_xml_no_reboot(){
vmapper_xml
echo "`date +%Y-%m-%d_%T` Restarting vmapper and pogo" >> $logfile
am force-stop com.nianticlabs.pokemongo
am force-stop de.vahrmap.vmapper
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
# disable pd autoupdate
touch /sdcard/disableautopogodroidupdate

# enable vm daemon
sed -i 's,\"daemon\" value=\"false\",\"daemon\" value=\"true\",g' $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf

# kill pd & start vm
am force-stop com.mad.pogodroid
am force-stop de.vahrmap.vmapper
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
# enable pd autoupdate
rm -f /sdcard/disableautopogodroidupdate

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

rgc_to_vm(){
vmconf="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.vahrmap.vmapper/|head -n2|tail -n1|awk '{print $3}')
# disable rgc
sed -i 's,\"autostart_services\" value=\"true\",\"autostart_services\" value=\"false\",g' $rgcconf
sed -i 's,\"boot_startup\" value=\"true\",\"boot_startup\" value=\"false\",g' $rgcconf
chmod 660 $rgcconf
chown $ruser:$ruser $rgcconf
# disable rgc autoupdate
touch /sdcard/disableautorgcupdate

# enable vm mockgps
sed -i 's,\"mockgps\" value=\"false\",\"mockgps\" value=\"true\",g' $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf

# kill rgc & restart vm
am force-stop de.grennith.rgc.remotegpscontroller
am force-stop de.vahrmap.vmapper
am broadcast -n de.vahrmap.vmapper/.RestartService
sleep 5

echo "`date +%Y-%m-%d_%T` VM mockgps enable and RGC disable" >> $logfile

reboot=1
}

vm_to_rgc(){
vmconf="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.vahrmap.vmapper/|head -n2|tail -n1|awk '{print $3}')
# disable vm mockgps AND useApi
sed -i 's,\"mockgps\" value=\"true\",\"mockgps\" value=\"false\",g' $vmconf
sed -i 's,\"useApi\" value=\"true\",\"useApi\" value=\"false\",g' $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf

# enable rgc
sed -i 's,\"autostart_services\" value=\"false\",\"autostart_services\" value=\"true\",g' $rgcconf
sed -i 's,\"boot_startup\" value=\"false\",\"boot_startup\" value=\"true\",g' $rgcconf
chmod 660 $rgcconf
chown $ruser:$ruser $rgcconf
# enable rgc autoupdate
rm -f /sdcard/disableautorgcupdate

# restart vm & start rgc
am force-stop de.vahrmap.vmapper
am broadcast -n de.vahrmap.vmapper/.RestartService
sleep 2
monkey -p de.grennith.rgc.remotegpscontroller 1
sleep 5

echo "`date +%Y-%m-%d_%T` VM mockgps disable and RGC enable" >> $logfile

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
 -dpwnr) downgrade_pogo_wizard_no_reboot ;;
 -urw) update_rgc_wizard ;;
 -ua) update_all ;;
 -uanr) update_all_no_reboot ;;
 -uvx) create_vmapper_xml ;;
 -uvxnr) create_vmapper_xml_no_reboot ;;
 -spv) pd_to_vm ;;
 -svp) vm_to_pd ;;
 -srv) rgc_to_vm ;;
 -svr) vm_to_rgc ;;
 -fp) force_pogo_update ;;
 esac
done


(( $reboot )) && reboot_device
exit
