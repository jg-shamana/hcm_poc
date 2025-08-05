#!/usr/bin/env python3.12

import sys
import time
import os
from datetime import datetime

def main():
    print("=" * 50)
    print("HCM POC Application Starting...")
    print(f"Python version: {sys.version}")
    print(f"Environment: {os.getenv('ENVIRONMENT', 'unknown')}")
    print(f"Project: {os.getenv('PROJECT_NAME', 'unknown')}")
    print(f"Start time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    
    counter = 0
    try:
        while True:
            counter += 1
            current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            print(f"[{current_time}] Counter: {counter} - Application running normally")
            
            # stdout をフラッシュして即座に出力する
            sys.stdout.flush()
            
            time.sleep(10)
    except KeyboardInterrupt:
        print("Application received interrupt signal, shutting down gracefully...")
        sys.exit(0)
    except Exception as e:
        print(f"ERROR: Unexpected error occurred: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
