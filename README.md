
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
