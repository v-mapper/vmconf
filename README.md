
# vmconf

Install vMAD, upload vmapper, fill out autoconfig section for V-Mapper and....<BR>
1 execute job ``vm: install vmapper (autoupdate enabled)`` to install vmapper on devices (with default MAD rom)<BR>
2 for new atvs, alternatively, use vmpper rom <BR> 
<BR>
notes:<BR>
1 vmapper.sh and 42vmapper logging is done in /sdcard/vm.log<BR>
2 in order to use develop branch ``touch /sdcard/useVMCdevelop`` job included in repo<BR> 
<BR>
VMapper rom will allow for copy of PoGo, Magisk and Gapps from usb to speed up the process for new install. If files aren't present they will be downloaded.<BR>
- download PoGo from apkmirror, 42vmapper will check wizard on pogo version supported before copy from usb<BR>
- [download magisk](https://github.com/Map-A-Droid/MAD-ATV/raw/master/Magisk-v20.3.zip)<BR>
- [download gapps](https://madatv.b-cdn.net/open_gapps-arm64-7.1-pico-20200715.zip)<BR>

Usage ATVdetailsSender:<BR>
1 create sql table ATVsummary, already done for Stats users<BR>
2 setup webhook receiver, [repo](https://github.com/v-mapper/rdmVM/tree/main/wh_receiver)<BR>
3 make sure config file is present on atv `/data/local/ATVdetailsWebhook.config`<BR>
4 enable webhooks to be send on atv ``touch /sdcard/sendwebhook``<BR>
notes:
- steps 3+4 are performed automatically for new install with vmapper rom IF config file ``ATVdetailsWebhook.txt`` is present on usb<BR>
- steps 3+4 for MADrom devices, example job in repo ``enableWHsenderMADrom.json``<BR> 


## **Advanced feature (optional) - Requires VMapper Roms V2 or above**
> ⚠️ The steps below are not required to set up your devices. Following these you understand you are now building your own personal ROM file for your own use what has built in personal and sensitive data (as server adresses, usernames and passwords) that should not be shared so proceed at your own risk. ⚠️<BR>
<BR>
Adds possibility of flashing with a custom rom (based on vmapper rom) with a config file containing MADmin ip and credentials, and optionally a proxy address so devices can be flashed and directly setup without usb flashdrive.<BR>

Use AMLogic Flash Tool to unpack vmapper rom, go to Advanced tab and open system folder and add in ``system/etc`` a file with the following content:<BR>

### Built in MadMin autoconfig file (removes the need for USB drive for this)
<BR>
Filename: vm_custom_config <BR>
File content: ``http://192.168.1.123:8000 AUTHUSER AUTHPASS 192.168.1.456:80`` <BR>
where first item is your MADmin address, second is MADmin auth user, third is MADmin auth password, and last is your proxy ip:port (optional)

### Built in ATVdetailsWebhook config file (removes the need for USB drive for this) 
Copy your ``ATVdetailsWebhook.txt`` file to the ROM folder indicated above

After adding your custom files, repack your rom, flash your device, fire it up and it will show up in MADmin auto-config section where you can assign an Origin (allow some time at first boot for tools to be downloaded) without need of using an usb flashdrive.
