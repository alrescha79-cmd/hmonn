#!/bin/ash
# Installation script by ARYO.

DIR=/usr/bin
CONF=/etc/config
MODEL=/usr/lib/lua/luci/model/cbi
CON=/usr/lib/lua/luci/controller


finish(){
clear
	echo ""
    echo "INSTALL SUCCESSFULLY ;)"
    echo ""
    sleep 3
    clear
    echo "Youtube : ARYO BROKOLLY"
    echo ""
    echo ""
}

download_files()
{
    	clear
  	echo "Downloading files from repo.."
   	wget -O $MODEL/telegram_config.lua https://raw.githubusercontent.com/aryobrokollyy/Telegrambuset/main/telegram_config.lua
 	wget -O $DIR/telegram https://raw.githubusercontent.com/aryobrokollyy/Telegrambuset/main/usr/bin/telegram && chmod +x $DIR/telegram
 	wget -O $CONF/telegram https://raw.githubusercontent.com/aryobrokollyy/Telegrambuset/main/etc/config/telegram
  	wget -O $CON/telegram.lua https://raw.githubusercontent.com/aryobrokollyy/Telegrambuset/main/telegram.lua && chmod +x $CON/telegram.lua
 		finish
}

echo ""
echo "Install Script code from repo aryo."

while true; do
    read -p "This will download the files. Do you want to continue (y/n)? " yn
    case $yn in
        [Yy]* ) download_files; break;;
        [Nn]* ) exit;;
        * ) echo "Please answer 'y' or 'n'.";;
    esac
done
