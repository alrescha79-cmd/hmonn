#!/usr/bin/env python3
import logging
from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection
import time
import socket
import requests
import re
import os
import sys

CACHE_FILE = "/tmp/last_ip.txt"

def get_wan_info(client):
    try:
        wan_info = client.device.information()
        return wan_info.get("WanIPAddress"), wan_info.get("DeviceName")
    except Exception:
        return None, None

def send_telegram_message(token, chat_id, message, message_thread_id=None):
    if not token or not chat_id:
        print("⚠️ Token/chat_id kosong, lewati kirim pesan.")
        return
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = {"chat_id": chat_id, "text": message}
    if message_thread_id:
        data["message_thread_id"] = message_thread_id
    try:
        r = requests.post(url, data=data, timeout=10)
        if r.status_code != 200:
            print(f"⚠️ Gagal kirim Telegram: {r.text}")
    except Exception as e:
        print(f"⚠️ Gagal kirim Telegram: {e}")

def load_openwrt_config(cfg="/etc/config/huawey"):
    config = {}
    if not os.path.exists(cfg):
        raise Exception(f"Config {cfg} tidak ditemukan.")
    with open(cfg) as f:
        for line in f:
            m = re.match(r"\s*option\s+(\w+)\s+'([^']+)'", line)
            if m:
                config[m[1]] = m[2]
    return config

def save_last_ip(ip):
    if ip:
        with open(CACHE_FILE, "w") as f:
            f.write(ip)

def load_last_ip():
    if os.path.exists(CACHE_FILE):
        with open(CACHE_FILE) as f:
            return f.read().strip()
    return None

def initiate_ip_change(client):
    """Men-trigger modem agar ganti IP"""
    try:
        client.net.plmn_list()
        print("🔁 Permintaan ganti IP dikirim ke modem...")
        return True
    except Exception as e:
        print(f"❌ Gagal kirim perintah ganti IP: {e}")
        return False

def monitor_ip_changes(client, token, chat_id, thread_id, device_name, hostname):
    """Pemantauan otomatis setiap 30 detik"""
    print("\n🛰️ Monitoring IP otomatis dimulai ...")
    last_ip = load_last_ip()
    while True:
        try:
            current_ip, _ = get_wan_info(client)
            if current_ip and current_ip != last_ip:
                msg = (
                    f"🔄 Pergantian IP Otomatis - {hostname}\n"
                    f"=========================\n"
                    f"📡 Modem: {device_name}\n"
                    f"🌐 Lama: {last_ip or '-'}\n"
                    f"🆕 Baru: {current_ip}\n"
                    f"=========================\n"
                    f"👨‍💻"
                )
                send_telegram_message(token, chat_id, msg, thread_id)
                print(msg)
                save_last_ip(current_ip)
                last_ip = current_ip
            else:
                print(f"[{time.strftime('%H:%M:%S')}] IP belum berubah ({current_ip})")
        except Exception as e:
            print(f"⚠️ Error monitoring: {e}")
        time.sleep(30)

def main():
    config = load_openwrt_config()
    router_ip = config.get("router_ip", "192.168.8.1")
    username = config.get("username", "admin")
    password = config.get("password", "admin")
    token = config.get("telegram_token", "")
    chat_id = config.get("chat_id", "")
    thread_id = config.get("message_thread_id")
    hostname = socket.gethostname()

    connection_url = f"http://{username}:{password}@{router_ip}/"

    manual_mode = "--change" in sys.argv
    mode = "MANUAL" if manual_mode else "MONITOR"

    try:
        with Connection(connection_url) as conn:
            client = Client(conn)
            current_ip, device_name = get_wan_info(client)
            if not current_ip:
                raise Exception("Tidak bisa mendapatkan IP dari modem.")

            if manual_mode:
                # MODE GANTI IP MANUAL
                print("🔧 Mode: Ganti IP Manual")

                old_ip = load_last_ip() or current_ip
                send_telegram_message(token, chat_id,
                    f"🔧 Ganti IP Manual dimulai di {hostname}\n=========================\n📡 Modem: {device_name}\n🌐 IP Sekarang: {old_ip}\n=========================\n",
                    thread_id)

                if initiate_ip_change(client):
                    time.sleep(10)
                    new_ip, _ = get_wan_info(client)
                    msg = (
                        f"✅ IP BERHASIL DIGANTI MANUAL - {hostname}\n"
                        f"=========================\n"
                        f"📡 Modem: {device_name}\n"
                        f"🌐 IP Lama: {old_ip}\n"
                        f"🆕 IP Baru: {new_ip or 'Tidak terdeteksi'}"
                        f"=========================\n"
                    )
                    send_telegram_message(token, chat_id, msg, thread_id)
                    save_last_ip(new_ip)
                    print(msg)
                else:
                    send_telegram_message(token, chat_id, "❌ Gagal mengganti IP manual", thread_id)

            else:
                # MODE MONITOR OTOMATIS (BOOT)
                print("🛰️ Mode: Monitoring Otomatis")
                save_last_ip(current_ip)
                send_telegram_message(token, chat_id,
                    f"🚀 Monitoring otomatis dimulai di {hostname}\n=========================\n📡 Modem: {device_name}\n🌐 IP awal: {current_ip}\n=========================\n",
                    thread_id)
                monitor_ip_changes(client, token, chat_id, thread_id, device_name, hostname)

    except Exception as e:
        send_telegram_message(token, chat_id, f"❌ Error: {e}", thread_id)
        print(f"❌ {e}")

if __name__ == "__main__":
    main()
