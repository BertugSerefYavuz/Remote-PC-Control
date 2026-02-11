import firebase_admin
from firebase_admin import credentials, db, storage
import os
import sys
import time
import json
import requests
import tkinter as tk
from tkinter import messagebox
import threading
import cv2
import numpy as np
import pyautogui
import platform
import webbrowser
import ctypes
import subprocess
import uuid


# --- BU FONKSİYONU EKLE ---
# pc_kontrol.py içine eklenecek

def resource_path(relative_path):
    """ Nuitka ve PyInstaller uyumlu dosya yolu bulucu """
    if "__compiled__" in globals() or getattr(sys, 'frozen', False):
        base_path = os.path.dirname(__file__)
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))

    return os.path.join(base_path, relative_path)

CRED_PATH = resource_path("serviceAccountKey.json")

DB_URL = "https://pc-kontrol-v2-default-rtdb.europe-west1.firebasedatabase.app/"

WEB_API_KEY = "BURAYA WEB API GELECEK"

STORAGE_BUCKET = "pc-kontrol-v2.firebasestorage.app"

CONFIG_PATH = os.path.join(os.environ["APPDATA"], "SystemConfig", "sys_config.json")
current_user_id = None


#YARDIMCI FONKSİYONLAR
def get_saved_user():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r") as f:
                data = json.load(f)
                return data.get("uid")
        except:
            return None
    return None


def save_user(uid):
    folder = os.path.dirname(CONFIG_PATH)
    if not os.path.exists(folder): os.makedirs(folder)
    with open(CONFIG_PATH, "w") as f: json.dump({"uid": uid}, f)


def login_firebase(email, password):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={WEB_API_KEY}"
    payload = {"email": email, "password": password, "returnSecureToken": True}
    try:
        r = requests.post(url, json=payload)
        data = r.json()
        if "localId" in data: return data["localId"]
        return None
    except:
        return None


def register_firebase(email, password):
    url = f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={WEB_API_KEY}"
    payload = {"email": email, "password": password, "returnSecureToken": True}
    try:
        r = requests.post(url, json=payload)
        data = r.json()
        if "localId" in data: return data["localId"]
        return None
    except:
        return None


def get_running_apps():
    try:
        cmd = "powershell \"Get-Process | Where-Object {$_.MainWindowTitle -ne ''} | Select-Object ProcessName\""
        startupinfo = subprocess.STARTUPINFO()
        startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, startupinfo=startupinfo)
        output, error = proc.communicate()
        if output:
            raw_list = output.decode('utf-8', errors='ignore').splitlines()
            app_list = []
            for line in raw_list:
                clean_line = line.strip()
                if clean_line and "ProcessName" not in clean_line and "---" not in clean_line:
                    if clean_line not in app_list: app_list.append(clean_line)
            return app_list
        return []
    except:
        return []


#ARAYÜZ
def show_login_gui():
    root = tk.Tk()
    root.title("PC Kontrol Kurulum")
    w, h = 350, 320
    ws, hs = root.winfo_screenwidth(), root.winfo_screenheight()
    x, y = (ws / 2) - (w / 2), (hs / 2) - (h / 2)
    root.geometry('%dx%d+%d+%d' % (w, h, x, y))

    lbl_info = tk.Label(root, text="PC Kontrol V2", font=("Arial", 16, "bold"))
    lbl_info.pack(pady=10)
    tk.Label(root, text="E-posta:").pack()
    entry_email = tk.Entry(root, width=30)
    entry_email.pack(pady=5)
    tk.Label(root, text="Şifre:").pack()
    entry_pass = tk.Entry(root, width=30, show="*")
    entry_pass.pack(pady=5)
    lbl_status = tk.Label(root, text="", fg="red")
    lbl_status.pack(pady=5)

    def on_success(uid, msg):
        save_user(uid)
        messagebox.showinfo("Başarılı", msg)
        root.destroy()
        start_background_service(uid)

    def handle_login():
        email = entry_email.get()
        password = entry_pass.get()
        if not email or not password:
            lbl_status.config(text="Doldurunuz.")
            return
        lbl_status.config(text="İşlem yapılıyor...", fg="blue")
        root.update()
        uid = login_firebase(email, password)
        if uid:
            on_success(uid, "Giriş başarılı!")
        else:
            lbl_status.config(text="Hata!", fg="red")

    def handle_register():
        email = entry_email.get()
        password = entry_pass.get()
        if not email or not password: return
        lbl_status.config(text="Kayıt olunuyor...", fg="blue")
        root.update()
        uid = register_firebase(email, password)
        if uid:
            on_success(uid, "Hesap açıldı!")
        else:
            lbl_status.config(text="Kayıt hatası!", fg="red")

    frame_btns = tk.Frame(root)
    frame_btns.pack(pady=15)
    tk.Button(frame_btns, text="Giriş Yap", command=handle_login, bg="#6C63FF", fg="white").pack(side=tk.LEFT, padx=5)
    tk.Button(frame_btns, text="Kayıt Ol", command=handle_register, bg="#00E5FF", fg="black").pack(side=tk.LEFT, padx=5)
    root.mainloop()


