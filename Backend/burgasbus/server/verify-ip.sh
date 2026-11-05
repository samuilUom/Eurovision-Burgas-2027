#!/bin/sh
# Run ON THE SERVER after attaching its reserved public IPv4.
# No credentials or app data are sent to these public IP-check endpoints.
set -eu
first=$(curl --noproxy '*' -4 --fail --silent --show-error --max-time 15 https://checkip.amazonaws.com)
second=$(curl --noproxy '*' -4 --fail --silent --show-error --max-time 15 https://api.ipify.org)
python3 - "$first" "$second" <<'PY'
import ipaddress
import sys
first, second = (ipaddress.ip_address(value.strip()) for value in sys.argv[1:])
if first.version != 4 or not first.is_global or first != second:
    raise SystemExit('The outgoing public IPv4 could not be verified consistently.')
print('Observed outgoing public IPv4:', first)
print('Compare this with the RESERVED public IPv4 attached in the cloud console.')
print('Use it in the Burgasbus form only if they match. These checks alone do not reserve an IP.')
PY
