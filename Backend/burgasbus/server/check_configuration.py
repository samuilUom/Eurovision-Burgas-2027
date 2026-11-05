"""Fail before polling when required server-only settings are missing. Never print values."""
import json
import os
import sys
from urllib.parse import urlsplit


def validate(env):
    for key in ('BURGASBUS_GTFS_URL', 'BURGASBUS_VEHICLES_URL', 'SUPABASE_URL'):
        value = env.get(key, '')
        parsed = urlsplit(value)
        if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.fragment:
            raise ValueError('Missing or invalid ' + key)
    base = urlsplit(env['SUPABASE_URL'])
    if base.path not in ('', '/') or base.query:
        raise ValueError('SUPABASE_URL must be a project origin')
    service_key = env.get('SUPABASE_SERVICE_ROLE_KEY', '')
    if not service_key or service_key.startswith('sb_publishable_'):
        raise ValueError('Set a server service credential, not the mobile publishable key')
    headers = json.loads(env.get('BURGASBUS_HEADERS_JSON', '{}'))
    if not isinstance(headers, dict) or any(not isinstance(k, str) or not isinstance(v, str) or '\n' in k + v or '\r' in k + v for k, v in headers.items()):
        raise ValueError('BURGASBUS_HEADERS_JSON must contain string header names and values')


if __name__ == '__main__':
    try:
        validate(os.environ)
    except Exception:
        print('Server configuration is incomplete or invalid. Review the private feeds.env file.', file=sys.stderr)
        raise SystemExit(1)
    print('Server configuration validated.')
