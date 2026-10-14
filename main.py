# -*- coding: utf-8 -*-
import time
import os
import sys
import random

# ============ COLORS ============
class C:
    GREEN   = '\033[92m'
    RED     = '\033[91m'
    YELLOW  = '\033[93m'
    BLUE    = '\033[94m'
    CYAN    = '\033[96m'
    MAGENTA = '\033[95m'
    WHITE   = '\033[97m'
    BOLD    = '\033[1m'
    RESET   = '\033[0m'
    DIM     = '\033[2m'

def clear():
    os.system('cls' if os.name == 'nt' else 'clear')

def type_print(text, delay=0.03, color=C.RESET, end='\n'):
    for char in text:
        sys.stdout.write(color + char + C.RESET)
        sys.stdout.flush()
        time.sleep(delay)
    sys.stdout.write(end)

def loading(msg, duration=1.5):
    frames = ['|', '/', '-', '\\']
    end_time = time.time() + duration
    i = 0
    while time.time() < end_time:
        sys.stdout.write(f'\r{C.CYAN}{frames[i % len(frames)]} {msg}{C.RESET}')
        sys.stdout.flush()
        time.sleep(0.08)
        i += 1
    sys.stdout.write(f'\r{C.GREEN}[OK] {msg}{C.RESET}\n')

# ============ GREEN HACKING ANIMATION ============
def matrix_rain(duration=3):
    """Green matrix-style rain for movie feel"""
    cols = 80
    rows = 20
    chars = "01ABCDEF#$%&@!?*<>/\\|"
    end_time = time.time() + duration
    while time.time() < end_time:
        line = ''.join(random.choice(chars) if random.random() > 0.5 else ' '
                       for _ in range(cols))
        sys.stdout.write(f"{C.GREEN}{line}{C.RESET}\n")
        sys.stdout.flush()
        time.sleep(0.04)
    # move cursor up to clear matrix lines
    sys.stdout.write(f"\033[{rows}A")
    for _ in range(rows):
        sys.stdout.write(" " * cols + "\n")
    sys.stdout.write(f"\033[{rows}A")

def boot_sequence():
    """Fake hacker boot log"""
    logs = [
        ("[BOOT] Loading kernel modules...", 0.3),
        ("[NET ] Initializing network stack...", 0.3),
        ("[CRYPTO] Loading AES-256 engine...", 0.4),
        ("[GHOST] Injecting Ghost-Net payload...", 0.6),
        ("[SCAN] Scanning open ports...", 0.5),
        ("[SCAN] Port 22  OPEN  [ssh]", 0.2),
        ("[SCAN] Port 443 OPEN  [https]", 0.2),
        ("[SCAN] Port 8080 OPEN [proxy]", 0.2),
        ("[BYPASS] Firewall bypassed.", 0.5),
        ("[SPOOF] IP spoofed -> 192.168.x.x", 0.4),
        ("[TUNNEL] Encrypted tunnel established.", 0.5),
        ("[ROOT] Access level: ROOT", 0.3),
        ("[READY] Ghost-Net online.", 0.5),
    ]
    for msg, d in logs:
        type_print(msg, 0.008, C.GREEN)
        time.sleep(d)

def hacker_header():
    print()
    print(C.GREEN + C.BOLD + "  =============================================")
    print("        GHOST-NET v3.2  |  Created By ATHEX   ")
    print("        ENCRYPTION: AES-256  |  STATUS: ACTIVE")
    print("  =============================================" + C.RESET)
    print()

# ============ SCENE START ============
clear()

# PHASE 1: Green hacking animation
matrix_rain(duration=2.5)
clear()
boot_sequence()
print()
time.sleep(0.5)

hacker_header()

type_print("     SECURE CHAT -- END-TO-END ENCRYPTED     ", 0.005, C.CYAN)
print()

type_print(f"{C.YELLOW}[CONNECTING TO TARGET]{C.RESET}", 0.03)
loading("Resolving target identity", 1.0)
type_print(f"{C.GREEN}Target Acquired: {C.BOLD}M_JK{C.RESET}", 0.03)
time.sleep(0.5)
print()

type_print(f"{C.DIM}-------------- CHAT LOG --------------{C.RESET}", 0.005)
print()
time.sleep(0.8)

# ----- Soul Hacker sends first message -----
type_print(f"{C.MAGENTA}[Soul Hacker]{C.RESET} {C.DIM}>>{C.RESET} ", 0.02, end='')
type_print("Meerooo", 0.08)
time.sleep(1.2)

# ----- Voice Call Ringing -----
print()
type_print(f"{C.CYAN}[CALL] Incoming Voice Call from {C.BOLD}M_JK TO SOUL HACKER{C.RESET}...", 0.03)
time.sleep(0.8)

for i in range(3):
    sys.stdout.write(f"\r{C.YELLOW}   * Ringing{'.' * (i+1)}{' ' * (3-i)}{C.RESET}")
    sys.stdout.flush()
    time.sleep(0.7)

print()
loading("Connecting call", 1.5)
print()

type_print(f"{C.GREEN}{C.BOLD}[OK] CALL ATTENDED{C.RESET}", 0.03)
time.sleep(0.5)
print()

type_print(f"{C.DIM}=========== CALL IN PROGRESS ==========={C.RESET}", 0.005)
print()
time.sleep(0.8)

type_print(f"{C.MAGENTA}[Soul Hacker]{C.RESET} {C.DIM}(voice){C.RESET}: ", 0.02, end='')
type_print("Assalulaikum...", 0.06)
time.sleep(2)

print()
type_print(f"{C.RED}{C.BOLD}[!] SIGNAL LOST -- CONNECTION TERMINATED{C.RESET}", 0.03)

# Cursor blink at end
print()
for _ in range(3):
    sys.stdout.write(f"\r{C.GREEN}#{C.RESET}")
    sys.stdout.flush()
    time.sleep(0.5)
    sys.stdout.write("\r ")
    sys.stdout.flush()
    time.sleep(0.5)
print()