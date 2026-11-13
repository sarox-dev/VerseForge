import ctypes
import sys


def hide_taskbar():
    # Atrodam uzdevumu joslu
    taskbar = ctypes.windll.user32.FindWindowW("Shell_TrayWnd", None)
    # Paslēpjam uzdevumu joslu
    ctypes.windll.user32.ShowWindow(taskbar, 0)  # 0 paslēpj logu

def show_taskbar():
    # Atrodam uzdevumu joslu
    taskbar = ctypes.windll.user32.FindWindowW("Shell_TrayWnd", None)
    # Parādam uzdevumu joslu
    ctypes.windll.user32.ShowWindow(taskbar, 5)  # 5 parāda logu


if len(sys.argv) > 1:
    command = sys.argv[1:]
    if command[0] == "true":
        hide_taskbar()
else:
    show_taskbar()