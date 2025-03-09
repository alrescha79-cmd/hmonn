#!/bin/bash
# GPIO Founder Lutfa Ilham
# Internet Monitor for Huawei
# by Aryo Brokolly (youtube)
# 1.1 - Dengan Logging

DIR=/usr/bin
CONF=/etc/config
MODEL=/usr/lib/lua/luci/model/cbi
CON=/usr/lib/lua/luci/controller

LOG_FILE="/var/log/huawei_monitor.log"
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

if [ "$(id -u)" != "0" ]; then
  log "This script must be run as root"
  exit 1
fi

SERVICE_NAME="Huawei Monitor"
CONFIG_FILE="/etc/config/huawey"
DEFAULT_CHECK_INTERVAL=1

if [ -f "$CONFIG_FILE" ]; then
  source <(grep -E "^\s*option" "$CONFIG_FILE" | sed -E 's/option ([^ ]+) (.+)/\1=\2/')
else
  log "Config file $CONFIG_FILE not found. Exiting."
  exit 1
fi

LAN_OFF_DURATION=${lan_off_duration:-5}
MODEM_PATH=${modem_path}
CHECK_INTERVAL=$DEFAULT_CHECK_INTERVAL

function loop() {
  log "Monitoring LAN status..."
  lan_off_timer=0
  while true; do
    if curl -X "HEAD" --connect-timeout 3 -so /dev/null "http://bing.com"; then
      if [ "$lan_off_timer" -ne 0 ]; then
        log "Internet kembali normal."
      fi
      lan_off_timer=0
    else
      lan_off_timer=$((lan_off_timer + CHECK_INTERVAL))
      log "Internet tidak terdeteksi. Timer: $lan_off_timer detik."
    fi

    if [ "$lan_off_timer" -ge "$LAN_OFF_DURATION" ]; then
      log "LAN off selama $LAN_OFF_DURATION detik, menjalankan $MODEM_PATH ..."
      $MODEM_PATH &>> "$LOG_FILE"
      lan_off_timer=0 
    fi

    sleep "$CHECK_INTERVAL"
  done
}

function start() {
  log "Starting ${SERVICE_NAME} service ..."
  screen -AmdS huawei-monitor "${0}" -l
}

function stop() {
  log "Stopping ${SERVICE_NAME} service ..."
  kill $(screen -list | grep huawei-monitor | awk -F '[.]' {'print $1'}) 2>/dev/null || log "Service not running"
}

function usage() {
  cat <<EOF
Usage:
  -r  Run ${SERVICE_NAME} service
  -s  Stop ${SERVICE_NAME} service
  -x  Uninstall ${SERVICE_NAME} service
EOF
}

function uninstall()
{		

	echo "deleting file huawei monitor..."
    	clear
	echo "Remove file huawei.py..."
        rm -f $DIR/huawei.py
        mv $DIR/huawei_x.py $DIR/huawei.py
	sleep 1
	echo "Remove file huawey.lua..."
	rm -f $MODEL/huawey.lua
	clear
	sleep 1
	echo "Remove file huawei..."
	rm -f $DIR/huawei
	clear
	sleep 1
	echo "Remove file huawey..."
	rm -f $CONF/huawey
        clear
        sleep 1
	echo "Remove file huawey.lua..."
  	rm -f $CON/huawey.lua
 	sleep1
  echo " Uninstall Huawei Monitor succesfully..."
  sleep 5
  exit
}

case "${1}" in
  -l)
    loop
    ;;
  -r)
    start
    ;;
  -s)
    stop
    ;;
  -x)
    uninstall
    ;;
  *)
    usage
    ;;
esac
