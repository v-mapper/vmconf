#!/system/bin/sh
# version 4.8.3

#Version checks
Ver42vmapper="1.5.3"
Ver55vmapper="2.2"
Ver56vmwatchdog="1.3.9"
VerATVwebhook="1.8.3"

github_url="https://raw.githubusercontent.com/v-mapper/vmconf"

#Create logfile
if [ ! -e /sdcard/vm.log ] ;then
   touch /sdcard/vm.log
fi

# remove old vmapper_conf file if exists
rm -f /sdcard/vmapper_conf

logfile="/sdcard/vm.log"
[[ -d /data/data/com.mad.pogodroid ]] && puser=$(ls -la /data/data/com.mad.pogodroid/ | head -n2 | tail -n1 | awk '{print $3}')
pdconf="/data/data/com.mad.pogodroid/shared_prefs/com.mad.pogodroid_preferences.xml"
[[ -d /data/data/de.grennith.rgc.remotegpscontroller ]] && ruser=$(ls -la /data/data/de.grennith.rgc.remotegpscontroller/ |head -n2 | tail -n1 | awk '{print $3}')
rgcconf="/data/data/de.grennith.rgc.remotegpscontroller/shared_prefs/de.grennith.rgc.remotegpscontroller_preferences.xml"
vmconf="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
lastResort="/data/local/vm_last_resort"

# stderr to logfile
exec 2>> $logfile

# add vmapper.sh command to log
echo "" >> $logfile
echo "`date +%Y-%m-%d_%T` ## Executing $(basename $0) $@" >> $logfile

#Check if using Develop or main
if [ -f /sdcard/useVMCdevelop ] ;then
   branch="$github_url/develop"
else
   branch="$github_url/main"
fi

########## Functions

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

   function ver {
      for i in $(echo "$1" | tr '.' ' ')
      do
         echo $i | awk '{ printf("%03d", $1) }';
      done
   }

   if [ $(ver $1) -lt $(ver $2) ]; then
      need_update=1
   else
      need_update=0
   fi

}

install_vmapper_wizard(){
   # we first download vmapper
   /system/bin/rm -f /sdcard/Download/vmapper.apk
   until /system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download" || { echo "`date +%Y-%m-%d_%T` Download vmapper failed, exit" >> $logfile ; exit 1; } ;do
      sleep 2
   done

   ## pogodroid disable full daemon + stop pogodroid
   if [ -f "$pdconf" ] ;then
      sed -i 's,\"full_daemon\" value=\"true\",\"full_daemon\" value=\"false\",g' $pdconf
      chmod 660 $pdconf
      chown $puser:$puser $pdconf
      am force-stop com.mad.pogodroid
      echo "`date +%Y-%m-%d_%T` VM install: pogodroid disabled" >> $logfile
      # disable pd autoupdate
      touch /sdcard/disableautopogodroidupdate
   fi

   # let us kill pogo as well
   am force-stop com.nianticlabs.pokemongo

   ## Install vmapper
   settings put global package_verifier_user_consent -1
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

   # disable rgc
   if [ -f "$rgcconf" ] ;then
      sed -i 's,\"autostart_services\" value=\"true\",\"autostart_services\" value=\"false\",g' $rgcconf
      sed -i 's,\"boot_startup\" value=\"true\",\"boot_startup\" value=\"false\",g' $rgcconf
      chmod 660 $rgcconf
      chown $ruser:$ruser $rgcconf
      # disable rgc autoupdate
      touch /sdcard/disableautorgcupdate
      # kill rgc
      am force-stop de.grennith.rgc.remotegpscontroller
      echo "`date +%Y-%m-%d_%T` VM install: rgc disabled" >> $logfile
   fi

   # add 55vmapper for new install on MADrom
   if [ -f /system/etc/init.d/42mad ] || [ -f /system/etc/init.d/16mad ] && [ ! -f /system/etc/init.d/55vmapper ] ;then
      mount -o remount,rw /system
      until /system/bin/curl -s -k -L --fail --show-error -o /system/etc/init.d/55vmapper $branch/55vmapper || { echo "`date +%Y-%m-%d_%T` VM install: download 55vmapper failed, exit" >> $logfile ; exit 1; } ;do
	 sleep 2
      done
      chmod +x /system/etc/init.d/55vmapper
      #  mount -o remount,ro /system
      echo "`date +%Y-%m-%d_%T` VM install: 55vmapper installed" >> $logfile
   fi

   # add 56vmwatchdog for new install on MADrom
   if [ ! -f /system/etc/init.d/56vmwatchdog ] ;then
      mount -o remount,rw /system
      until /system/bin/curl -s -k -L --fail --show-error -o /system/etc/init.d/56vmwatchdog $branch/56vmwatchdog || { echo "`date +%Y-%m-%d_%T` VM install: download 56vmwatchdog failed, exit" >> $logfile ; exit 1; } ;do
	 sleep 2
      done
      chmod +x /system/etc/init.d/56vmwatchdog
      #  mount -o remount,ro /system
      echo "`date +%Y-%m-%d_%T` VM install: 56vmwatchdog installed" >> $logfile
   fi

   # add webhooksender
   mount -o remount,rw /system
   until /system/bin/curl -s -k -L --fail --show-error -o /system/bin/ATVdetailsSender.sh $branch/ATVdetailsSender.sh || { echo "`date +%Y-%m-%d_%T` VM install: download ATVdetailsSender.sh failed, exit" >> $logfile ; exit 1; } ;do
      sleep 2
   done
   chmod +x /system/bin/ATVdetailsSender.sh
   echo "`date +%Y-%m-%d_%T` VM install: webhook sender installed" >> $logfile
   mount -o remount,ro /system

   ## Set for reboot device
   reboot=1
}

