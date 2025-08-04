#!/usr/bin/env python3.12

import subprocess
import sys
import os
import time
from datetime import datetime

def get_commit_id():
    try:
        if not os.path.exists('.git') and not subprocess.run(['git', 'rev-parse', '--git-dir'],
                                                            capture_output=True, text=True).returncode == 0:
            print("error: this directory is not a git repository")
            return None

        result = subprocess.run(['git', 'rev-parse', 'HEAD'],
                              capture_output=True, text=True, check=True)
        commit_id = result.stdout.strip()
        return commit_id

    except subprocess.CalledProcessError as e:
        print(f"error: git command failed: {e}")
        return None
    except FileNotFoundError:
        print("error: git command not found")
        return None

def main():
    commit_id = get_commit_id()

    if commit_id:
        print(f"current commit ID: {commit_id}")

        short_commit_id = commit_id[:7]
        print(f"short commit ID: {short_commit_id}")

        counter = 0
        try:
            while True:
                counter += 1
                current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                print(f"[{current_time}] counter: {counter} - Commit ID: {short_commit_id}")
                time.sleep(10)
        except KeyboardInterrupt:
            sys.exit(0)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
