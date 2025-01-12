#!/bin/ash
# Installation script by ARYO.

DIR=/usr/bin
CONF=/etc/config
MODEL=/usr/lib/lua/luci/model/cbi
CON=/usr/lib/lua/luci/controller
URL=https://raw.githubusercontent.com/saputribosen/1clickhuawei/main
SRCH="/usr/bin/huawei.py"
TRCH="/usr/bin/huawei_x.py"


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
        if [ -f "$SRCH" ]; then
        mv "$SRCH" "$TRCH"
        echo "File renamed from $SRCH to $TRCH"
        else
        echo "Source file $SRCH does not exist."
        fi
	sleep 3
  	echo "Downloading files from repo.."
   	wget -O $MODEL/huawey.lua $URL/cbi_model/huawey.lua
 	wget -O $DIR/huawei.py $URL/usr/bin/huawei.py && chmod +x $DIR/huawei.py
 	wget -O $CONF/huawey $URL/huawey
  	wget -O $CON/huawey.lua $URL/controller/huawey.lua && chmod +x $CON/huawey.lua
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
