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


def _load_json_payload(args: argparse.Namespace):
    if args.json_text:
        return json.loads(args.json_text)

    if not sys.stdin.isatty():
        piped = sys.stdin.read().strip()
        if piped:
            return json.loads(piped)

    raise ValueError("No JSON input provided. Pass --json or pipe JSON via stdin.")


def _extract_total_values(payload) -> list[str]:
    export_totals: list[str] = []

    for section in payload.values():
        for item_payload in section.values():
            if "Total" in item_payload and item_payload["Total"] is not None:
                total = item_payload["Total"]
                if total == "-": total = "0"
                export_totals.append(total)

    return export_totals


def main():
    args = _parse_args()
    payload = _load_json_payload(args)
    totals = _extract_total_values(payload)

    if not totals:
        raise ValueError("No total values found in JSON input.")

    app = pywinauto.Application(backend="uia").connect(title_re="Conc Inventory Count.xlsm - Excel")
    window = app['Conc Inventory Count.xlsm - Excel']
    actionable_f3 = window['Conc Inventory Count'] \
        .child_window(title="Grid", auto_id="Grid", control_type="DataGrid") \
        .child_window(auto_id="F3") \
        .wait('visible')
    
    window.set_focus()
        
    actionable_f3.select()

    for total in totals:
        pywinauto.keyboard.send_keys(f"{total}{{DOWN}}")

if __name__ == '__main__':
    main()