vmapper_wizard(){
   #check update vmapper and download from wizard

   newver="$(/system/bin/curl -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/noarch" | awk '{print substr($1,2); }')"
   installedver="$(dumpsys package de.vahrmap.vmapper|awk -F'=' '/versionName/{print $2}'|head -n1 | awk '{print substr($1,2); }')"

   #if [ "$installedver" = "" ] ;then
   #installedver="$(dumpsys package de.goldjpg.vmapper|awk -F'=' '/versionName/{print $2}'|head -n1 | awk '{print substr($1,2); }')"
   #fi

   if [ "$newver" = "" ] ;then
      vm_install="skip"
      echo "`date +%Y-%m-%d_%T` Vmapper not found in MADmin, skipping version check" >> $logfile
   else
      checkupdate "$installedver" "$newver"
      if [ $need_update -eq 1 ]; then
	 echo "`date +%Y-%m-%d_%T` New vmapper version detected in wizard, updating $installedver=>$newver" >> $logfile
	 /system/bin/rm -f /sdcard/Download/vmapper.apk
	 until /system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download" || { echo "`date +%Y-%m-%d_%T` Download vmapper failed, exit" >> $logfile ; exit 1; } ;do
	    sleep 2
	 done

	 # set vmapper to be installed
	 vm_install="install"
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

      reboot=1
   fi
}

downgrade_vmapper_wizard(){
   # we download first
   /system/bin/rm -f /sdcard/Download/vmapper.apk
   until /system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/vmapper.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/vm/download" || { echo "`date +%Y-%m-%d_%T` Download vmapper failed, exit" >> $logfile ; exit 1; } ;do
      sleep 2
   done
   # remove vmapper
   am force-stop com.nianticlabs.pokemongo
   am force-stop de.vahrmap.vmapper
   sleep 2
   /system/bin/pm uninstall de.vahrmap.vmapper
   echo "`date +%Y-%m-%d_%T` VM downgrade: vmapper removed" >> $logfile

   # install vmapper from wizard
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

   if [ -z ${force_pogo_update+x} ] ;then
      newver="$(/system/bin/curl -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/pogo/$arch")"
   else
      newver="1.599.1"
   fi
   installedver="$(dumpsys package com.nianticlabs.pokemongo|awk -F'=' '/versionName/{print $2}')"

   checkupdate "$installedver" "$newver"
   if [ $need_update -eq 1 ]; then
      echo "`date +%Y-%m-%d_%T` New pogo version detected in wizard, updating $installedver=>$newver" >> $logfile
      /system/bin/rm -f /sdcard/Download/pogo.apk
      until /system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/pogo.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/pogo/$arch/download" || { echo "`date +%Y-%m-%d_%T` Download pogo failed, exit" >> $logfile ; exit 1; } ;do
	 sleep 2
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
   if [ "$pogo_install" = "install" ] ;then
      echo "`date +%Y-%m-%d_%T` Installing pogo" >> $logfile
      # install pogo
      /system/bin/pm install -r /sdcard/Download/pogo.apk
      /system/bin/rm -f /sdcard/Download/pogo.apk
      reboot=1
   fi
}

