#!/bin/bash

# Slime Rancher Save File Transfer Script
# Transfers save files and configuration between Steam Decks

set -euo pipefail

# Steam App ID for Slime Rancher
SLIME_RANCHER_APPID="433340"

# Base paths
STEAM_BASE_PATH="/home/deck/.local/share/Steam"
COMPATDATA_PATH="steamapps/compatdata"
SAVE_PATH="pfx/drive_c/users/steamuser/AppData/LocalLow/Monomi Park/Slime Rancher"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Transfer Slime Rancher save files between Steam Decks"
    echo ""
    echo "Options:"
    echo "  -s, --source HOST       Source device hostname or IP (required)"
    echo "  -d, --dest HOST         Destination device hostname or IP (required)"
    echo "  -u, --user USER         SSH username (default: deck)"
    echo "  -p, --port PORT         SSH port (default: 22)"
    echo "  -n, --dry-run          Show what would be transferred without doing it"
    echo "  -b, --backup           Create backup of existing saves on destination"
    echo "  -v, --verbose          Verbose output"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -s steamdeck -d purpledeck"
    echo "  $0 -s 10.0.0.42 -d 10.0.0.45 -b"
    echo "  $0 -s steamdeck -d purpledeck --dry-run"
}

# Default values
SOURCE_HOST=""
DEST_HOST=""
SSH_USER="deck"
SSH_PORT="22"
DRY_RUN=false
CREATE_BACKUP=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SOURCE_HOST="$2"
            shift 2
            ;;
        -d|--dest)
            DEST_HOST="$2"
            shift 2
            ;;
        -u|--user)
            SSH_USER="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -b|--backup)
            CREATE_BACKUP=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SOURCE_HOST" ]] || [[ -z "$DEST_HOST" ]]; then
    print_error "Source and destination hosts are required"
    show_usage
    exit 1
fi

# SSH options
SSH_OPTS="-p $SSH_PORT -o ConnectTimeout=10 -o BatchMode=yes"
if [[ "$VERBOSE" == false ]]; then
    SSH_OPTS="$SSH_OPTS -q"
fi

# Function to test SSH connectivity
test_ssh_connection() {
    local host=$1
    local description=$2
    
    print_status "Testing SSH connection to $description ($host)..."
    
    if ssh $SSH_OPTS "$SSH_USER@$host" "echo 'Connection successful'" >/dev/null 2>&1; then
        print_success "Connected to $description"
        return 0
    else
        print_error "Failed to connect to $description ($host)"
        return 1
    fi
}

# Function to get full save directory path
get_save_path() {
    echo "$STEAM_BASE_PATH/$COMPATDATA_PATH/$SLIME_RANCHER_APPID/$SAVE_PATH"
}

# Function to check if save directory exists on a host
check_save_directory() {
    local host=$1
    local description=$2
    local save_dir=$(get_save_path)
    
    print_status "Checking for Slime Rancher save directory on $description..."
    
    if ssh $SSH_OPTS "$SSH_USER@$host" "test -d '$save_dir'" 2>/dev/null; then
        print_success "Save directory found on $description"
        return 0
    else
        print_warning "Save directory not found on $description"
        print_status "Attempting to create directory structure..."
        
        if [[ "$DRY_RUN" == false ]]; then
            if ssh $SSH_OPTS "$SSH_USER@$host" "mkdir -p '$save_dir'" 2>/dev/null; then
                print_success "Created save directory on $description"
                return 0
            else
                print_error "Failed to create save directory on $description"
                return 1
            fi
        else
            print_status "[DRY RUN] Would create directory: $save_dir"
            return 0
        fi
    fi
}

# Function to list save files on a host
list_save_files() {
    local host=$1
    local description=$2
    local save_dir=$(get_save_path)
    
    print_status "Listing save files on $description..."
    
    local files=$(ssh $SSH_OPTS "$SSH_USER@$host" "find '$save_dir' -name '*.sav' -o -name '*.cfg' -o -name '*.prf' 2>/dev/null | sort" 2>/dev/null || echo "")
    
    if [[ -n "$files" ]]; then
        local count=$(echo "$files" | wc -l | tr -d ' ')
        print_success "Found $count save/config files on $description"
        if [[ "$VERBOSE" == true ]]; then
            echo "$files" | while read -r file; do
                local basename=$(basename "$file")
                local size=$(ssh $SSH_OPTS "$SSH_USER@$host" "ls -lh '$file' 2>/dev/null | awk '{print \$5}'" 2>/dev/null || echo "?")
                echo "  - $basename ($size)"
            done
        fi
        echo "$files"
    else
        print_warning "No save files found on $description"
        echo ""
    fi
}

