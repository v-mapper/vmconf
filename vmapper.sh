#!/system/bin/sh
# version 2.01

#Create logfile
if [ ! -e /sdcard/vm.log ] ;then
    touch /sdcard/vm.log
fi

# remove old vmapper_conf file if exists
rm -f /sdcard/vmapper_conf

logfile="/sdcard/vm.log"
pdconf="/data/data/com.mad.pogodroid/shared_prefs/com.mad.pogodroid_preferences.xml"
puser=$(ls -la /data/data/com.mad.pogodroid/|head -n2|tail -n1|awk '{print $3}')
authpassword=$(grep 'auth_password' $pdconf | sed -e 's/    <string name="auth_password">\(.*\)<\/string>/\1/')
authuser=$(grep 'auth_username' $pdconf | sed -e 's/    <string name="auth_username">\(.*\)<\/string>/\1/')
origin=$(grep 'post_origin' $pdconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/')
postdest=$(grep -w 'post_destination' $pdconf | sed -e 's/    <string name="post_destination">\(.*\)<\/string>/\1/')
pserver=$(grep -v raw "$pdconf"|awk -F'>' '/post_destination/{print $2}'|awk -F'<' '{print $1}')


reboot_device(){
echo "`date +%Y-%m-%d_%T` Reboot device" >> logfile
/system/bin/reboot
}

checkpdconf(){
if ! [[ -s "$pdconf" ]] ;then
 echo "`date +%Y-%m-%d_%T` Pogodroid not configured, we need those settings" >> logfile
 return 1
fi
}

get_pd_user(){
checkpdconf || return 1
user=$(awk -F'>' '/auth_username/{print $2}' "$pdconf"|awk -F'<' '{print $1}')
pass=$(awk -F'>' '/auth_password/{print $2}' "$pdconf"|awk -F'<' '{print $1}')
if [[ "$user" ]] ;then
 printf "-u $user:$pass"
fi
}

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


install_vmapper_wizzard(){
## pogodroid disable full daemon + stop pogodroid
sed -i 's,\"full_daemon\" value=\"true\",\"full_daemon\" value=\"false\",g' $pdconf
chmod 660 $pdconf
chown $puser:$puser $pdconf
am force-stop com.mad.pogodroid
# let us kill pogo as well
am force-stop com.nianticlabs.pokemongo

## Install vmapper
/system/bin/rm -f /sdcard/Download/vmapper.apk
curl -o /sdcard/Download/vmapper.apk -s -k -L $(get_pd_user) -H "origin: $origin" "$pserver/mad_apk/vm/download"
/system/bin/pm install -r /sdcard/Download/vmapper.apk
/system/bin/rm -f /sdcard/Download/vmapper.apk

## At this stage vmapper isn't in magisk db nor had it generated a config folder
#monkey -p de.goldjpg.vmapper -c android.intent.category.LAUNCHER 1
am start -n de.goldjpg.vmapper/.MainActivity
sleep 2
uid=$(stat -c %u /data/data/de.goldjpg.vmapper/)
am force-stop de.goldjpg.vmapper
sleep 2

## Grant su access
sqlite3 /data/adb/magisk.db "INSERT INTO policies (uid,package_name,policy,until,logging,notification) VALUES(\"$uid\",'de.goldjpg.vmapper',2,0,1,1)"

## Create config file
create_vmapper_xml

## Start vmapper
#am start -n de.goldjpg.vmapper/.MainActivity
monkey -p de.goldjpg.vmapper 1
sleep 5
# Push start
# portrait 64bit
input tap 209 745
sleep 2
# portrait 32bit
input tap 199 642
sleep 5

## add 55vmapper
mount -o remount,rw /system
/system/bin/curl -L -o /system/etc/init.d/55vmapper -k -s https://raw.githubusercontent.com/dkmur/vmconf/main/55vmapper
chmod +x /system/etc/init.d/55vmapper
mount -o remount,ro /system

## Set for reboot device
reboot=1
}

update_vmapper_wizzard(){
#update vmapper using the vmad wizard
checkpdconf || return 1
! [[ "$pserver" ]] && echo "`date +%Y-%m-%d_%T` pogodroid endpoint not configured yet, cannot contact the wizard" >> logfile && return 1
origin=$(awk -F'>' '/post_origin/{print $2}' "$pdconf"|awk -F'<' '{print $1}')
newver="$(curl -s -k -L $(get_pd_user) -H "origin: $origin" "$pserver/mad_apk/vm/noarch" | awk '{print substr($1,2); }')"
installedver="$(dumpsys package de.goldjpg.vmapper|awk -F'=' '/versionName/{print $2}'|head -n1 | awk '{print substr($1,2); }')"
if checkupdate "$newver" "$installedver" ;then
 echo "`date +%Y-%m-%d_%T` new vmapper version detected in wizzard, updating $installedver=>$newver" >> logfile
 /system/bin/rm -f /sdcard/Download/vmapper.apk
 until curl -o /sdcard/Download/vmapper.apk -s -k -L $(get_pd_user) -H "origin: $origin" "$pserver/mad_apk/vm/download" ;do
  /system/bin/rm -f /sdcard/Download/vmapper.apk
  sleep
 done
 /system/bin/pm install -r /sdcard/Download/vmapper.apk
 /system/bin/rm -f /sdcard/Download/vmapper.apk

 # new vampper version in wizzard, so we replace xml
 create_vmapper_xml

 reboot=1
 else
 echo "`date +%Y-%m-%d_%T` vmapper already on latest version" >> logfile
fi
}


create_vmapper_xml(){
vmconf="/data/data/de.goldjpg.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.goldjpg.vmapper/|head -n2|tail -n1|awk '{print $3}')

curl -s -k -L $(get_pd_user) -H "origin: $origin" "$pserver/vm_conf"  >> $vmconf

chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf
echo "`date +%Y-%m-%d_%T` config.xml (re)created" >> logfile
reboot=1
}

pd_to_vm(){
vmconf="/data/data/de.goldjpg.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.goldjpg.vmapper/|head -n2|tail -n1|awk '{print $3}')
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
am start -n de.goldjpg.vmapper/.MainActivity
sleep 5
# Push start
# portrait 64bit
input tap 209 745
sleep 2
# portrait 32bit
input tap 199 642
sleep 5

echo "`date +%Y-%m-%d_%T` vm daemon enable and pd daemon disable" >> logfile

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

echo "`date +%Y-%m-%d_%T` vm daemon disable and pd daemon enable" >> logfile

reboot=1
}

for i in "$@" ;do
 case "$i" in
 -ivw) install_vmapper_wizzard ;;
 -uvw) update_vmapper_wizzard ;;
 -uvx) create_vmapper_xml ;;
 -spv) pd_to_vm ;;
 -svp) vm_to_pd ;;
 esac
done


(( $reboot )) && reboot_device
exit