downgrade_pogo_wizard_no_reboot(){
   /system/bin/rm -f /sdcard/Download/pogo.apk
   until /system/bin/curl -k -s -L --fail --show-error -o /sdcard/Download/pogo.apk -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/pogo/$arch/download" || { echo "`date +%Y-%m-%d_%T` Download pogo failed, exit" >> $logfile ; exit 1; } ;do
      sleep 2
   done
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

   if [ -f "$rgcconf" ] ;then

      newver="$(curl -s -k -L -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/rgc/noarch")"
      installedver="$(dumpsys package de.grennith.rgc.remotegpscontroller 2>/dev/null|awk -F'=' '/versionName/{print $2}'|head -n1)"

      if checkupdate "$newver" "$installedver" ;then
	 echo "`date +%Y-%m-%d_%T` New rgc version detected in wizard, updating $installedver=>$newver" >> $logfile
	 rm -f /sdcard/Download/RemoteGpsController.apk
	 until /system/bin/curl -o /sdcard/Download/RemoteGpsController.apk  -s -k -L --fail --show-error -u $authuser:$authpassword -H "origin: $origin" "$server/mad_apk/rgc/download" || { echo "`date +%Y-%m-%d_%T` Download rgc failed, exit" >> $logfile ; exit 1; } ;do
	    sleep 2
	 done

	 # set rgc to be installed
	 rgc_install="install"

      else
	 rgc_install="skip"
	 echo "`date +%Y-%m-%d_%T` RGC already on latest version" >> $logfile
      fi
   else
      rgc_install="skip"
      echo "`date +%Y-%m-%d_%T` RGC not installed, skipping update" >> $logfile
   fi
}

update_rgc_wizard(){
   rgc_wizard
   if [ "$rgc_install" = "install" ] ;then
      echo "`date +%Y-%m-%d_%T` Installing rgc" >> $logfile
      # install rgc
      /system/bin/pm install -r /sdcard/Download/RemoteGpsController.apk
      /system/bin/rm -f /sdcard/Download/RemoteGpsController.apk
      reboot=1
   fi
}

