#!/usr/bin/env python3
import argparse
import json
import sys

import pywinauto


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Type totals from count JSON into Excel, moving down each row."
    )
    parser.add_argument(
        "--json",
        dest="json_text",
        help="Raw JSON string from count output.",
    )
    return parser.parse_args()


def _load_json(args: argparse.Namespace):
    if args.json_text:
        return json.loads(args.json_text)

    if not sys.stdin.isatty():
        piped = sys.stdin.read().strip()
        if piped:
            return json.loads(piped)

    raise ValueError("No JSON input provided. Pass --json or pipe JSON via stdin.")


def _extract_total_values(json):
    export_totals = {}

    for section in json.values():
        for item_name, item_value in section.items():
            if "Total" in item_value and item_value["Total"] is not None:
                total = item_value["Total"]
                if total == "-": total = ""
                omni_name = item_value.get("omniName")
                normalized_name = (
                    omni_name.lower()
                    if isinstance(omni_name, str)
                    else item_name.lower()
                )
                export_totals[normalized_name] = total

    return export_totals


def main():
    args = _parse_args()
    json = _load_json(args)
    totals = _extract_total_values(json)

    if not totals:
        raise ValueError("No total values found in JSON input.")

    try:
        app = pywinauto.Application(backend="uia").connect(title_re="Concessions Manager.*")
    except pywinauto.findwindows.ElementNotFoundError:
        raise RuntimeError("Concessions Manager application not found. Please ensure it is running.") from None

    try:
        window = app.top_window()
    except RuntimeError:
        desktop = pywinauto.Desktop(backend='uia')
        taskbar = desktop.Taskbar
        running_apps_toolbar = taskbar.child_window(title="Running applications", control_type="ToolBar")

        print(running_apps_toolbar)
        print(dir(running_apps_toolbar))
        program_button = running_apps_toolbar.child_window(title_re="Concession Manager.*")
        program_button.click_input()

        window = app.top_window()

    window.set_focus()

    try:
        stock_count = window['Revenue CentrePane'] \
            .child_window(title="Stock Count", auto_id="FormStockCount", control_type="Window")
    except pywinauto.findwindows.ElementNotFoundError:
        raise RuntimeError("Stock Count form not found. Please navigate to the Stock Count screen in Concessions Manager.") from None

    data_grid = stock_count \
        .child_window(title="DataGrid", auto_id="dgStock", control_type="Table") \
        .wait('visible')
    rows = [item for item in data_grid.children() if item.friendly_class_name() == "Custom"]

    rect = data_grid.rectangle()
    x = (rect.left + rect.right) // 2
    y = (rect.top + rect.bottom) // 2
    pywinauto.mouse.scroll((x,y), 100)

    count_field = next((item for item in rows[0].children() if item.texts()[0] == "Phys. Count"), None)
    count_field.click_input()

    for row in rows:
        children = row.children()
        name_field = next((item for item in children if item.texts()[0] == "Name"), None)
        name = name_field.legacy_properties()['Value'].lower()

        if name in totals:
            total = totals[name]
            pywinauto.keyboard.send_keys(f"{total}")
        
        pywinauto.keyboard.send_keys("{DOWN}")

if __name__ == '__main__':
    main()
