#!/bin/bash

# Slime Rancher Save File Transfer Script (Multi-User Support)
# Transfers save files and configuration between Steam Decks
# Supports multiple Steam users per device with interactive selection

set -euo pipefail

# Steam App ID for Slime Rancher
SLIME_RANCHER_APPID="433340"

# Base paths
STEAM_BASE_PATH="/home/deck/.local/share/Steam"
USERDATA_PATH="userdata"
COMPATDATA_PATH="steamapps/compatdata"
SAVE_PATH="pfx/drive_c/users/steamuser/AppData/LocalLow/Monomi Park/Slime Rancher"
CLOUD_PATH="remote"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_prompt() {
    echo -e "${CYAN}[PROMPT]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Transfer Slime Rancher save files between Steam Decks"
    echo "Supports multiple Steam users with interactive or non-interactive selection"
    echo ""
    echo "Options:"
    echo "  -s, --source HOST       Source device hostname or IP (required)"
    echo "  -d, --dest HOST         Destination device hostname or IP (required)"
    echo "  --source-user NAME      Source Steam username (non-interactive mode)"
    echo "  --dest-user NAME        Destination Steam username (non-interactive mode)"
    echo "  -u, --ssh-user USER     SSH username (default: deck)"
    echo "  -p, --port PORT         SSH port (default: 22)"
    echo "  -n, --dry-run          Show what would be transferred without doing it"
    echo "  -b, --backup           Create backup of existing saves on destination"
    echo "  -v, --verbose          Verbose output"
    echo "  --list-users           List Steam users on both devices and exit"
    echo "  --non-interactive      Fail if user selection is required"
    echo "  -h, --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Interactive mode - will prompt for user selection if multiple found"
    echo "  $0 -s steamdeck -d purpledeck"
    echo ""
    echo "  # Non-interactive mode with specific users"
    echo "  $0 -s steamdeck -d purpledeck --source-user \"uncle_who\" --dest-user \"lydia\""
    echo ""
    echo "  # List users on both devices"
    echo "  $0 -s steamdeck -d purpledeck --list-users"
    echo ""
    echo "  # Dry run with backup"
    echo "  $0 -s 10.0.0.42 -d 10.0.0.45 --source-user \"Bob\" --dest-user \"Alice\" -b --dry-run"
}

# Default values
SOURCE_HOST=""
DEST_HOST=""
SOURCE_USER=""
DEST_USER=""
SSH_USER="deck"
SSH_PORT="22"
DRY_RUN=false
CREATE_BACKUP=false
VERBOSE=false
LIST_USERS_ONLY=false
NON_INTERACTIVE=false

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
        --source-user)
            SOURCE_USER="$2"
            shift 2
            ;;
        --dest-user)
            DEST_USER="$2"
            shift 2
            ;;
        -u|--ssh-user)
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
        --list-users)
            LIST_USERS_ONLY=true
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
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

# Function to get Steam user info from loginusers.vdf
get_steam_users() {
    local host=$1
    local description=$2
    
    print_status "Discovering Steam users on $description..."
    
    local loginusers_path="$STEAM_BASE_PATH/config/loginusers.vdf"
    local userdata_path="$STEAM_BASE_PATH/$USERDATA_PATH"
    
    # Get the loginusers.vdf file content
    local vdf_content
    if ! vdf_content=$(ssh $SSH_OPTS "$SSH_USER@$host" "cat '$loginusers_path' 2>/dev/null" 2>/dev/null); then
        print_warning "Could not read loginusers.vdf on $description"
        return 1
    fi
    
    # Get list of user directories
    local user_dirs
    if ! user_dirs=$(ssh $SSH_OPTS "$SSH_USER@$host" "ls -1 '$userdata_path' 2>/dev/null | grep -E '^[0-9]+$'" 2>/dev/null); then
        print_warning "No Steam user directories found on $description"
        return 1
    fi
    
    # Parse user info and check for Slime Rancher data
    local users_json="[]"
    local found_users=false
    
    while read -r user_id; do
        [[ -z "$user_id" ]] && continue
        
        # Check if this user has Slime Rancher data (either Steam Cloud or Proton saves)
        local has_cloud_data=false
        local has_proton_data=false
        
        # Check for Steam Cloud data
        if ssh $SSH_OPTS "$SSH_USER@$host" "test -d '$userdata_path/$user_id/$SLIME_RANCHER_APPID'" 2>/dev/null; then
            has_cloud_data=true
        fi
        
        # Check for Proton save data (this is where actual saves are usually stored)
        if ssh $SSH_OPTS "$SSH_USER@$host" "test -d '$STEAM_BASE_PATH/$COMPATDATA_PATH/$SLIME_RANCHER_APPID' && find '$STEAM_BASE_PATH/$COMPATDATA_PATH/$SLIME_RANCHER_APPID/$SAVE_PATH' -name '*.sav' -type f | head -1" >/dev/null 2>&1; then
            has_proton_data=true
        fi
        
        if [[ "$has_cloud_data" == true ]] || [[ "$has_proton_data" == true ]]; then
            # Extract username from VDF (this is a simplified parser)
            local username
            username=$(echo "$vdf_content" | grep -A 20 "\"$user_id\"" | grep -m1 "\"PersonaName\"" | sed 's/.*"PersonaName"[[:space:]]*"//' | sed 's/".*//' 2>/dev/null || echo "User_$user_id")
            
            if [[ "$VERBOSE" == true ]]; then
                print_status "Found user: $username (ID: $user_id) - Cloud: $has_cloud_data, Proton: $has_proton_data"
            fi
            
            # Add to our users array (using a simple format)
            echo "$user_id|$username|$has_cloud_data|$has_proton_data"
            found_users=true
        fi
    done <<< "$user_dirs"
    
    if [[ "$found_users" == false ]]; then
        print_warning "No Steam users with Slime Rancher data found on $description"
        return 1
    fi
    
    return 0
}

