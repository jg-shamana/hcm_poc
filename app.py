#!/usr/bin/env python3.12

import sys
import time
from datetime import datetime

def main():
    counter = 0
    try:
        while True:
            counter += 1
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f"[{current_time}] counter: {counter}")
            time.sleep(10)
    except KeyboardInterrupt:
            sys.exit(0)

if __name__ == "__main__":
    main()
