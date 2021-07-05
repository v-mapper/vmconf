#!/system/bin/sh
# version 0.2

source /sdcard/vmapper_conf

pdconf="/data/data/com.mad.pogodroid/shared_prefs/com.mad.pogodroid_preferences.xml"
puser=$(ls -la /data/data/com.mad.pogodroid/|head -n2|tail -n1|awk '{print $3}')
authpassword=$(grep 'auth_password' $pdconf | sed -e 's/    <string name="auth_password">\(.*\)<\/string>/\1/')
authuser=$(grep 'auth_username' $pdconf | sed -e 's/    <string name="auth_username">\(.*\)<\/string>/\1/')
origin=$(grep 'post_origin' $pdconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/')
postdest=$(grep -w 'post_destination' $pdconf | sed -e 's/    <string name="post_destination">\(.*\)<\/string>/\1/')

reboot_device(){
#if [[ "$USER" == "shell" ]] ;then
# echo "Rebooting Device"
/system/bin/reboot
#fi
}

create_vmapper_config(){
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
echo "    <boolean name=\"selinux\" value=\"$selinux\" />" >> $vmconf
echo "    <boolean name=\"betamode\" value=\"$betamode\" />" >> $vmconf
echo "    <boolean name=\"daemon\" value=\"$daemon\" />" >> $vmconf
echo "    <boolean name=\"gzip\" value=\"$gzip\" />" >> $vmconf
echo "    <int name=\"bootdelay\" value=\"$bootdelay\" />" >> $vmconf
echo "</map>" >> $vmconf
chmod 660 $vmconf
chown $vmuser:$vmuser $vmconf
}

install_vmapper(){

## pogodroid disable full daemon + stop pogodroid
sed -i 's,\"full_daemon\" value=\"true\",\"full_daemon\" value=\"false\",g' $pdconf
chmod 660 $pdconf
chown $puser:$puser $pdconf
am force-stop com.mad.pogodroid
# let us kill pogo as well
am force-stop com.nianticlabs.pokemongo

## Download and install vmapper
/system/bin/curl -L -o /sdcard/Download/vmapper.apk -k -s $download/vmapper.apk
/system/bin/pm install -r /sdcard/Download/vmapper.apk
/system/bin/rm /sdcard/Download/vmapper.apk

## At this stage vmapper isn't in magisk db nor had it generated a config filefolder
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
# Let try and push start, untested
input tap 352 199
sleep 5

## Set for reboot device
reboot=1
}

update_vmapper(){
/system/bin/curl -L -o /sdcard/Download/vmapper.apk -k -s $download/vmapper.apk
# will force-stop prevent atvexperience from becomming unresponsive? it will require to push start again so we reboot after update
# am force-stop de.goldjpg.vmapper
/system/bin/pm install -r /sdcard/Download/vmapper.apk
/system/bin/rm /sdcard/Download/vmapper.apk
am broadcast -a android.intent.action.BOOT_COMPLETED -p de.goldjpg.vmapper
reboot=1
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
/system/bin/curl -L -o /system/bin/vmapper.sh -k -s https://raw.githubusercontent.com/dkmur/vmconf/master/vmapper.sh
chmod +x /system/bin/vmapper.sh
}

update_pogo(){
case "$(uname -m)" in
 aarch64) arch="arm64_v8a";;
 armv8l)  arch="armeabi-v7a";;
esac

if [[ $arch == "arm64_v8a"  ]]
then
/system/bin/curl -L -o /sdcard/Download/pogo.apk -k -s $download/pogo64.apk
else
  if [[ $arch == "armeabi-v7a" ]]
  then
  /system/bin/curl -L -o /sdcard/Download/pogo.apk -k -s $download/pogo32.apk
  fi
fi

/system/bin/pm install -r /sdcard/Download/pogo.apk
/system/bin/rm -f /sdcard/Download/pogo.apk
reboot=1
}

for i in "$@" ;do
 case "$i" in
 -iv) install_vmapper ;;
 -us) update_vmapper_script ;;
 -up) update_pogo ;;
 -uv) update_vmapper ;;
 -uvc) update_vmapper_conf ;;
 -uvx) update_vmapper_xml ;;
 esac
done


(( $reboot )) && reboot_device
exit
