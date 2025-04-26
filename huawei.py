#!/usr/bin/env python3
# Script by https://bit.ly/aryochannel

import logging
from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection
import time
#import telegram
import socket
import requests
import re
#from telegram import Bot

def get_wan_info(client):
    wan_info = client.device.information()
    wan_ip_address = wan_info.get('WanIPAddress')
    device_name = wan_info.get('DeviceName')
    return wan_ip_address, device_name

def send_telegram_message(token, chat_id, message, message_thread_id=None):
    url = f'https://api.telegram.org/bot{token}/sendMessage'
    data = {'chat_id': chat_id, 'text': message}

    if message_thread_id:
        data['message_thread_id'] = message_thread_id

    try:
        response = requests.post(url, data=data)
        if response.status_code != 200:
            print_warning("Gagal mengirim pesan Telegram.\nCek kembali Telegram Token / Chat ID pada Huawei Monitor.")
    except Exception as e:
        print_warning(f"Gagal mengirim pesan Telegram: {e}")

def print_warning(message):
    print("\n\033[93m" + message + "\033[0m")


def load_openwrt_config(config_file="/etc/config/huawey"):
    config = {}
    try:
        with open(config_file, "r") as file:
            for line in file:
                match = re.match(r"\s*option\s+(\w+)\s+'([^']+)'", line)
                if match:
                    key, value = match.groups()
                    config[key] = value
    except FileNotFoundError:
        raise Exception(f"Configuration file {config_file} not found.")
    return config

def main():
    config = load_openwrt_config()

    router_ip = config.get('router_ip', '192.168.8.1')
    username = config.get('username', 'admin')
    password = config.get('password', 'admin')
    telegram_token = config.get('telegram_token', '')
    chat_id = config.get('chat_id', '')
    message_thread_id = config.get('message_thread_id')

    hostname = socket.gethostname()
    connection_url = f"http://{username}:{password}@{router_ip}/"

    try:
        with Connection(connection_url) as connection:
            client = Client(connection)
            try:
                print_header("Get a new WAN IP Address", "")

                wan_ip_address, device_name = fetch_wan_info(client)
                print_result("Modem Name", device_name)
                print_result("Current IP", wan_ip_address)

                print("Initiating IP change process...")
                initiate_ip_change(client)

                time.sleep(5)

                print("Waiting for the IP to be changed...")
                wan_ip_address_after_plmn, _ = fetch_wan_info(client)
                print_result("New IP", wan_ip_address_after_plmn)
                send_telegram_message(telegram_token, chat_id, f"⚙️ Change IP-{hostname}.\n===============\n🔰 Modem Name: {device_name}\n🔰 Current IP: {wan_ip_address}\n🔰 New IP: {wan_ip_address_after_plmn} \n\n✅ IP change successfully.\n===============\n👨‍🔧 By Aryo Brokolly",
                    message_thread_id=message_thread_id
                )

                print_success("IP has been successfully changed.")

            except Exception as e:
                error_message = str(e)

                if "401" in error_message or "Username and Password wrong" in error_message:
                    clean_error = "Error: Invalid username or password."
                elif "Connection refused" in error_message or "Name or service not known" in error_message:
                    clean_error = "Error: Could not connect to the router. Check the IP address or network connection."
                else:
                    clean_error = "An unexpected error occurred. Please check your settings."

                print_error(clean_error)
                send_telegram_message(telegram_token, chat_id, clean_error, message_thread_id=message_thread_id)
    except Exception as e:
        error_message = str(e)

        if "401" in error_message or "Username and Password wrong" in error_message:
            clean_error = "Error: Invalid username or password."
        elif "Connection refused" in error_message or "Name or service not known" in error_message:
            clean_error = "Error: Could not connect to the router. Check the IP address or network connection."
        else:
            clean_error = "Unexpected error: " + error_message

        print_error(clean_error)
        send_telegram_message(telegram_token, chat_id, clean_error, message_thread_id=message_thread_id)
            

def fetch_wan_info(client):
    wan_ip_address = None
    device_name = None
    while not (wan_ip_address and device_name):
        wan_ip_address, device_name = get_wan_info(client)
    return wan_ip_address, device_name

def initiate_ip_change(client):
    response = client.net.plmn_list()

def print_header(title, creator):
    print(f"{'=' * 40}")
    print(f"{title.center(40)}")
    print(f"{'=' * 40}")

def print_result(label, value):
    print(f"{label}: {value}")

def print_success(message):
    print("\n\033[92m" + message + "\033[0m")

def print_error(message):
    print("\n\033[91m" + message + "\033[0m")

if __name__ == "__main__":
    main()
