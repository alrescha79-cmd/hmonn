#!/usr/bin/env python3
"""
Telegram Bot for Huawei Modem Monitor Control
==============================================
Bot ini memungkinkan pengguna untuk mengontrol layanan monitoring
modem Huawei melalui perintah Telegram.

Commands:
    /start   - Menampilkan IP sekarang dan waktu terakhir diganti
    /status  - Menampilkan status layanan monitoring
    /stop    - Menonaktifkan layanan monitoring
    /restart - Mengaktifkan ulang layanan monitoring
    /change  - Mengganti IP modem secara manual
"""

import os
import re
import time
import subprocess
import logging
from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes

# Setup logging
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# Constants
CONFIG_FILE = "/etc/config/huawey"
IP_CACHE_FILE = "/tmp/last_ip.txt"
HUAWEI_SCRIPT = "/usr/bin/huawei"
HUAWEI_PY = "/usr/bin/huawei.py"


def load_config():
    """Load configuration from OpenWrt config file."""
    config = {}
    if not os.path.exists(CONFIG_FILE):
        raise Exception(f"Config {CONFIG_FILE} tidak ditemukan.")
    with open(CONFIG_FILE) as f:
        for line in f:
            m = re.match(r"\s*option\s+(\w+)\s+'([^']+)'", line)
            if m:
                config[m[1]] = m[2]
    return config


def get_current_ip():
    """Get current IP and timestamp from cache file."""
    if os.path.exists(IP_CACHE_FILE):
        with open(IP_CACHE_FILE) as f:
            lines = f.read().strip().split('\n')
            ip = lines[0] if len(lines) > 0 else None
            timestamp = lines[1] if len(lines) > 1 else None
            return ip, timestamp
    return None, None


def is_service_running():
    """Check if huawei-monitor service is running."""
    try:
        result = subprocess.run(
            ["screen", "-list"],
            capture_output=True,
            text=True
        )
        return "huawei-monitor" in result.stdout
    except Exception:
        return False


def is_authorized(chat_id: str, config: dict) -> bool:
    """Check if the chat_id is authorized to use the bot."""
    authorized_chat_id = config.get("chat_id", "")
    return str(chat_id) == str(authorized_chat_id)


async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /start command - Show current IP and last change time."""
    try:
        config = load_config()
        
        if not is_authorized(update.effective_chat.id, config):
            await update.message.reply_text("⛔ Anda tidak memiliki akses ke bot ini.")
            return
        
        current_ip, last_change = get_current_ip()
        
        message = (
            "🛰️ **Huawei Modem Monitor**\n"
            "═══════════════════════════\n\n"
            f"📡 **IP Sekarang:** `{current_ip or 'Tidak tersedia'}`\n"
            f"⏰ **Terakhir Diganti:** {last_change or 'Tidak tersedia'}\n\n"
            "═══════════════════════════\n"
            "📋 **Perintah Tersedia:**\n"
            "• /start - Info IP sekarang\n"
            "• /status - Status layanan\n"
            "• /stop - Nonaktifkan layanan\n"
            "• /restart - Aktifkan layanan\n"
            "• /change - Ganti IP manual\n"
        )
        
        await update.message.reply_text(message, parse_mode='Markdown')
        
    except Exception as e:
        logger.error(f"Error in start_command: {e}")
        await update.message.reply_text(f"❌ Error: {e}")


async def status_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /status command - Show service status."""
    try:
        config = load_config()
        
        if not is_authorized(update.effective_chat.id, config):
            await update.message.reply_text("⛔ Anda tidak memiliki akses ke bot ini.")
            return
        
        running = is_service_running()
        current_ip, last_change = get_current_ip()
        
        status_emoji = "🟢" if running else "🔴"
        status_text = "Running" if running else "Stopped"
        
        message = (
            "📊 **Status Layanan**\n"
            "═══════════════════════════\n\n"
            f"{status_emoji} **Status:** {status_text}\n"
            f"📡 **IP Sekarang:** `{current_ip or 'N/A'}`\n"
            f"⏰ **Terakhir Diganti:** {last_change or 'N/A'}\n\n"
            "═══════════════════════════\n"
        )
        
        await update.message.reply_text(message, parse_mode='Markdown')
        
    except Exception as e:
        logger.error(f"Error in status_command: {e}")
        await update.message.reply_text(f"❌ Error: {e}")


