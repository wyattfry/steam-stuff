#!/bin/bash
# Install Valheim server as systemd service

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

echo "Installing Valheim server systemd service..."

# Create the service file
cat > /etc/systemd/system/valheim-server.service << 'SERVICE'
[Unit]
Description=Valheim Dedicated Server
After=network.target

[Service]
Type=forking
User=valheim
Group=valheim
WorkingDirectory=/home/valheim
ExecStart=/home/valheim/valheim-server.sh start
ExecStop=/home/valheim/valheim-server.sh stop
Restart=always
RestartSec=30
PIDFile=/tmp/valheim-server.pid

[Install]
WantedBy=multi-user.target
SERVICE

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable valheim-server

echo "✅ Valheim server service installed!"
echo ""
echo "Usage:"
echo "  sudo systemctl start valheim-server    # Start server"
echo "  sudo systemctl stop valheim-server     # Stop server"
echo "  sudo systemctl status valheim-server   # Check status"
echo "  sudo systemctl enable valheim-server   # Enable auto-start"
echo "  sudo systemctl disable valheim-server  # Disable auto-start"
