#!/usr/bin/env python3
import sys
import json

def main():
    args = sys.argv[1:]
    out = {"received": args, "count": len(args)}
    print(json.dumps(out))

if __name__ == '__main__':
    main()
