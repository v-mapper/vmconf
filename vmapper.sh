#!/system/bin/sh
# version 0.14

source /sdcard/vmapper_conf

pdconf="/data/data/com.mad.pogodroid/shared_prefs/com.mad.pogodroid_preferences.xml"
puser=$(ls -la /data/data/com.mad.pogodroid/|head -n2|tail -n1|awk '{print $3}')
authpassword=$(grep 'auth_password' $pdconf | sed -e 's/    <string name="auth_password">\(.*\)<\/string>/\1/')
authuser=$(grep 'auth_username' $pdconf | sed -e 's/    <string name="auth_username">\(.*\)<\/string>/\1/')
origin=$(grep 'post_origin' $pdconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/')
postdest=$(grep -w 'post_destination' $pdconf | sed -e 's/    <string name="post_destination">\(.*\)<\/string>/\1/')
pserver=$(grep -v raw "$pdconf"|awk -F'>' '/post_destination/{print $2}'|awk -F'<' '{print $1}')

reboot_device(){
#if [[ "$USER" == "shell" ]] ;then
# echo "Rebooting Device"
/system/bin/reboot
#fi
}

checkpdconf(){
if ! [[ -s "$pdconf" ]] ;then
 echo "pogodroid not configured yet"
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

create_vmapper_config(){
# download latest vmapper_conf
update_vmapper_conf
# check for missing added config options
if [ -z "$openlucky" ]
then
        echo "you did NOT add openlucky setting to config.ini, setting it to true for now"
        openlucky="true"
        echo ""
else
        echo "openlucky setting added, proceeding"
        echo ""
fi
if [ -z "$rebootminutes" ]
then
        echo "you did NOT add rebootminutes setting to config.ini, setting it to 0 for now"
        rebootminutes="0"
        echo ""
else
        echo "rebootminutes setting added, proceeding"
        echo ""
fi

if [ -z "$rawpostdest" ]
then
        echo "you did NOT add $rawpostdest setting to config.ini, setting it to NO rawpoastdest for now"
        rawpostdest=""
        echo ""
else
        echo "$rawpostdest setting added, proceeding"
        echo ""
fi

# (re)create vmapper config.xml
vmconf="/data/data/de.goldjpg.vmapper/shared_prefs/config.xml"
vmuser=$(ls -la /data/data/de.goldjpg.vmapper/|head -n2|tail -n1|awk '{print $3}')
rm -f $vmconf
touch $vmconf
sed -i "$ a \<?xml version=\'1.0\' encoding=\'utf-8\' standalone=\'yes\' ?\>" $vmconf
echo "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>" >> $vmconf
echo "<map>" >> $vmconf
echo "    <string name=\"authpassword\">$authpassword</string>" >> $vmconf
echo "    <string name=\"authuser\">$authuser</string>" >> $vmconf
echo "    <string name=\"authid\">$vmtoken</string>" >> $vmconf
echo "    <string name=\"origin\">$origin</string>" >> $vmconf
echo "    <string name=\"postdest\">$postdest</string>" >> $vmconf
echo "    <string name=\"rawpostdest\">$rawpostdest</string>" >> $vmconf
echo "    <boolean name=\"selinux\" value=\"$selinux\" />" >> $vmconf
echo "    <boolean name=\"betamode\" value=\"$betamode\" />" >> $vmconf
echo "    <boolean name=\"daemon\" value=\"$daemon\" />" >> $vmconf
echo "    <boolean name=\"gzip\" value=\"$gzip\" />" >> $vmconf
echo "    <boolean name=\"openlucky\" value=\"$openlucky\" />" >> $vmconf
echo "    <int name=\"bootdelay\" value=\"$bootdelay\" />" >> $vmconf
echo "    <int name=\"rebootminutes\" value=\"$rebootminutes\" />" >> $vmconf
echo "</map>" >> $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf
}

setup_vmapper(){
## pogodroid disable full daemon + stop pogodroid
sed -i 's,\"full_daemon\" value=\"true\",\"full_daemon\" value=\"false\",g' $pdconf
chmod 660 $pdconf
chown $puser:$puser $pdconf
am force-stop com.mad.pogodroid
# let us kill pogo as well
am force-stop com.nianticlabs.pokemongo

## Install vmapper
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
create_vmapper_config

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
/system/bin/curl -L -o /system/etc/init.d/55vmapper -k -s https://raw.githubusercontent.com/dkmur/vmconf/main/55vmapper
chmod +x /system/etc/init.d/55vmapper

## Set for reboot device
reboot=1
}

install_vmapper(){
# Dowload vmapper from folder
/system/bin/rm -f /sdcard/Download/vmapper.apk
/system/bin/curl -L -o /sdcard/Download/vmapper.apk -k -s $download/vmapper.apk

# setup vmapper
setup_vmapper

## de-activate autoupdate by default as it requires vmad
touch /sdcard/disableautovmapperupdate
}

install_vmapper_wizzard(){
# Dowload vmapper from wizzard
/system/bin/rm -f /sdcard/Download/vmapper.apk
curl -o /sdcard/Download/vmapper.apk -s -k -L $(get_pd_user) -H "origin: $origin" "$pserver/mad_apk/vm/download"

# setup vmapper
setup_vmapper
}

update_vmapper(){
/system/bin/curl -L -o /sdcard/Download/vmapper.apk -k -s $download/vmapper.apk
# will force-stop prevent atvexperience from becomming unresponsive? it will require to push start again so we reboot after update
# am force-stop de.goldjpg.vmapper
/system/bin/pm install -r /sdcard/Download/vmapper.apk
/system/bin/rm -f /sdcard/Download/vmapper.apk
# re create vmapper config.xml
create_vmapper_config
am broadcast -a android.intent.action.BOOT_COMPLETED -p de.goldjpg.vmapper
reboot=1
}

update_vmapper_wizzard(){
#update vmapper using the vmad wizard
checkpdconf || return 1
! [[ "$pserver" ]] && echo "pogodroid endpoint not configured yet, cannot contact the wizard" && return 1
origin=$(awk -F'>' '/post_origin/{print $2}' "$pdconf"|awk -F'<' '{print $1}')
newver="$(curl -s -k -L $(get_pd_user) -H "origin: $origin" "$pserver/mad_apk/vm/noarch" | awk '{print substr($1,2); }')"
installedver="$(dumpsys package de.goldjpg.vmapper|awk -F'=' '/versionName/{print $2}'|head -n1 | awk '{print substr($1,2); }')"
if checkupdate "$newver" "$installedver" ;then
 echo "updating vmapper..."
 /system/bin/rm -f /sdcard/Download/vmapper.apk
 until curl -o /sdcard/Download/vmapper.apk -s -k -L $(get_pd_user) -H "origin: $origin" "$pserver/mad_apk/vm/download" ;do
  /system/bin/rm -f /sdcard/Download/vmapper.apk
  sleep
 done
 /system/bin/pm install -r /sdcard/Download/vmapper.apk
 /system/bin/rm -f /sdcard/Download/vmapper.apk
 # re create vmapper config.xml
 create_vmapper_config
 reboot=1
fi
}

update_vmapper_conf(){
/system/bin/curl -L -o /sdcard/vmapper_conf -k -s $download/vmapper_conf
}

update_vmapper_xml(){
/system/bin/curl -L -o /sdcard/vmapper_conf -k -s $download/vmapper_conf
create_vmapper_config
reboot=1
}

update_vmapper_script(){
mount -o remount,rw /system
/system/bin/curl -L -o /system/bin/vmapper.sh -k -s https://raw.githubusercontent.com/dkmur/vmconf/main/vmapper.sh
chmod +x /system/bin/vmapper.sh
mount -o remount,ro /system
}

update_pogo(){
case "$(uname -m)" in
 aarch64) arch="arm64_v8a";;
 armv8l)  arch="armeabi-v7a";;
esac

if [ "$arch" = "arm64_v8a" ]
then
/system/bin/curl -L -o /sdcard/Download/pogo.apk -k -s $download/pogo64.apk
else
  if [ "$arch" = "armeabi-v7a" ]
  then
  /system/bin/curl -L -o /sdcard/Download/pogo.apk -k -s $download/pogo32.apk
  fi
fi

/system/bin/pm install -r /sdcard/Download/pogo.apk
/system/bin/rm -f /sdcard/Download/pogo.apk
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

reboot=1
}

for i in "$@" ;do
 case "$i" in
 -iv) install_vmapper ;;
 -ivw) install_vmapper_wizzard ;;
 -us) update_vmapper_script ;;
 -up) update_pogo ;;
 -uv) update_vmapper ;;
 -uvw) update_vmapper_wizzard ;;
 -uvc) update_vmapper_conf ;;
 -uvx) update_vmapper_xml ;;
 -spv) pd_to_vm ;;
 -svp) vm_to_pd ;;
 esac
done


(( $reboot )) && reboot_device
exit
