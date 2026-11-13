# tray_module.py
import pygetwindow as gw
from pystray import MenuItem as item, Icon
from pystray import Menu
from PIL import Image
import subprocess
import threading
import os

class TrayModule:
    def __init__(self, window_name, editor_command, image_path):
        """
        window_name: logs, ko paslēpt
        editor_command: lista ar komandu, lai startētu editoru
        image_path: tray ikonas ceļš
        """
        self.window_name = window_name
        self.editor_command = editor_command
        self.image_path = image_path
        self.window_hidden = False
        self.icon = None
        self.exit_callback = None

    def hide_window(self):
        """Paslēpj/minimizē logu"""
        if self.window_hidden:
            return
        windows = gw.getWindowsWithTitle(self.window_name)
        if windows:
            win = windows[0]
            win.minimize()
            win.hide()
            self.window_hidden = True

    def open_editor(self):
        """Startē editoru (Godot vai citu)"""
        subprocess.Popen(self.editor_command, start_new_session=True)

    def set_exit_callback(self, callback):
        """Reģistrē callback, ko izsaukt, kad lietotājs spiež Exit"""
        self.exit_callback = callback

    def on_exit(self):
        """Beidz tray un paziņo serverim"""
        if self.icon:
            self.icon.stop()
        if self.exit_callback:
            self.exit_callback()

    def get_status(self):
        """Atgriež tray statusu serverim (vai klientam)"""
        return {"window_hidden": self.window_hidden}

    def run_tray(self):
        """Palaid tray ikonu un GUI"""
        self.hide_window()  # paslēpt logu sākumā

        image = Image.open(self.image_path)
        menu = Menu(
            item("Open menu", lambda icon, item: self.open_editor(), default=True),
            item("Exit", lambda icon, item: self.on_exit())
        )
        self.icon = Icon(self.window_name, image, self.window_name, menu=menu)

        # Tray GUI darbojas savā thread, lai netraucētu serverim
        t = threading.Thread(target=self.icon.run, daemon=True)
        t.start()
