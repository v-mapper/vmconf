#!/system/bin/sh

# vmapper watchdog version
vm_watchdog="1.0"

#Check if vmapper watchdog script is disabled
[ ! -f /sdcard/vm_watchdog ] || exit

#Create logfile if it doesn't exist yet
logfile="/sdcard/vm.log"

if [ ! -e $logfile ] ;then
    touch $logfile
fi

RUN_EVERY=60
REBOOT_AFTER=10

check_mitm() {
mitm_running=$(ps | grep -e de.goldjpg.vmapper -e de.vahrmap.vmapper -e com.mad.pogodroid | awk -F. '{ print $NF }')
}

i=0

while true; do
check_mitm
if (( $i > $REBOOT_AFTER )); then

    if [ $(cat $logfile | grep `date +%Y-%m-%d` | grep vm_watchdog | grep rebooted | wc -l) -gt 10 ] ;then
      #echo "`date +%Y-%m-%d_%T` Device rebooted over 10 times today by the vm_watchdog script, vmapper.sh signing out, see you tomorrow"
      echo "`date +%Y-%m-%d_%T` Device rebooted over 10 times today by the vm_watchdog script, this may be a sign something else is failing. vm_watchdog signing out to prevent infinite loops, see you tomorrow..."  >> $logfile
    else
      #echo "`date +%Y-%m-%d_%T` No MITM apk found running. Tried to restart vmapper $REBOOT_AFTER times and failed, vm_watchdog rebooting device as failsafe."
      echo "`date +%Y-%m-%d_%T` No MITM apk found running. Tried to restart vmapper $REBOOT_AFTER times and failed, vm_watchdog rebooted device as failsafe."  >> $logfile
      reboot
    fi

 elif [ -z "$mitm_running" ]; then
     #echo "`date +%Y-%m-%d_%T` No MITM App found running by vm_watchdog, restarting VMapper"
     echo "`date +%Y-%m-%d_%T` No MITM App found running by vm_watchdog, restarting VMapper" >> $logfile 
     am broadcast -n de.vahrmap.vmapper/.RestartService --ez autostart true
     sleep 10
     check_mitm
     [ -z "$mitm_running" ] && i=$((i+1)) && echo "`date +%Y-%m-%d_%T` No MITM detected by vm_watchdog after trying to restart it, waiting for next loop to retry. This was try number $i " >> $logfile && echo "`date +%Y-%m-%d_%T` No MITM detected by vm_watchdog after trying to restart it, waiting for next loop to retry. This was try number $i "  || echo "`date +%Y-%m-%d_%T` \$mitm_running restarted successfully by vm_watchdog, everything is fine" >> $logfile && c=i
 else
     i=0
     echo "\$mitm_running is running, everything is fine."
fi
  sleep $RUN_EVERY
done