#SERVİS
def start_background_service(uid):
    global current_user_id
    current_user_id = uid

    if not firebase_admin._apps:
        cred = credentials.Certificate(CRED_PATH)
        # Storage Bucket ayarını ekledik
        firebase_admin.initialize_app(cred, {
            'databaseURL': DB_URL,
            'storageBucket': STORAGE_BUCKET
        })

    ref = db.reference(f'users/{current_user_id}')

    def listener(event):
        if event.event_type != 'put' or not event.data: return
        path = event.path
        raw_data = event.data
        command = path.replace('/', '')

        command_val = raw_data
        timestamp = 0
        if isinstance(raw_data, dict) and 'val' in raw_data:
            command_val = raw_data['val']
            timestamp = raw_data.get('ts', 0)

        if (time.time() * 1000) - timestamp > 300000:
            ref.child(f'command/{command}').delete()
            return

        if command == 'shutdown' and command_val:
            ref.child(f'command/{command}').set({'val': False})
            os.system("shutdown /s /t 10")
        elif command == 'lock' and command_val:
            ctypes.windll.user32.LockWorkStation()
            ref.child(f'command/{command}').delete()
        elif command == 'screenshot' and command_val:
            take_screenshot(ref)  # Yeni fonksiyon
            ref.child(f'command/{command}').delete()
        elif command == 'popup':
            show_popup(command_val)
            ref.child(f'command/{command}').delete()
        elif command == 'open_url':
            webbrowser.open(command_val)
            ref.child(f'command/{command}').delete()
        elif command == 'kill':
            kill_app(command_val)
            ref.child(f'command/{command}').delete()
        elif command == 'get_apps':
            update_status(ref)
            ref.child(f'command/{command}').delete()

    try:
        ref.child('command').listen(listener)
        while True:
            update_status(ref)
            time.sleep(5)
    except:
        time.sleep(10)
        start_background_service(uid)

def take_screenshot(ref):
    try:
        screenshot = pyautogui.screenshot()
        frame = np.array(screenshot)
        frame = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

        filename = f"{uuid.uuid4()}.jpg"

        _, buffer = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 60])

        bucket = storage.bucket()
        blob = bucket.blob(f'screenshots/{filename}')

        blob.upload_from_string(buffer.tobytes(), content_type='image/jpeg')

        blob.make_public()
        public_url = blob.public_url

        ref.child('status/last_screenshot').set({
            'url': public_url,
            'time': time.time()
        })

    except Exception as e:
        ref.child('status/last_screenshot').set({'error': str(e)})


def show_popup(msg):
    threading.Thread(target=lambda: ctypes.windll.user32.MessageBoxW(0, str(msg), "Mesaj", 0x40 | 0x1)).start()


def kill_app(app_name):
    try:
        name = app_name if app_name.endswith('.exe') else app_name + ".exe"
        os.system(f"taskkill /f /im {name}")
    except:
        pass


def update_status(ref):
    try:
        hwnd = ctypes.windll.user32.GetForegroundWindow()
        length = ctypes.windll.user32.GetWindowTextLengthW(hwnd)
        buf = ctypes.create_unicode_buffer(length + 1)
        ctypes.windll.user32.GetWindowTextW(hwnd, buf, length + 1)
        app_list = get_running_apps()
        ref.child('status').update({
            'online': True,
            'heartbeat': int(time.time()),
            'pc_name': platform.node(),
            'active_window': buf.value if buf.value else "Masaüstü",
            'app_list': app_list
        })
    except:
        pass


if __name__ == "__main__":
    saved_uid = get_saved_user()
    if saved_uid:
        start_background_service(saved_uid)
    else:
        show_login_gui()