#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="/home/redditbot/Projects/TradeFlair"
SERVICE_DIR="$PROJECT_DIR/services"

sudo ln -sf "$SERVICE_DIR/tradeflair-api.service" \
  /etc/systemd/system/tradeflair-api.service

sudo ln -sf "$SERVICE_DIR/tradeflair-hourly-worker.service" \
  /etc/systemd/system/tradeflair-hourly-worker.service

sudo systemctl daemon-reload

sudo systemctl enable tradeflair-api.service
sudo systemctl enable tradeflair-hourly-worker.service

sudo systemctl restart tradeflair-api.service
sudo systemctl restart tradeflair-hourly-worker.service

sudo systemctl status tradeflair-api.service --no-pager
sudo systemctl status tradeflair-hourly-worker.service --no-pager