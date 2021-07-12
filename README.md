
# vmconf


1 clone repo and copy config.ini ``git clone https://github.com/dkmur/vmconf.git && cd vmconf && cp config.ini.example config.ini``<BR>
2 fill out config.ini details<BR>
3 execute ``./settings.run`` This will copy (and adjust) vm_conf file to download folder and add jobs to MADmin<BR>
4 make sure to add, at least, ``vmapper.apk`` to download folder (wizzard is not yet supported for initial install)<BR>
5 optionally add ``pogo32.apk`` and/or ``pogo64.apk`` to download folder in case of mixed vmapper/pogodroid setup in order co control pogo updates via jobs (make sure to disable autoupdate)<BR>
