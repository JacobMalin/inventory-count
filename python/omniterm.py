#!/usr/bin/env python3
import sys
import json
import pyautogui

def main():
    x, y = pyautogui.locateCenterOnScreen('python/Screenshot 2026-02-26 025921.png', confidence=0.9)
    print(f"First item location: ({x}, {y})")
    pyautogui.moveTo(x, y)

if __name__ == '__main__':
    main()
