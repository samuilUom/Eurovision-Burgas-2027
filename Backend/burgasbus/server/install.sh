#!/bin/sh
# Runs only on a NEW dedicated Ubuntu server through cloud-init.
set -eu
python3 -m venv /opt/burgasbus/venv
/opt/burgasbus/venv/bin/python -m pip install --disable-pip-version-check -r /opt/burgasbus/requirements.txt
install -d -m 0700 -o root -g root /etc/burgasbus
systemctl daemon-reload
# Deliberately not started: provider approval and private feed settings are still pending.
systemctl disable burgasbus-importer.service
printf '%s\n' 'Server files installed. The feed importer is inactive until access is approved.'
