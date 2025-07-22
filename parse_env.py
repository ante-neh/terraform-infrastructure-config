#!/usr/bin/env python3
import os
import json
import sys

def parse_env_file(file_path):
    env_vars = {}
    if os.path.exists(file_path):
        with open(file_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key.strip()] = value.strip()
    return env_vars

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({"error": "Usage: python parse_env.py <env-file-path>"}))
        sys.exit(1)
    
    env_file = sys.argv[1]
    try:
        result = parse_env_file(env_file)
        print(json.dumps(result))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)