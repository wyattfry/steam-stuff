#!/bin/bash

# Valheim Dedicated Server Management Script
# Usage: ./valheim-server.sh [start|stop|restart|status|update|backup|logs|help]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/valheim-server.conf"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if server is running
is_server_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

# Start server
start_server() {
    if is_server_running; then
        print_warning "Server is already running (PID: $(cat $PID_FILE))"
        return 0
    fi

    print_info "Starting Valheim server..."
    print_info "Server: $SERVER_NAME | World: $WORLD_NAME | Port: $SERVER_PORT"

    cd "$SERVER_DIR" || exit 1

    export templdpath=$LD_LIBRARY_PATH
    export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH
    export SteamAppId=892970

    # Build command arguments
    local crossplay_arg=""
    if [[ "$CROSSPLAY_ENABLED" == "1" ]]; then
        crossplay_arg="-crossplay"
    fi

    # Start server in background
    nohup ./valheim_server.x86_64 \
        -name "$SERVER_NAME" \
        -port "$SERVER_PORT" \
        -world "$WORLD_NAME" \
        -password "$SERVER_PASSWORD" \
        -public "$SERVER_PUBLIC" \
        $crossplay_arg \
        > "$LOG_FILE" 2>&1 &

    local server_pid=$!
    echo $server_pid > "$PID_FILE"

    export LD_LIBRARY_PATH=$templdpath

    # Wait a moment and check if it started successfully
    sleep 3
    if is_server_running; then
        print_status "Server started successfully (PID: $server_pid)"
        print_info "Logs: tail -f $LOG_FILE"
    else
        print_error "Server failed to start. Check logs: $LOG_FILE"
        return 1
    fi
}

# Stop server
stop_server() {
    if ! is_server_running; then
        print_warning "Server is not running"
        return 0
    fi

    local pid=$(cat "$PID_FILE")
    print_info "Stopping server (PID: $pid)..."
    
    kill "$pid"
    sleep 5

    if kill -0 "$pid" 2>/dev/null; then
        print_warning "Server didn't stop gracefully, force killing..."
        kill -KILL "$pid"
        sleep 2
    fi

    rm -f "$PID_FILE"
    print_status "Server stopped"
}

# Server status
show_status() {
    echo "=== Valheim Server Status ==="
    echo "Server Name: $SERVER_NAME"
    echo "World: $WORLD_NAME"
    echo "Port: $SERVER_PORT"
    echo "Password: $SERVER_PASSWORD"
    echo ""

    if is_server_running; then
        local pid=$(cat "$PID_FILE")
        print_status "Server is RUNNING (PID: $pid)"
        
        echo ""
        echo "Network Status:"
        ss -tulpn | grep -E ":245[6-8]|valheim" || echo "No network ports detected"
        
        echo ""
        echo "Memory Usage:"
        ps -p "$pid" -o pid,ppid,%mem,%cpu,cmd --no-headers 2>/dev/null || echo "Process info unavailable"
    else
        print_error "Server is NOT running"
    fi
}

# Update server
update_server() {
    print_info "Updating Valheim server..."
    
    # Stop server if running
    local was_running=false
    if is_server_running; then
        was_running=true
        stop_server
    fi

    cd "$STEAMCMD_DIR" || exit 1
    
    print_info "Running SteamCMD update..."
    ./steamcmd.sh +force_install_dir "$SERVER_DIR" +login anonymous +app_update 896660 validate +quit

    if [[ $? -eq 0 ]]; then
        print_status "Server updated successfully"
        
        if [[ "$was_running" == "true" ]]; then
            print_info "Restarting server..."
            start_server
        fi
    else
        print_error "Server update failed"
        return 1
    fi
}

# Create world backup
backup_world() {
    local backup_dir="$HOME/valheim-backups"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_name="valheim_${WORLD_NAME}_${timestamp}"
    
    mkdir -p "$backup_dir"
    
    print_info "Creating backup: $backup_name"
    
    # Backup world files
    local world_dir="$HOME/.config/unity3d/IronGate/Valheim/worlds_local"
    if [[ -d "$world_dir" ]]; then
        tar -czf "$backup_dir/${backup_name}.tar.gz" -C "$world_dir" "${WORLD_NAME}.db" "${WORLD_NAME}.fwl" 2>/dev/null
        
        if [[ $? -eq 0 ]]; then
            print_status "Backup created: $backup_dir/${backup_name}.tar.gz"
            
            # Keep only last 10 backups
            cd "$backup_dir" && ls -t valheim_*.tar.gz | tail -n +11 | xargs -r rm
        else
            print_error "Backup failed"
        fi
    else
        print_error "World directory not found: $world_dir"
    fi
}

# Show logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        print_error "Log file not found: $LOG_FILE"
    fi
}

# Show help
show_help() {
    echo "Valheim Dedicated Server Management Script"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  start     Start the server"
    echo "  stop      Stop the server"  
    echo "  restart   Restart the server"
    echo "  status    Show server status"
    echo "  update    Update server files via SteamCMD"
    echo "  backup    Create world backup"
    echo "  logs      Show server logs (follow mode)"
    echo "  help      Show this help message"
    echo ""
    echo "Configuration file: $CONFIG_FILE"
    echo "Log file: $LOG_FILE"
}

# Main script logic
case "${1:-help}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        sleep 2
        start_server
        ;;
    status)
        show_status
        ;;
    update)
        update_server
        ;;
    backup)
        backup_world
        ;;
    logs)
        show_logs
        ;;
    help|*)
        show_help
        ;;
esac
