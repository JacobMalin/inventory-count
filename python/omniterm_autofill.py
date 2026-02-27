#!/usr/bin/env python3
import pywinauto

def main():
    # Example: Find a window with a specific title and send keystrokes
    app = pywinauto.Application().connect(title_re="Conc Inventory Count.xlsm - Excel")
    window = app.window(title_re="Conc Inventory Count.xlsm - Excel")
    
    window.set_focus()
    window.F3.click()

if __name__ == '__main__':
    main()