# Function to select user interactively
select_user_interactive() {
    local users_data="$1"
    local description="$2"
    
    print_prompt "Multiple Steam users with Slime Rancher data found on $description:"
    echo ""
    
    local -a user_ids=()
    local -a usernames=()
    local counter=1
    
    while IFS='|' read -r user_id username has_cloud has_proton; do
        [[ -z "$user_id" ]] && continue
        user_ids+=("$user_id")
        usernames+=("$username")
        
        local data_types=""
        [[ "$has_cloud" == "true" ]] && data_types+="Cloud "
        [[ "$has_proton" == "true" ]] && data_types+="Saves"
        [[ -z "$data_types" ]] && data_types="Unknown"
        
        echo "  $counter. $username (ID: $user_id) [$data_types]"
        ((counter++))
    done <<< "$users_data"
    
    echo ""
    print_prompt "Select user number (1-$((counter-1))):"
    
    local selection
    read -r selection
    
    # Validate selection
    if [[ ! "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -ge "$counter" ]]; then
        print_error "Invalid selection: $selection"
        return 1
    fi
    
    local selected_index=$((selection-1))
    echo "${user_ids[$selected_index]}|${usernames[$selected_index]}"
}

# Function to find user by username
find_user_by_name() {
    local users_data="$1"
    local target_username="$2"
    local description="$3"
    
    while IFS='|' read -r user_id username has_cloud has_proton; do
        [[ -z "$user_id" ]] && continue
        if [[ "$username" == "$target_username" ]]; then
            echo "$user_id|$username"
            return 0
        fi
    done <<< "$users_data"
    
    print_error "User '$target_username' not found on $description"
    return 1
}

# Function to get save directory paths for a user
get_user_save_paths() {
    local host=$1
    local user_id=$2
    local description=$3
    
    local cloud_path="$STEAM_BASE_PATH/$USERDATA_PATH/$user_id/$SLIME_RANCHER_APPID"
    local proton_path="$STEAM_BASE_PATH/$COMPATDATA_PATH/$SLIME_RANCHER_APPID/$SAVE_PATH"
    
    echo "cloud:$cloud_path|proton:$proton_path"
}

# Function to list save files for a specific user
list_user_save_files() {
    local host=$1
    local user_id=$2
    local username=$3
    local description=$4
    
    print_status "Listing save files for user '$username' on $description..."
    
    local paths
    paths=$(get_user_save_paths "$host" "$user_id" "$description")
    
    local cloud_path proton_path
    cloud_path=$(echo "$paths" | cut -d'|' -f1 | cut -d':' -f2)
    proton_path=$(echo "$paths" | cut -d'|' -f2 | cut -d':' -f2)
    
    local all_files=""
    
    # Get cloud saves (if any)
    local cloud_files
    if cloud_files=$(ssh $SSH_OPTS "$SSH_USER@$host" "find '$cloud_path' -name '*.sav' -o -name '*.cfg' -o -name '*.prf' 2>/dev/null | sort" 2>/dev/null); then
        if [[ -n "$cloud_files" ]]; then
            if [[ "$VERBOSE" == true ]]; then
                print_status "Found Steam Cloud saves:"
                echo "$cloud_files" | while read -r file; do
                    local basename=$(basename "$file")
                    local size=$(ssh $SSH_OPTS "$SSH_USER@$host" "ls -lh '$file' 2>/dev/null | awk '{print \$5}'" 2>/dev/null || echo "?")
                    echo "  - $basename ($size)"
                done
            fi
            all_files="$cloud_files"
        fi
    fi
    
    # Get Proton saves
    local proton_files
    if proton_files=$(ssh $SSH_OPTS "$SSH_USER@$host" "find '$proton_path' -name '*.sav' -o -name '*.cfg' -o -name '*.prf' 2>/dev/null | sort" 2>/dev/null); then
        if [[ -n "$proton_files" ]]; then
            if [[ "$VERBOSE" == true ]]; then
                print_status "Found Proton saves:"
                echo "$proton_files" | while read -r file; do
                    local basename=$(basename "$file")
                    local size=$(ssh $SSH_OPTS "$SSH_USER@$host" "ls -lh '$file' 2>/dev/null | awk '{print \$5}'" 2>/dev/null || echo "?")
                    echo "  - $basename ($size)"
                done
            fi
            if [[ -n "$all_files" ]]; then
                all_files="$all_files"$'\n'"$proton_files"
            else
                all_files="$proton_files"
            fi
        fi
    fi
    
    if [[ -n "$all_files" ]]; then
        local count=$(echo "$all_files" | wc -l | tr -d ' ')
        print_success "Found $count save/config files for user '$username' on $description"
        echo "$all_files"
    else
        print_warning "No save files found for user '$username' on $description"
        echo ""
    fi
}

# Function to create destination directories for a user
create_user_directories() {
    local host=$1
    local user_id=$2
    local username=$3
    local description=$4
    
    print_status "Creating save directories for user '$username' on $description..."
    
    local paths
    paths=$(get_user_save_paths "$host" "$user_id" "$description")
    
    local cloud_path proton_path
    cloud_path=$(echo "$paths" | cut -d'|' -f1 | cut -d':' -f2)
    proton_path=$(echo "$paths" | cut -d'|' -f2 | cut -d':' -f2)
    
    if [[ "$DRY_RUN" == false ]]; then
        # Create Steam Cloud directory
        ssh $SSH_OPTS "$SSH_USER@$host" "mkdir -p '$cloud_path'" 2>/dev/null || true
        
        # Create Proton directory
        ssh $SSH_OPTS "$SSH_USER@$host" "mkdir -p '$proton_path'" 2>/dev/null || true
        
        print_success "Directories created for user '$username' on $description"
    else
        print_status "[DRY RUN] Would create directories:"
        print_status "  Cloud: $cloud_path"
        print_status "  Proton: $proton_path"
    fi
}

# Function to transfer files between users
transfer_user_files() {
    local source_files="$1"
    local source_user_id="$2"
    local source_username="$3"
    local dest_user_id="$4"
    local dest_username="$5"
    
    if [[ -z "$source_files" ]]; then
        print_error "No files to transfer"
        return 1
    fi
    
    local file_count=$(echo "$source_files" | wc -l | tr -d ' ')
    print_status "Transferring $file_count files from '$source_username' to '$dest_username'..."
    
    # Get destination paths
    local dest_paths
    dest_paths=$(get_user_save_paths "$DEST_HOST" "$dest_user_id" "destination")
    local dest_cloud_path dest_proton_path
    dest_cloud_path=$(echo "$dest_paths" | cut -d'|' -f1 | cut -d':' -f2)
    dest_proton_path=$(echo "$dest_paths" | cut -d'|' -f2 | cut -d':' -f2)
    
    if [[ "$DRY_RUN" == false ]]; then
        # Transfer files
        echo "$source_files" | while read -r file; do
            if [[ -n "$file" ]]; then
                local basename=$(basename "$file")
                local dest_path
                
                # Determine destination based on source path
                if [[ "$file" == *"/userdata/"* ]]; then
                    dest_path="$dest_cloud_path"
                else
                    dest_path="$dest_proton_path"
                fi
                
                if [[ "$VERBOSE" == true ]]; then
                    print_status "Transferring $basename to $(echo "$dest_path" | sed 's|.*/\([^/]*/[^/]*\)$|\1|')..."
                fi
                
                if scp $SSH_OPTS "$SSH_USER@$SOURCE_HOST:$file" "$SSH_USER@$DEST_HOST:$dest_path/" 2>/dev/null; then
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
                local dest_type
                if [[ "$file" == *"/userdata/"* ]]; then
                    dest_type="Cloud"
                else
                    dest_type="Proton"
                fi
                echo "  - $basename ($dest_type)"
            fi
        done
    fi
}

# Function to create backup for a user
create_user_backup() {
    local host=$1
    local user_id=$2
    local username=$3
    local description=$4
    
    print_status "Creating backup for user '$username' on $description..."
    
    local paths
    paths=$(get_user_save_paths "$host" "$user_id" "$description")
    
    local cloud_path proton_path
    cloud_path=$(echo "$paths" | cut -d'|' -f1 | cut -d':' -f2)
    proton_path=$(echo "$paths" | cut -d'|' -f2 | cut -d':' -f2)
    
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [[ "$DRY_RUN" == false ]]; then
        local backup_created=false
        
        # Backup cloud data if it exists
        if ssh $SSH_OPTS "$SSH_USER@$host" "test -d '$cloud_path'" 2>/dev/null; then
            local cloud_backup="${cloud_path}.backup.$timestamp"
            if ssh $SSH_OPTS "$SSH_USER@$host" "cp -r '$cloud_path' '$cloud_backup'" 2>/dev/null; then
                print_success "Cloud backup created: $(basename "$cloud_backup")"
                backup_created=true
            fi
        fi
        
        # Backup proton data if it exists
        if ssh $SSH_OPTS "$SSH_USER@$host" "test -d '$proton_path'" 2>/dev/null; then
            local proton_backup="${proton_path}.backup.$timestamp"
            if ssh $SSH_OPTS "$SSH_USER@$host" "cp -r '$proton_path' '$proton_backup'" 2>/dev/null; then
                print_success "Proton backup created: $(basename "$proton_backup")"
                backup_created=true
            fi
        fi
        
        if [[ "$backup_created" == false ]]; then
            print_warning "No existing data to backup for user '$username'"
        fi
    else
        print_status "[DRY RUN] Would create backups with timestamp: $timestamp"
    fi
}

# Main execution
main() {
    echo "=========================================================="
    echo "  Slime Rancher Save Transfer Script (Multi-User)"
    echo "=========================================================="
    echo ""
    
    print_status "Source: $SSH_USER@$SOURCE_HOST:$SSH_PORT"
    print_status "Destination: $SSH_USER@$DEST_HOST:$SSH_PORT"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi
    
    if [[ -n "$SOURCE_USER" ]] && [[ -n "$DEST_USER" ]]; then
        print_status "Non-interactive mode: '$SOURCE_USER' → '$DEST_USER'"
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
    
    # Discover users
    print_status "========== User Discovery =========="
    
    local source_users dest_users
    if ! source_users=$(get_steam_users "$SOURCE_HOST" "source device"); then
        print_error "Failed to discover Steam users on source device"
        exit 1
    fi
    
    if ! dest_users=$(get_steam_users "$DEST_HOST" "destination device"); then
        print_error "Failed to discover Steam users on destination device"
        exit 1
    fi
    
    # If only listing users, do that and exit
    if [[ "$LIST_USERS_ONLY" == true ]]; then
        echo ""
        print_success "Steam users with Slime Rancher data:"
        echo ""
        echo "Source device ($SOURCE_HOST):"
        while IFS='|' read -r user_id username has_cloud has_proton; do
            [[ -z "$user_id" ]] && continue
            local data_types=""
            [[ "$has_cloud" == "true" ]] && data_types+="Cloud "
            [[ "$has_proton" == "true" ]] && data_types+="Saves"
            echo "  - $username (ID: $user_id) [$data_types]"
        done <<< "$source_users"
        
        echo ""
        echo "Destination device ($DEST_HOST):"
        while IFS='|' read -r user_id username has_cloud has_proton; do
            [[ -z "$user_id" ]] && continue
            local data_types=""
            [[ "$has_cloud" == "true" ]] && data_types+="Cloud "
            [[ "$has_proton" == "true" ]] && data_types+="Saves"
            echo "  - $username (ID: $user_id) [$data_types]"
        done <<< "$dest_users"
        exit 0
    fi
    
    # Select source user
    local source_user_id source_username
    if [[ -n "$SOURCE_USER" ]]; then
        # Non-interactive mode
        local source_selection
        if ! source_selection=$(find_user_by_name "$source_users" "$SOURCE_USER" "source device"); then
            exit 1
        fi
        source_user_id=$(echo "$source_selection" | cut -d'|' -f1)
        source_username=$(echo "$source_selection" | cut -d'|' -f2)
        print_success "Source user: $source_username (ID: $source_user_id)"
    else
        # Interactive mode
        local source_user_count
        source_user_count=$(echo "$source_users" | wc -l | tr -d ' ')
        
        if [[ "$source_user_count" -eq 1 ]]; then
            source_user_id=$(echo "$source_users" | cut -d'|' -f1)
            source_username=$(echo "$source_users" | cut -d'|' -f2)
            print_success "Single source user found: $source_username (ID: $source_user_id)"
        else
            if [[ "$NON_INTERACTIVE" == true ]]; then
                print_error "Multiple source users found but non-interactive mode specified"
                exit 1
            fi
            
            local source_selection
            if ! source_selection=$(select_user_interactive "$source_users" "source device"); then
                exit 1
            fi
            source_user_id=$(echo "$source_selection" | cut -d'|' -f1)
            source_username=$(echo "$source_selection" | cut -d'|' -f2)
        fi
    fi
    
    # Select destination user
    local dest_user_id dest_username
    if [[ -n "$DEST_USER" ]]; then
        # Non-interactive mode - try to find existing user or create new
        local dest_selection
        if dest_selection=$(find_user_by_name "$dest_users" "$DEST_USER" "destination device" 2>/dev/null); then
            dest_user_id=$(echo "$dest_selection" | cut -d'|' -f1)
            dest_username=$(echo "$dest_selection" | cut -d'|' -f2)
            print_success "Destination user: $dest_username (ID: $dest_user_id)"
        else
            print_warning "Destination user '$DEST_USER' not found - this will require manual Steam setup"
            # For now, we'll use the first available user or exit
            local dest_user_count
            dest_user_count=$(echo "$dest_users" | wc -l | tr -d ' ')
            if [[ "$dest_user_count" -eq 1 ]]; then
                dest_user_id=$(echo "$dest_users" | cut -d'|' -f1)
                dest_username=$(echo "$dest_users" | cut -d'|' -f2)
                print_warning "Using existing user: $dest_username (ID: $dest_user_id)"
            else
                print_error "Cannot determine destination user automatically"
                exit 1
            fi
        fi
    else
        # Interactive mode
        local dest_user_count
        dest_user_count=$(echo "$dest_users" | wc -l | tr -d ' ')
        
        if [[ "$dest_user_count" -eq 1 ]]; then
            dest_user_id=$(echo "$dest_users" | cut -d'|' -f1)
            dest_username=$(echo "$dest_users" | cut -d'|' -f2)
            print_success "Single destination user found: $dest_username (ID: $dest_user_id)"
        else
            if [[ "$NON_INTERACTIVE" == true ]]; then
                print_error "Multiple destination users found but non-interactive mode specified"
                exit 1
            fi
            
            local dest_selection
            if ! dest_selection=$(select_user_interactive "$dest_users" "destination device"); then
                exit 1
            fi
            dest_user_id=$(echo "$dest_selection" | cut -d'|' -f1)
            dest_username=$(echo "$dest_selection" | cut -d'|' -f2)
        fi
    fi
    
    echo ""
    print_status "========== File Operations =========="
    
    # List source files
    local source_files
    source_files=$(list_user_save_files "$SOURCE_HOST" "$source_user_id" "$source_username" "source device")
    if [[ -z "$source_files" ]]; then
        print_error "No save files found for user '$source_username' on source device"
        exit 1
    fi
    
    echo ""
    
    # Create destination directories
    create_user_directories "$DEST_HOST" "$dest_user_id" "$dest_username" "destination device"
    
    echo ""
    
    # Create backup if requested
    if [[ "$CREATE_BACKUP" == true ]]; then
        create_user_backup "$DEST_HOST" "$dest_user_id" "$dest_username" "destination device"
        echo ""
    fi
    
    # Transfer files
    transfer_user_files "$source_files" "$source_user_id" "$source_username" "$dest_user_id" "$dest_username"
    
    echo ""
    
    # Verify transfer (only if not dry run)
    if [[ "$DRY_RUN" == false ]]; then
        print_status "Verifying transfer..."
        local dest_files
        dest_files=$(list_user_save_files "$DEST_HOST" "$dest_user_id" "$dest_username" "destination device")
        
        if [[ -n "$dest_files" ]]; then
            print_success "Transfer verification completed"
            echo ""
            print_success "Save files successfully transferred!"
            print_success "From: '$source_username' on $SOURCE_HOST"
            print_success "To: '$dest_username' on $DEST_HOST"
            echo ""
            print_status "Launch Slime Rancher as '$dest_username' on the destination device to access the transferred saves."
        else
            print_error "Transfer verification failed - no files found for destination user"
            exit 1
        fi
    else
        print_success "Dry run completed successfully"
        print_status "Would transfer from '$source_username' to '$dest_username'"
    fi
}

# Run main function
main "$@"
