#!/system/bin/sh
# version 1.1

logfile="/sdcard/vm.log"
vmconf="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
RUN_EVERY=60
REBOOT_AFTER=3
MAX_DAILY_REBOOT=3

#Create logfile if it doesn't exist yet
if [ ! -e $logfile ] ;then
  touch $logfile
fi

# stderr to logfile
exec 2>> $logfile

#Check if vmapper watchdog script is disabled
if [ -f /sdcard/disable_vm_watchdog ] ;then
  echo "`date +%Y-%m-%d_%T` VMwatchdog: disabled" >> $logfile
  exit
fi

#Check if vmapper is installed
if [ ! -f $vmconf ] ;then
  echo "`date +%Y-%m-%d_%T` VMwatchdog: not started, no vmapper install found" >> $logfile
  exit
fi

#Lets start by sleeping a bit
sleep 300

check_vm() {
vm_running=$(ps | grep de.vahrmap.vmapper | awk -F. '{ print $NF }')
}

i=0

while true; do
  check_vm
  if (( $i > $REBOOT_AFTER )) ;then
    if [ $(cat $logfile | grep `date +%Y-%m-%d` | grep VMwatchdog | grep rebooting | wc -l) -gt $MAX_DAILY_REBOOT ] ;then
      echo "`date +%Y-%m-%d_%T` VMwatchdog: I've already rebooted $MAX_DAILY_REBOOT times today, too tired now, see you tomorrow..."  >> $logfile
      sleep $(( 86400 - $(( $(date '+%-H *3600 + %-M *60 + %-S') )) ))
    else
      echo "`date +%Y-%m-%d_%T` VMwatchdog: vmapper not running, tried to restart vmapper $REBOOT_AFTER times, rebooting device"  >> $logfile
      reboot
    fi

  elif [ -z "$vm_running" ] ;then
    echo "`date +%Y-%m-%d_%T` VMwatchdog: vmapper not running, restarting" >> $logfile 
    am broadcast -n de.vahrmap.vmapper/.RestartService --ez autostart true
    i=$((i+1))
    sleep 5
    check_vm
    if [ -z "$vm_running" ] ;then
      echo "`date +%Y-%m-%d_%T` VMwatchdog: vmapper not running after restart attempt $i, waiting for next loop to retry" >> $logfile
    else
      echo "`date +%Y-%m-%d_%T` VMwatchdog: vmapper running after restart attempt $i" >> $logfile
      i=0
    fi
  fi
  sleep $RUN_EVERY
done