async def stop_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /stop command - Stop the monitoring service."""
    try:
        config = load_config()
        
        if not is_authorized(update.effective_chat.id, config):
            await update.message.reply_text("⛔ Anda tidak memiliki akses ke bot ini.")
            return
        
        if not is_service_running():
            await update.message.reply_text("ℹ️ Layanan sudah tidak aktif.")
            return
        
        await update.message.reply_text("⏳ Menghentikan layanan...")
        
        # Run the stop command
        result = subprocess.run(
            [HUAWEI_SCRIPT, "-s"],
            capture_output=True,
            text=True
        )
        
        # Wait a moment and check status
        time.sleep(2)
        
        if not is_service_running():
            message = (
                "✅ **Layanan Dihentikan**\n"
                "═══════════════════════════\n\n"
                "🔴 Monitoring modem telah dinonaktifkan.\n"
                "Gunakan /restart untuk mengaktifkan kembali.\n"
            )
        else:
            message = "⚠️ Gagal menghentikan layanan. Coba lagi nanti."
        
        await update.message.reply_text(message, parse_mode='Markdown')
        
    except Exception as e:
        logger.error(f"Error in stop_command: {e}")
        await update.message.reply_text(f"❌ Error: {e}")


async def restart_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /restart command - Restart/Start the monitoring service."""
    try:
        config = load_config()
        
        if not is_authorized(update.effective_chat.id, config):
            await update.message.reply_text("⛔ Anda tidak memiliki akses ke bot ini.")
            return
        
        was_running = is_service_running()
        
        if was_running:
            await update.message.reply_text("⏳ Merestart layanan...")
            # Stop first
            subprocess.run([HUAWEI_SCRIPT, "-s"], capture_output=True)
            time.sleep(2)
        else:
            await update.message.reply_text("⏳ Memulai layanan...")
        
        # Start the service
        subprocess.run([HUAWEI_SCRIPT, "-r"], capture_output=True)
        
        # Wait and check status
        time.sleep(3)
        
        if is_service_running():
            action = "Direstart" if was_running else "Dimulai"
            message = (
                f"✅ **Layanan {action}**\n"
                "═══════════════════════════\n\n"
                "🟢 Monitoring modem sekarang aktif.\n"
                "IP akan dipantau secara otomatis.\n"
            )
        else:
            message = "⚠️ Gagal memulai layanan. Coba lagi nanti."
        
        await update.message.reply_text(message, parse_mode='Markdown')
        
    except Exception as e:
        logger.error(f"Error in restart_command: {e}")
        await update.message.reply_text(f"❌ Error: {e}")


async def change_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle /change command - Manually change IP."""
    try:
        config = load_config()
        
        if not is_authorized(update.effective_chat.id, config):
            await update.message.reply_text("⛔ Anda tidak memiliki akses ke bot ini.")
            return
        
        old_ip, _ = get_current_ip()
        
        await update.message.reply_text(
            "🔄 **Mengganti IP...**\n"
            f"IP Sekarang: `{old_ip or 'N/A'}`\n\n"
            "⏳ Mohon tunggu, proses ini membutuhkan waktu...",
            parse_mode='Markdown'
        )
        
        # Run the change IP command
        result = subprocess.run(
            ["python3", HUAWEI_PY, "--change"],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        # Wait for IP to update
        time.sleep(5)
        
        new_ip, timestamp = get_current_ip()
        
        if new_ip and new_ip != old_ip:
            message = (
                "✅ **IP Berhasil Diganti**\n"
                "═══════════════════════════\n\n"
                f"🌐 IP Lama: `{old_ip or 'N/A'}`\n"
                f"🆕 IP Baru: `{new_ip}`\n"
                f"⏰ Waktu: {timestamp or time.strftime('%Y-%m-%d %H:%M:%S')}\n"
            )
        elif new_ip == old_ip:
            message = (
                "ℹ️ **IP Tidak Berubah**\n"
                "═══════════════════════════\n\n"
                f"📡 IP: `{new_ip}`\n\n"
                "IP mungkin sudah yang terbaru atau\n"
                "provider tidak memberikan IP baru.\n"
            )
        else:
            message = (
                "⚠️ **Gagal Mengganti IP**\n"
                "═══════════════════════════\n\n"
                "Tidak dapat memverifikasi IP baru.\n"
                "Periksa koneksi ke modem.\n"
            )
        
        await update.message.reply_text(message, parse_mode='Markdown')
        
    except subprocess.TimeoutExpired:
        await update.message.reply_text("⚠️ Timeout! Proses ganti IP terlalu lama.")
    except Exception as e:
        logger.error(f"Error in change_command: {e}")
        await update.message.reply_text(f"❌ Error: {e}")


def main():
    """Main function to run the bot."""
    print("🤖 Starting Huawei Monitor Telegram Bot...")
    
    try:
        config = load_config()
        token = config.get("telegram_token", "")
        
        if not token:
            print("❌ Telegram token tidak ditemukan di config!")
            return
        
        print(f"📱 Chat ID yang diizinkan: {config.get('chat_id', 'N/A')}")
        
        # Create application
        application = Application.builder().token(token).build()
        
        # Add handlers
        application.add_handler(CommandHandler("start", start_command))
        application.add_handler(CommandHandler("status", status_command))
        application.add_handler(CommandHandler("stop", stop_command))
        application.add_handler(CommandHandler("restart", restart_command))
        application.add_handler(CommandHandler("change", change_command))
        
        print("✅ Bot siap menerima perintah!")
        print("Tekan Ctrl+C untuk menghentikan bot.")
        
        # Run the bot
        application.run_polling(allowed_updates=Update.ALL_TYPES)
        
    except Exception as e:
        print(f"❌ Error starting bot: {e}")


if __name__ == "__main__":
    main()
