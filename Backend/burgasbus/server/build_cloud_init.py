"""Create a self-contained, secret-free cloud-init file for a new Ubuntu 24.04 VM.

This only writes a local setup file. It creates no VM, IP address, account or service.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def config():
    def file(source, destination, mode='0644'):
        return {'path': destination, 'owner': 'root:root', 'permissions': mode,
                'content': source.read_text()}
    return {
        'package_update': True,
        'packages': ['python3', 'python3-venv', 'ca-certificates', 'curl'],
        'ssh_pwauth': False,
        'disable_root': True,
        'users': ['default', {'name': 'burgasbus', 'system': True, 'lock_passwd': True,
                              'shell': '/usr/sbin/nologin', 'no_create_home': True}],
        'write_files': [
            file(ROOT.parent / 'import_feed.py', '/opt/burgasbus/import_feed.py'),
            file(ROOT.parent / 'requirements.txt', '/opt/burgasbus/requirements.txt'),
            file(ROOT / 'check_configuration.py', '/opt/burgasbus/check_configuration.py'),
            file(ROOT / 'feeds.env.example', '/opt/burgasbus/feeds.env.example', '0600'),
            file(ROOT / 'burgasbus-importer.service', '/etc/systemd/system/burgasbus-importer.service'),
            file(ROOT / 'install.sh', '/opt/burgasbus/install.sh', '0700'),
            file(ROOT / 'verify-ip.sh', '/opt/burgasbus/verify-ip.sh', '0755'),
        ],
        'runcmd': [['/bin/sh', '/opt/burgasbus/install.sh']],
        'final_message': 'Burgasbus server setup finished. Review cloud-init logs. Importer is inactive pending provider approval.',
    }


if __name__ == '__main__':
    # JSON is also valid YAML; the required header identifies cloud-config user-data.
    output = ROOT / 'cloud-init.yaml'
    output.write_text('#cloud-config\n' + json.dumps(config(), indent=2, ensure_ascii=False) + '\n')
    print('Prepared cloud-init.yaml locally. No cloud resource has been created.')