# Function to create backup
create_backup() {
    local host=$1
    local description=$2
    local save_dir=$(get_save_path)
    local backup_dir="${save_dir}.backup.$(date +%Y%m%d_%H%M%S)"
    
    print_status "Creating backup on $description..."
    
    if [[ "$DRY_RUN" == false ]]; then
        if ssh $SSH_OPTS "$SSH_USER@$host" "test -d '$save_dir' && cp -r '$save_dir' '$backup_dir'" 2>/dev/null; then
            print_success "Backup created: $backup_dir"
        else
            print_warning "Could not create backup (save directory may not exist)"
        fi
    else
        print_status "[DRY RUN] Would create backup: $backup_dir"
    fi
}

# Function to transfer files
transfer_files() {
    local source_files=$1
    local save_dir=$(get_save_path)
    
    if [[ -z "$source_files" ]]; then
        print_error "No files to transfer"
        return 1
    fi
    
    local file_count=$(echo "$source_files" | wc -l | tr -d ' ')
    print_status "Transferring $file_count files..."
    
    if [[ "$DRY_RUN" == false ]]; then
        # Transfer files one by one to handle spaces in paths properly
        echo "$source_files" | while read -r file; do
            if [[ -n "$file" ]]; then
                local basename=$(basename "$file")
                if [[ "$VERBOSE" == true ]]; then
                    print_status "Transferring $basename..."
                fi
                
                if scp $SSH_OPTS "$SSH_USER@$SOURCE_HOST:$file" "$SSH_USER@$DEST_HOST:$save_dir/" 2>/dev/null; then
                    if [[ "$VERBOSE" == true ]]; then
                        print_success "Transferred $basename"
                    fi
                else
                    print_error "Failed to transfer $basename"
                fi
            fi
        done
        print_success "Transfer completed"
    else
        print_status "[DRY RUN] Would transfer the following files:"
        echo "$source_files" | while read -r file; do
            if [[ -n "$file" ]]; then
                local basename=$(basename "$file")
                echo "  - $basename"
            fi
        done
    fi
}

# Main execution
main() {
    echo "=================================================="
    echo "  Slime Rancher Save File Transfer Script"
    echo "=================================================="
    echo ""
    
    print_status "Source: $SSH_USER@$SOURCE_HOST:$SSH_PORT"
    print_status "Destination: $SSH_USER@$DEST_HOST:$SSH_PORT"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi
    
    echo ""
    
    # Test connections
    if ! test_ssh_connection "$SOURCE_HOST" "source device"; then
        exit 1
    fi
    
    if ! test_ssh_connection "$DEST_HOST" "destination device"; then
        exit 1
    fi
    
    echo ""
    
    # Check save directories
    if ! check_save_directory "$SOURCE_HOST" "source device"; then
        print_error "Source device doesn't have Slime Rancher save directory"
        exit 1
    fi
    
    if ! check_save_directory "$DEST_HOST" "destination device"; then
        exit 1
    fi
    
    echo ""
    
    # List source files
    source_files=$(list_save_files "$SOURCE_HOST" "source device")
    if [[ -z "$source_files" ]]; then
        print_error "No save files found on source device"
        exit 1
    fi
    
    echo ""
    
    # Create backup if requested
    if [[ "$CREATE_BACKUP" == true ]]; then
        create_backup "$DEST_HOST" "destination device"
        echo ""
    fi
    
    # Transfer files
    transfer_files "$source_files"
    
    echo ""
    
    # Verify transfer (only if not dry run)
    if [[ "$DRY_RUN" == false ]]; then
        print_status "Verifying transfer..."
        dest_files=$(list_save_files "$DEST_HOST" "destination device")
        
        if [[ -n "$dest_files" ]]; then
            print_success "Transfer verification completed"
            echo ""
            print_success "Save files successfully transferred!"
            print_status "Launch Slime Rancher on the destination device to access the transferred saves."
        else
            print_error "Transfer verification failed - no files found on destination"
            exit 1
        fi
    else
        print_success "Dry run completed successfully"
    fi
}

# Run main function
main "$@"
