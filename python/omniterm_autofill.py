#!/usr/bin/env python3
import argparse
import json
import sys
import time

import pywinauto


# Toggle here to disable all pywinauto timing without touching call sites.
ENABLE_PYWINAUTO_TIMING = True


def _pw_timed(label: str, fn):
    if not ENABLE_PYWINAUTO_TIMING:
        return fn()

    started = time.perf_counter()
    try:
        return fn()
    finally:
        elapsed_ms = (time.perf_counter() - started) * 1000
        print(f"[pywinauto-timing] {label}: {elapsed_ms:.2f} ms", file=sys.stderr)


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


def _extract_values(json_text):
    export_totals = {}
    export_damages = {}

    for section in json_text.values():
        for item_name, item_value in section.items():
            omni_name = item_value.get("omniName")
            normalized_name = (
                omni_name.lower()
                if isinstance(omni_name, str)
                else item_name.lower()
            )
            normalized_name = normalized_name.replace("&", "")
            
            if "Total" in item_value and item_value["Total"] is not None:
                total = item_value["Total"]
                if total == "-": total = ""
                sanitized_total = "".join(ch for ch in str(total) if ch.isdigit())
                export_totals[normalized_name] = sanitized_total
            if "Damaged" in item_value and item_value["Damaged"] is not None:
                damaged = item_value["Damaged"]
                sanitized_damaged = "".join(ch for ch in str(damaged) if ch.isdigit())
                export_damages[normalized_name] = sanitized_damaged

    return export_totals, export_damages


def main():
    args = _parse_args()
    json_text = _load_json(args)
    totals, damages = _extract_values(json_text)
    expected = {}

    if not totals:
        raise ValueError("No total values found in JSON input.")

    try:
        app = _pw_timed(
            "Application.connect",
            lambda: pywinauto.Application(backend="uia").connect(title_re="Concessions Manager.*"),
        )
    except pywinauto.findwindows.ElementNotFoundError:
        raise RuntimeError("Concessions Manager application not found. Please ensure it is running.") from None

    try:
        window = _pw_timed("Application.top_window", lambda: app.top_window())
    except RuntimeError:
        desktop = _pw_timed("Desktop.init", lambda: pywinauto.Desktop(backend="uia"))
        taskbar = desktop.Taskbar
        running_apps_toolbar = _pw_timed(
            "Taskbar.child_window:Running applications",
            lambda: taskbar.child_window(title="Running applications", control_type="ToolBar"),
        )

        program_button = _pw_timed(
            "Running applications.child_window:Concession Manager",
            lambda: running_apps_toolbar.child_window(title_re="Concession Manager.*"),
        )
        _pw_timed("Program button.click_input", lambda: program_button.click_input())

        window = _pw_timed("Application.top_window", lambda: app.top_window())

    _pw_timed("Window.set_focus", lambda: window.set_focus())

    try:
        stock_count = _pw_timed(
            "Stock Count.child_window",
            lambda: window["Revenue CentrePane"].child_window(
                title="Stock Count", auto_id="FormStockCount", control_type="Window"
            ),
        )
    except pywinauto.findwindows.ElementNotFoundError:
        raise RuntimeError("Stock Count form not found. Please navigate to the Stock Count screen in Concessions Manager.") from None

    data_grid_spec = _pw_timed(
        "DataGrid.child_window",
        lambda: stock_count.child_window(auto_id="dgStock", control_type="Table"),
    )
    try:
        data_grid = _pw_timed(
            "DataGrid.wait(visible,fast)",
            lambda: data_grid_spec.wait("visible", timeout=1.0, retry_interval=0.1),
        )
    except pywinauto.timings.TimeoutError:
        data_grid = _pw_timed(
            "DataGrid.wait(visible,fallback)",
            lambda: data_grid_spec.wait("visible", timeout=10.0, retry_interval=0.2),
        )

    rows = []
    for item in _pw_timed("DataGrid.children", lambda: data_grid.children()):
        if _pw_timed("Row.friendly_class_name", lambda item=item: item.friendly_class_name()) == "Custom":
            rows.append(item)

    rect = _pw_timed("DataGrid.rectangle", lambda: data_grid.rectangle())
    x = (rect.left + rect.right) // 2
    y = (rect.top + rect.bottom) // 2
    _pw_timed("mouse.scroll", lambda: pywinauto.mouse.scroll((x, y), 100))

    count_field = None
    for item in _pw_timed("First row.children", lambda: rows[0].children()):
        texts = _pw_timed("Field.texts", lambda item=item: item.texts())
        if texts and texts[0] == "Phys. Count":
            count_field = item
            break

    _pw_timed("Count field.click_input", lambda: count_field.click_input())

    all_keys = ""
    for row in rows:
        children = _pw_timed("Row.children", lambda row=row: row.children())

        name_field = None
        expected_field = None
        for item in children:
            texts = _pw_timed("Name field.texts", lambda item=item: item.texts())
            print(texts)
            if texts and texts[0] == "Name":
                name_field = item
            elif texts and texts[0] == "Calc. Qty \xa0":
                expected_field = item
                
            if name_field and expected_field:
                break
            
        name = _pw_timed("Name field.legacy_properties", lambda: name_field.legacy_properties())["Value"].lower().strip()
        expected_text = _pw_timed("Expected field.legacy_properties", lambda: expected_field.legacy_properties())["Value"]
        
        expected_digits = "".join(ch for ch in expected_text if ch.isdigit() or ch == '.')
        expected_value = int(double(expected_digits)) if expected_digits else 0

        expected[name] = expected_value

        name = name.replace("&", "")

        all_keys += "{BACKSPACE}"
        
        if name in totals:
            total = totals[name]
            all_keys += f"{total}"
        
        all_keys += "{DOWN}"
    
    _pw_timed("keyboard.send_keys:all_keys", lambda: pywinauto.keyboard.send_keys(all_keys, pause=0.01))
    print(json.dumps(expected))

if __name__ == '__main__':
    main()