vmapper_xml(){
   vmconf="/data/data/de.vahrmap.vmapper/shared_prefs/config.xml"
   vmuser=$(ls -la /data/data/de.vahrmap.vmapper/|head -n2|tail -n1|awk '{print $3}')

   until /system/bin/curl -k -s -L --fail --show-error -o $vmconf -u $authuser:$authpassword -H "origin: $origin" "$server/vm_conf" || { echo "`date +%Y-%m-%d_%T` Download config.xml failed, exit" >> $logfile ; exit 1; } ;do
      sleep 2
   done

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

force_pogo_update(){
   force_pogo_update=true
}

update_all(){
   if [ -f /sdcard/disableautovmapperupdate ] ;then
      echo "`date +%Y-%m-%d_%T` VMapper auto update disabled, skipping version check" >> $logfile
   else
      vmapper_wizard
   fi

   if [ -f /sdcard/disableautopogoupdate ] ;then
      echo "`date +%Y-%m-%d_%T` PoGo auto update disabled, skipping version check" >> $logfile
   else
      pogo_wizard
   fi

   if [ ! -z "$vm_install" ] && [ ! -z "$pogo_install" ] ;then
      echo "`date +%Y-%m-%d_%T` All updates checked and downloaded if needed" >> $logfile
      if [ "$vm_install" = "install" ] ;then
	 echo "`date +%Y-%m-%d_%T` Install vmapper" >> $logfile
	 # kill pogo
	 am force-stop com.nianticlabs.pokemongo
	 # install vmapper
	 /system/bin/pm install -r /sdcard/Download/vmapper.apk
	 /system/bin/rm -f /sdcard/Download/vmapper.apk
	 # if no pogo update we restart both now
	 if [ "$pogo_install" != "install" ] ;then
	    echo "`date +%Y-%m-%d_%T` No pogo update, starting vmapper+pogo" >> $logfile
	    am force-stop de.vahrmap.vmapper
	    am broadcast -n de.vahrmap.vmapper/.RestartService
	    sleep 5
	    monkey -p com.nianticlabs.pokemongo -c android.intent.category.LAUNCHER 1
	 fi
      fi
      if [ "$pogo_install" = "install" ] ;then
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
      if [ "$vm_install" != "install" ] && [ "$pogo_install" != "install" ] ;then
	 echo "`date +%Y-%m-%d_%T` Nothing to install" >> $logfile
      fi
   fi
}

########## Execution

#remove old last resort
rm -f /sdcard/vm_last_resort

#wait on internet
until ping -c1 8.8.8.8 >/dev/null 2>/dev/null || ping -c1 1.1.1.1 >/dev/null 2>/dev/null; do
   sleep 10
done
echo "`date +%Y-%m-%d_%T` Internet connection available" >> $logfile

# Initial Install of 56vmwatchdog
if [ ! -f /system/etc/init.d/56vmwatchdog ] ;then
   mount -o remount,rw /system
   until /system/bin/curl -s -k -L --fail --show-error -o /system/etc/init.d/56vmwatchdog $branch/56vmwatchdog || { echo "`date +%Y-%m-%d_%T` VM install: download 56vmwatchdog failed, exit" >> $logfile ; exit 1; } ;do
      sleep 2
   done
   chmod +x /system/etc/init.d/56vmwatchdog
   #  mount -o remount,ro /system
   echo "`date +%Y-%m-%d_%T` VM install: 56vmwatchdog installed" >> $logfile
fi

#download latest vmapper.sh
if [[ $(basename $0) != "vmapper_new.sh" ]] ;then
   mount -o remount,rw /system
   oldsh=$(head -2 /system/bin/vmapper.sh | grep '# version' | awk '{ print $NF }')
   until /system/bin/curl -s -k -L --fail --show-error -o /system/bin/vmapper_new.sh $branch/vmapper.sh || { echo "`date +%Y-%m-%d_%T` Download vmapper.sh failed, exit" >> $logfile ; exit 1; } ;do
      sleep 2
   done
   chmod +x /system/bin/vmapper_new.sh
   newsh=$(head -2 /system/bin/vmapper_new.sh | grep '# version' | awk '{ print $NF }')
   if [[ $oldsh != $newsh ]] ;then
      echo "`date +%Y-%m-%d_%T` vmapper.sh $oldsh=>$newsh, restarting script" >> $logfile
      #   folder=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
      cp /system/bin/vmapper_new.sh /system/bin/vmapper.sh
      mount -o remount,ro /system
      /system/bin/vmapper_new.sh $@
      exit 1
   fi
fi

#update 55vmpper, 42vmapper, 56vmwatchdog and ATVdetailsSender.sh if needed
if [[ $(basename $0) = "vmapper_new.sh" ]] ;then
   mount -o remount,rw /system

   #download latest 55vmapper if used
   if [[ -f /system/etc/init.d/55vmapper ]] ;then
      old55=$(head -2 /system/etc/init.d/55vmapper | grep '# version' | awk '{ print $NF }')
      if [ $Ver55vmapper != $old55 ] ;then
	 until /system/bin/curl -s -k -L --fail --show-error -o /system/etc/init.d/55vmapper $branch/55vmapper || { echo "`date +%Y-%m-%d_%T` Download 55vmapper failed, exit" >> $logfile ; exit 1; } ;do
	    sleep 2
	 done
	 chmod +x /system/etc/init.d/55vmapper
	 new55=$(head -2 /system/etc/init.d/55vmapper | grep '# version' | awk '{ print $NF }')
	 echo "`date +%Y-%m-%d_%T` 55vmapper $old55=>$new55" >> $logfile
      fi
   fi

   #download latest 42vmapper if used
   if [[ -f /system/etc/init.d/42vmapper ]] ;then
      old42=$(head -2 /system/etc/init.d/42vmapper | grep '# version' | awk '{ print $NF }')
      if [ $Ver42vmapper != $old42 ] ;then
	 until /system/bin/curl -s -k -L --fail --show-error -o /system/etc/init.d/42vmapper $branch/42vmapper || { echo "`date +%Y-%m-%d_%T` Download 42vmapper failed, exit" >> $logfile ; exit 1; } ;do
	    sleep 2
	 done
	 chmod +x /system/etc/init.d/42vmapper
	 new42=$(head -2 /system/etc/init.d/42vmapper | grep '# version' | awk '{ print $NF }')
	 echo "`date +%Y-%m-%d_%T` 42vmapper $old42=>$new42" >> $logfile
      fi
   fi

   #download latest 56vmwatchdog if used
   if [[ -f /system/etc/init.d/56vmwatchdog ]] ;then
      old56=$(head -2 /system/etc/init.d/56vmwatchdog | grep '# version' | awk '{ print $NF }')
      if [ $Ver56vmwatchdog != $old56 ] ;then
	 until /system/bin/curl -s -k -L --fail --show-error -o /system/etc/init.d/56vmwatchdog $branch/56vmwatchdog || { echo "`date +%Y-%m-%d_%T` Download 56vmwatchdog failed, exit" >> $logfile ; exit 1; } ;do
	    sleep 2
	 done
	 chmod +x /system/etc/init.d/56vmwatchdog
	 new56=$(head -2 /system/etc/init.d/56vmwatchdog | grep '# version' | awk '{ print $NF }')
	 echo "`date +%Y-%m-%d_%T` 56vmwatchdog $old56=>$new56" >> $logfile
      fi
   fi

   #download latest ATVdetailsSender.sh
   oldWH=$([ -f /system/bin/ATVdetailsSender.sh ] && head -2 /system/bin/ATVdetailsSender.sh | grep '# version' | awk '{ print $NF }' || echo 0)
   if [ $VerATVwebhook != $oldWH ] ;then
      until /system/bin/curl -s -k -L --fail --show-error -o /system/bin/ATVdetailsSender.sh $branch/ATVdetailsSender.sh || { echo "`date +%Y-%m-%d_%T` Download ATVdetailsSender.sh failed, exit" >> $logfile ; exit 1; } ;do
	 sleep 2
      done
      chmod +x /system/bin/ATVdetailsSender.sh
      newWH=$(head -2 /system/bin/ATVdetailsSender.sh | grep '# version' | awk '{ print $NF }')
      echo "`date +%Y-%m-%d_%T` ATVdetailsSender.sh $oldWH=>$newWH" >> $logfile
   fi
   mount -o remount,ro /system
fi

# "rom" checks
# if 42mad exists we cannot have 42vmapper
if [ -f /system/etc/init.d/42mad ] && [ -f /system/etc/init.d/42vmapper ] ;then
   mount -o remount,rw /system
   rm -f /system/etc/init.d/42vmapper
   mount -o remount,ro /system
   echo "`date +%Y-%m-%d_%T` Removed 42vmapper as 42mad exists, this should not happen!" >> $logfile
fi
# if 16mad exists we cannot have 42vmapper
if [ -f /system/etc/init.d/16mad ] && [ -f /system/etc/init.d/42vmapper ] ;then
   mount -o remount,rw /system
   rm -f /system/etc/init.d/42vmapper
   mount -o remount,ro /system
   echo "`date +%Y-%m-%d_%T` Removed 42vmapper as 16mad exists, this should not happen!" >> $logfile
fi
# if 42vmappers exist we cannot have 55vmapper
if [ -f /system/etc/init.d/55vmapper ] && [ -f /system/etc/init.d/42vmapper ] ;then
   mount -o remount,rw /system
   rm -f /system/etc/init.d/55vmapper
   mount -o remount,ro /system
   echo "`date +%Y-%m-%d_%T` Removed 55vmapper as 42vmapper exists, this should not happen!" >> $logfile
fi

# check vmapper policy
if [ -d /data/data/de.vahrmap.vmapper/ ] ;then
   uid=$(stat -c %u /data/data/de.vahrmap.vmapper/)
   policy=$(sqlite3 /data/adb/magisk.db "SELECT policy FROM policies where uid = '$uid'")
   if [[ $policy == "" ]] ;then
      echo "`date +%Y-%m-%d_%T` vmapper incorectly or not added to su list, adding it and reboot device" >> $logfile
      sqlite3 /data/adb/magisk.db "DELETE FROM policies where package_name = 'de.vahrmap.vmapper'"
      sqlite3 /data/adb/magisk.db "INSERT INTO policies (uid,package_name,policy,until,logging,notification) VALUES('$uid','de.vahrmap.vmapper',2,0,1,1)"
      reboot=1
   else
      if [[ $policy != 2 ]] ;then
	 echo "`date +%Y-%m-%d_%T` incorrect policy for vmapper, changing it and reboot device" >> $logfile
	 sqlite3 /data/adb/magisk.db "DELETE FROM policies where package_name = 'de.vahrmap.vmapper'"
	 sqlite3 /data/adb/magisk.db "DELETE FROM policies where uid = '$uid'"
	 sqlite3 /data/adb/magisk.db "INSERT INTO policies (uid,package_name,policy,until,logging,notification) VALUES('$uid','de.vahrmap.vmapper',2,0,1,1)"
	 reboot=1
      fi
   fi
fi

# allign rgc/pd settings with vm
[ -f $vmconf ] && vm_origin=$(grep -w 'origin' $vmconf | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/')
[ -f $rgcconf ] && rgc_origin=$(grep -w 'websocket_origin' $rgcconf | sed -e 's/    <string name="websocket_origin">\(.*\)<\/string>/\1/')
[ -f $pdconf ] && pd_origin=$(grep -w 'post_origin' $pdconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/')
[ -f $vmconf ] && vm_ws=$(grep -w 'websocketurl' $vmconf | sed -e 's/    <string name="websocketurl">\(.*\)<\/string>/\1/')
[ -f $rgcconf ] && rgc_ws=$(grep -w 'websocket_uri' $rgcconf | sed -e 's/    <string name="websocket_uri">\(.*\)<\/string>/\1/')
[ -f $vmconf ] && vm_dest=$(grep -w 'postdest' $vmconf | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/')
[ -f $pdconf ] && pd_dest=$(grep -w 'post_destination' $pdconf | sed -e 's/    <string name="post_destination">\(.*\)<\/string>/\1/')
#Check rgc
if [ -f $vmconf ] && [ -f $rgcconf ] && [[ $vm_origin != $rgc_origin || $vm_ws != $rgc_ws ]] ;then
   echo "`date +%Y-%m-%d_%T` VMconf check: rgc settings differ from vmapper, adjusting rgc" >> $logfile
   sed -i 's,\"websocket_origin\">.*<,\"websocket_origin\">'"$vm_origin"'<,g' $rgcconf
   sed -i 's,\"websocket_uri\">.*<,\"websocket_uri\">'"$vm_ws"'<,g' $rgcconf
   chmod 660 $rgcconf
   chown $ruser:$ruser $rgcconf
fi
#Check pd
if [ -f $vmconf ] && [ -f $pdconf ] && [[ $vm_origin != $pd_origin || $vm_dest != $pd_dest ]] ;then
   echo "`date +%Y-%m-%d_%T` VMconf check: pd settings differ from vmapper, adjusting pd" >> $logfile
   sed -i 's,\"post_origin\">.*<,\"post_origin\">'"$vm_origin"'<,g' $pdconf
   sed -i 's,\"post_destination\">.*<,\"post_destination\">'"$vm_dest"'<,g' $pdconf
   chmod 660 $pdconf
   chown $puser:$puser $pdconf
fi

# check rgc status, websocket fallback
if [ -f "$rgcconf" ] ;then
   if [ -f "$vmconf" ] && [ ! -z $(grep -w 'websocketurl' $vmconf | sed -e 's/    <string name="websocketurl">\(.*\)<\/string>/\1/') ] ;then
      if [[ $(grep -w 'boot_startup' $rgcconf | awk -F "\"" '{print tolower($4)}') == "true" ]] ;then
	 sed -i 's,\"autostart_services\" value=\"true\",\"autostart_services\" value=\"false\",g' $rgcconf
	 sed -i 's,\"boot_startup\" value=\"true\",\"boot_startup\" value=\"false\",g' $rgcconf
	 chmod 660 $rgcconf
	 chown $ruser:$ruser $rgcconf
	 am force-stop de.grennith.rgc.remotegpscontroller
	 echo "`date +%Y-%m-%d_%T` VMconf check: rgc activated and vmapper installed, disabled rgc" >> $logfile
      fi
   else
      if [[ $(grep -w 'boot_startup' $rgcconf | awk -F "\"" '{print tolower($4)}') == "false" ]] ;then
	 sed -i 's,\"autostart_services\" value=\"false\",\"autostart_services\" value=\"true\",g' $rgcconf
	 sed -i 's,\"boot_startup\" value=\"false\",\"boot_startup\" value=\"true\",g' $rgcconf
	 chmod 660 $rgcconf
	 chown $ruser:$ruser $rgcconf
	 monkey -p de.grennith.rgc.remotegpscontroller 1
	 reboot=1
	 echo "`date +%Y-%m-%d_%T` VMconf check: rgc deactivated and either vmapper not installed or websocket was empty, started rgc" >> $logfile
      fi
   fi
fi

# check owner of vmapper config.xml
[ -f $vmconf ] && vmuser=$(ls -la /data/data/de.vahrmap.vmapper/|head -n2|tail -n1|awk '{print $3}')
[ -f $vmconf ] && vmconfiguser=$(ls -la /data/data/de.vahrmap.vmapper/shared_prefs/config.xml |head -n2|tail -n1|awk '{print $3}')
if [ -f "$vmconf" ] && [[ $vmuser != $vmconfiguser ]] ;then
   chmod 660 $vmconf
   chown $vmuser:$vmuser $vmconf
   am force-stop de.vahrmap.vmapper
   am broadcast -n de.vahrmap.vmapper/.RestartService
   echo "`date +%Y-%m-%d_%T` VMconf check: vmapper config.xml user incorrect, changed it and restarted vmapper" >> $logfile
fi

# Get MADmin credentials and origin
if [ -f "$vmconf" ] && [ ! -z $(grep -w 'postdest' $vmconf | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/') ] ;then
   server=$(grep -w 'postdest' $vmconf | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/')
   authuser=$(grep -w 'authuser' $vmconf | sed -e 's/    <string name="authuser">\(.*\)<\/string>/\1/')
   authpassword=$(grep -w 'authpassword' $vmconf | sed -e 's/    <string name="authpassword">\(.*\)<\/string>/\1/')
   origin=$(grep -w 'origin' $vmconf | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/')
   echo "`date +%Y-%m-%d_%T` Using vahrmap.vmapper settings" >> $logfile
elif [ -f "$pdconf" ] && [ ! -z $(grep -w 'post_origin' $pdconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/') ] ;then
   server=$(grep -w 'post_destination' $pdconf | sed -e 's/    <string name="post_destination">\(.*\)<\/string>/\1/')
   authuser=$(grep -w 'auth_username' $pdconf | sed -e 's/    <string name="auth_username">\(.*\)<\/string>/\1/')
   authpassword=$(grep -w 'auth_password' $pdconf | sed -e 's/    <string name="auth_password">\(.*\)<\/string>/\1/')
   origin=$(grep -w 'post_origin' $pdconf | sed -e 's/    <string name="post_origin">\(.*\)<\/string>/\1/')
   echo "`date +%Y-%m-%d_%T` Using pogodroid settings" >> $logfile
elif [ -f "$lastResort" ] ;then
   server=$(awk '{print $1}' "$lastResort")
   authuser=$(awk '{print $2}' "$lastResort")
   authpassword=$(awk '{print $3}' "$lastResort")
   origin=$(awk '{print $4}' "$lastResort")
   echo "`date +%Y-%m-%d_%T` Using settings stored in /sdcard/vm_last_resort"  >> $logfile
elif [[ -f /data/local/vmconf ]] ;then
   server=$(grep -w 'postdest' /data/local/vmconf | sed -e 's/    <string name="postdest">\(.*\)<\/string>/\1/')
   authuser=$(grep -w 'authuser' /data/local/vmconf | sed -e 's/    <string name="authuser">\(.*\)<\/string>/\1/')
   authpassword=$(grep -w 'authpassword' /data/local/vmconf | sed -e 's/    <string name="authpassword">\(.*\)<\/string>/\1/')
   auth="$authuser:$authpassword"
   origin=$(grep -w 'origin' /data/local/vmconf | sed -e 's/    <string name="origin">\(.*\)<\/string>/\1/')
   #pm disable-user com.android.vending
   echo "`date +%Y-%m-%d_%T` Using settings stored in /data/local/vmconf"  >> $logfile
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
if [ -z $1 ] || [ $1 != "-nrc" ] ;then
   if [ $(cat /sdcard/vm.log | grep `date +%Y-%m-%d` | grep rebooted | wc -l) -gt 20 ] ;then
      echo "`date +%Y-%m-%d_%T` Device rebooted over 20 times today, vmapper.sh signing out, see you tomorrow"  >> $logfile
      echo "Device rebooted over 20 times today, vmapper.sh signing out, see you tomorrow.....add -nrc to job or (re)move /sdcard/vm.log then try again"
      exit 1
   fi
fi

# set hostname = origin, wait till next reboot for it to take effect
if [ $(cat /system/build.prop | grep net.hostname | wc -l) = 0 ]; then
   echo "`date +%Y-%m-%d_%T` No hostname set, setting it to $origin" >> $logfile
   mount -o remount,rw /system
   echo "net.hostname=$origin" >> /system/build.prop
   mount -o remount,ro /system
else
   hostname=$(grep net.hostname /system/build.prop | awk 'BEGIN { FS = "=" } ; { print $2 }')
   if [[ $hostname != $origin ]] ;then
      echo "`date +%Y-%m-%d_%T` Changing hostname, from $hostname to $origin" >> $logfile
      mount -o remount,rw /system
      sed -i -e "s/^net.hostname=.*/net.hostname=$origin/g" /system/build.prop
      mount -o remount,ro /system
   fi
fi

# enable ATVdetails webhook sender or restart
if [ -f /data/local/ATVdetailsWebhook.config ] && [ -f /system/bin/ATVdetailsSender.sh ] && [ -f /sdcard/sendwebhook ] ;then
   checkWHsender=$(pgrep -f ATVdetailsSender.sh)
   if [ -z $checkWHsender ] ;then
      /system/bin/ATVdetailsSender.sh >/dev/null 2>&1 &
      echo "`date +%Y-%m-%d_%T` ATVdetails sender enabled" >> $logfile
   else
      kill -9 $checkWHsender
      sleep 2
      /system/bin/ATVdetailsSender.sh >/dev/null 2>&1 &
      echo "`date +%Y-%m-%d_%T` ATVdetails sender restarted" >> $logfile
   fi
fi

for i in "$@" ;do
   case "$i" in
      -ivw) install_vmapper_wizard ;;
      -uvw) update_vmapper_wizard ;;
      -dvw) downgrade_vmapper_wizard ;;
      -upw) update_pogo_wizard ;;
      -dpwnr) downgrade_pogo_wizard_no_reboot ;;
      -urw) update_rgc_wizard ;;
      -ua) update_all ;;
      -uvx) create_vmapper_xml ;;
      -uvxnr) create_vmapper_xml_no_reboot ;;
      -fp) force_pogo_update ;;
   esac
done


(( $reboot )) && reboot_device
exit
