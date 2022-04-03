
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
- download Magisk from <https://github.com/Map-A-Droid/MAD-ATV/raw/master/Magisk-v20.3.zip> <BR>
- download Gapps from <https://madatv.b-cdn.net/open_gapps-arm64-7.1-pico-20200715.zip> <BR>
