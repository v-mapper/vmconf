
# vmconf

Install vMAD, upload vmapper, fill out autoconfig section for V-Mapper and....<BR>
use one of the new Android9 64bit Rom<BR> 
<BR>
notes:<BR>
1 vmapper.sh and 49vmapper logging is done in /sdcard/vm.log<BR>
2 in order to use develop branch ``touch /sdcard/useVMCdevelop`` job included in repo<BR> 
<BR>
VMapper rom will allow for copy of PoGo from usb to speed up the process for new install. If files aren't present they will be downloaded.<BR>
- download PoGo from apkmirror, 49vmapper will check wizard on pogo version supported before copy from usb<BR>

Usage ATVdetailsSender:<BR>
1 create a Stats DB with user & pass and import /sql/tables.sql<BR>
2 setup webhook receiver, [repo](https://github.com/v-mapper/vmconf/tree/main9/vmc_whreceiver)<BR>
3 make sure config file is present on atv `/data/local/ATVdetailsWebhook.config` [Example](https://raw.githubusercontent.com/v-mapper/vmconf/main9/vmc_whreceiver/ATVdetailsWebhook.txt)<BR>
4 enable webhooks to be send on atv ``touch /sdcard/sendwebhook``<BR>
notes:
- steps 3+4 are performed automatically for new install with Android9 Rom IF config file ``ATVdetailsWebhook.txt`` is present on usb<BR>
- steps 3+4 for Android9 Rom devices, example rotom job in repo ``vmconf_enable_ATVsender``<BR> 
