# Valheim Dedicated Server

A complete setup for running a Valheim dedicated server on Linux (Debian/Ubuntu).

## 🚀 Quick Start

```bash
# Run setup (on fresh system)
./setup.sh

# Edit configuration
vim valheim-server.conf

# Check server status
./valheim-server.sh status

# Start the server  
./valheim-server.sh start

# View live logs
./valheim-server.sh logs
```

## 📁 Files Overview

- **`setup.sh`** - Automated setup script for fresh systems
- **`valheim-server.sh`** - Main management script
- **`valheim-server.conf.example`** - Configuration template
- **`valheim-server.conf`** - Your server configuration (created by setup.sh)
- **`install-service.sh`** - Optional systemd service installer
- **`maintenance.sh`** - Automated maintenance script
- **`README.md`** - This documentation

## 🔧 Server Configuration

After running `setup.sh`, edit `valheim-server.conf`:

```bash
# Server Identity - CHANGE THESE!
SERVER_NAME="MyValheimServer"        # Server name in browser
SERVER_PASSWORD="change-this-password"  # Password (min 5 characters!)  
WORLD_NAME="MyWorld"                # World name

# Network Settings
SERVER_PORT="2456"                  # Main game port
SERVER_PUBLIC="1"                   # 1=public, 0=private
CROSSPLAY_ENABLED="0"               # 1=enabled, 0=disabled (recommended for LAN)
```

## 🎮 Connecting to Your Server

After starting the server:

1. In Valheim, go to "Join Game"
2. Click "Add server" 
3. Enter: `YOUR_SERVER_IP:2456`
4. Password: Whatever you set in `valheim-server.conf`

## 📋 Management Commands

| Command | Description |
|---------|-------------|
| `./valheim-server.sh start` | Start the server |
| `./valheim-server.sh stop` | Stop the server |
| `./valheim-server.sh restart` | Restart the server |
| `./valheim-server.sh status` | Show detailed status |
| `./valheim-server.sh update` | Update server via SteamCMD |
| `./valheim-server.sh backup` | Create world backup |
| `./valheim-server.sh logs` | Show live server logs |

## 🔄 Server Updates

```bash
# This will stop server, update, and restart if it was running
./valheim-server.sh update
```

## 💾 World Backups

```bash
# Create backup
./valheim-server.sh backup

# Backups stored in: ~/valheim-backups/
# Format: valheim_WorldName_YYYYMMDD_HHMMSS.tar.gz
# Automatically keeps only last 10 backups
```

## 🐛 Troubleshooting

### Server Won't Start

1. **Check logs**: `./valheim-server.sh logs`
2. **Check disk space**: `df -h` (need ~1GB free)
3. **Check processes**: `ps aux | grep valheim`
4. **Verify files**: `ls -la ~/Steam/steamapps/common/Valheim\ dedicated\ server/`

### Can't Connect to Server

1. **Verify server is running**: `./valheim-server.sh status`
2. **Check ports are listening**: 
   ```bash
   ss -tuln | grep -E ":245[6-8]"
   # Should show ports 2456 and 2457
   ```
3. **Test network connectivity**: `ping YOUR_SERVER_IP`
4. **Check password length**: Must be 5+ characters
5. **Try without crossplay**: Set `CROSSPLAY_ENABLED="0"` in config

### Common Issues & Solutions

| Problem | Solution |
|---------|----------|
| Password too short error | Change password to 5+ characters in config |
| Port already in use | Check for other server instances: `pkill -f valheim_server` |
| Out of disk space | Clean up files or expand storage |
| Server crashes on startup | Check logs, try without crossplay |
| PlayFab connection issues | Disable crossplay: `CROSSPLAY_ENABLED="0"` |

### Important Lessons Learned

1. **Password Requirements**: Valheim requires passwords to be minimum 5 characters
2. **Crossplay Issues**: Can cause PlayFab connection problems on LAN servers
3. **Port Binding**: Server uses multiple ports (2456, 2457, others)
4. **Disk Space**: Keep at least 1GB free for updates and world generation
5. **World Generation**: Takes 1-2 minutes on first startup

## 📊 Server Monitoring

```bash
# Basic status
./valheim-server.sh status

# Monitor logs
tail -f /tmp/valheim-server.log

# Check network ports
ss -tuln | grep valheim

# Monitor resources  
htop
```

## 🔧 Advanced Configuration

### Auto-start on Boot (systemd)

```bash
# Install as systemd service
sudo ./install-service.sh

# Control with systemctl
sudo systemctl start valheim-server
sudo systemctl stop valheim-server
sudo systemctl status valheim-server
```

### Firewall Configuration

```bash
# UFW (Ubuntu)
sudo ufw allow 2456/udp
sudo ufw allow 2457/udp

# iptables  
sudo iptables -A INPUT -p udp --dport 2456 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 2457 -j ACCEPT
```

## 📂 Directory Structure

```
valheim/
├── setup.sh                   # Initial setup script
├── valheim-server.sh          # Main management script
├── valheim-server.conf.example # Configuration template
├── valheim-server.conf        # Your configuration (created by setup)
├── install-service.sh         # systemd service installer
├── maintenance.sh            # Maintenance script
└── README.md                 # This file

~/steamcmd/                   # SteamCMD installation
~/Steam/steamapps/common/Valheim dedicated server/  # Server files
~/valheim-backups/           # World backups
~/.config/unity3d/IronGate/Valheim/worlds_local/    # World saves
```

## 🔗 Useful Resources

- [Valheim Dedicated Server Wiki](https://valheim.fandom.com/wiki/Dedicated_server)
- [SteamCMD Documentation](https://developer.valvesoftware.com/wiki/SteamCMD)  
- [Valheim Server Commands](https://valheim.fandom.com/wiki/Console_Commands)

---

**Need help?** Check the logs with `./valheim-server.sh logs` or run `./valheim-server.sh help`
