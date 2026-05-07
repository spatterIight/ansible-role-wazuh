#/usr/bin/env python3

import sys
import requests
import json
from requests.auth import HTTPBasicAuth

# Read configuration parameters
alert_file = sys.argv[1]
user = sys.argv[2].split(":")[0]
hook_url = sys.argv[3]

# Read the alert file
with open(alert_file) as f:
    alert_json = json.loads(f.read())

# Generate request
headers = {'content-type': 'application/json'}

# Send the request
response = requests.post(hook_url, data=json.dumps(alert_json), headers=headers)

# Uncomment this line for debugging
# print(json.dumps(json.loads(response.text), sort_keys=True, indent=4, separators=(",", ": ")))

sys.exit(0)
