#!/bin/bash

# shellcheck disable=SC2162

###############################################################################
# Proxmox VM Builder
# Author: Originally by Francis Munch, maintained by Mineraleyt
# Description: Automated VM creation script using cloud images for Proxmox
###############################################################################

set -euo pipefail

# Constants
readonly GITHUB_REPO="mineraleyt/vmbuilder"
readonly GITHUB_BRANCH="dev"  # Change to "main" for stable version
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_PATH="$(readlink -f "$0")"
readonly SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
readonly CLOUD_IMAGES_FILE="$SCRIPT_DIR/cloud_images.json"
readonly MIN_DISK_SIZE=1
readonly MAX_DISK_SIZE=2048
readonly DEFAULT_CORES=4
readonly DEFAULT_MEMORY=2048
readonly DEFAULT_CPU_TYPE="kvm64"
readonly DEFAULT_VM_TYPE="pc"
readonly DEFAULT_DISPLAY="serial0"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Error handling functions
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}Warning: $1${NC}" >&2
}

success() {
    echo -e "${GREEN}Success: $1${NC}"
}

info() {
    echo "Info: $1"
}

# Load cloud images
load_cloud_images() {
    [[ -f "$CLOUD_IMAGES_FILE" ]] || error_exit "Cloud images file not found: $CLOUD_IMAGES_FILE"
    
    # Check if jq is available
    if command -v jq >/dev/null 2>&1; then
        if ! jq empty "$CLOUD_IMAGES_FILE" 2>/dev/null; then
            error_exit "Invalid JSON in cloud images file"
        fi
    else
        warning "jq not found. Basic JSON validation only."
        # Basic check for valid JSON
        if ! grep -q '^{' "$CLOUD_IMAGES_FILE"; then
            error_exit "Invalid JSON in cloud images file"
        fi
    fi
}

# Select cloud image
select_cloud_image() {
    load_cloud_images
    local image_url=""
    
    # Check if jq is available for better JSON parsing
    if ! command -v jq >/dev/null 2>&1; then
        error_exit "jq is required for OS selection"
    fi

    # Create array of OS information
    declare -a os_list
    while IFS= read -r os_info; do
        os_list+=("$os_info")
    done < <(jq -r '.images[] | "\(.os)|\(.version)|\(.codename // \"-\")"' "$CLOUD_IMAGES_FILE")

    # Display available operating systems
    echo "Available operating systems:"
    echo
    local i=1
    for os_info in "${os_list[@]}"; do
        IFS='|' read -r os version codename <<< "$os_info"
        printf "%2d) %-20s %-10s %-15s\n" "$i" "$os" "$version" "$codename"
        ((i++))
    done
    echo

    # Get user selection
    local selection
    while true; do
        read -r -p "Select an operating system (enter number): " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && \
           [ "$selection" -ge 1 ] && \
           [ "$selection" -le "${#os_list[@]}" ]; then
            image_url=$(jq -r ".images[$(( selection - 1 ))].url" "$CLOUD_IMAGES_FILE")
            break
        else
            warning "Invalid selection. Please try again."
        fi
    done
    
    [[ -n "$image_url" ]] || error_exit "Failed to get image URL"
    printf "%s" "$image_url"
}

# Check for script updates
check_for_updates() {
    info "Checking for updates..."
    
    if ! command -v curl &> /dev/null; then
        warning "curl is required for update checks. Skipping update check."
        return
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    if curl -sL "https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_BRANCH/vmbuilder.sh" -o "$temp_file"; then
        if ! cmp -s "$SCRIPT_PATH" "$temp_file"; then
            echo -e "${YELLOW}New updates available!${NC}"
            read -r -p "Would you like to update now? [y/N] " response
            echo
            
            if [[ "$response" =~ ^[Yy] ]]; then
                info "Downloading update..."
                
                # Preserve execute permissions
                local current_perms
                current_perms=$(stat -c %a "$SCRIPT_PATH")
                
                # Replace current script with new version
                if mv "$temp_file" "$SCRIPT_PATH"; then
                    chmod "$current_perms" "$SCRIPT_PATH"
                    success "Update successful! Please restart the script."
                    exit 0
                else
                    rm -f "$temp_file"
                    error_exit "Failed to install update. Please update manually."
                fi
            fi
        else
            info "No updates available. You have the latest version."
        fi
    else
        rm -f "$temp_file"
        warning "Failed to check for updates. Continuing with current version."
    fi
    
    rm -f "$temp_file"
}

# Display banner
show_banner() {
    clear
    cat << "EOF"
╔════════════════════════════════════════════════════════════════════════════════╗
║                    🚀 Proxmox Virtual Machine Builder                          ║
╠════════════════════════════════════════════════════════════════════════════════╣
║                                                                                ║
║  Create cloud-based VMs in Proxmox quickly and easily                          ║
║  Typical deployment time: < 3 minutes                                          ║
║                                                                                ║
║  Features:                                                                     ║
║  • Automated cloud image deployment                                            ║
║  • Multiple OS support (Ubuntu, Debian, Fedora, etc.)                          ║
║  • User and SSH key configuration                                              ║
║  • Network and storage customization                                           ║
║                                                                                ║
╠════════════════════════════════════════════════════════════════════════════════╣
║  📦 Originally by Francis Munch  (github.com/francismunch/vmbuilder)           ║
║  🔧 Maintained by Mineraleyt     (github.com/mineraleyt/vmbuilder)             ║
╚════════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    [[ $EUID -eq 0 ]] || error_exit "This script must be run as root"
    [[ -f "/etc/pve/storage.cfg" ]] || error_exit "This script must be run on a Proxmox VE host"

    local required_commands=("pvesh" "qm" "wget" "openssl")
    for cmd in "${required_commands[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || error_exit "Required command not found: $cmd"
    done

    # Install jq if not present
    if ! command -v jq >/dev/null 2>&1; then
        info "Installing jq..."
        if ! apt-get update >/dev/null 2>&1; then
            error_exit "Failed to update package lists"
        fi
        if ! DEBIAN_FRONTEND=noninteractive apt-get install -y jq >/dev/null 2>&1; then
            error_exit "Failed to install jq"
        fi
        success "jq installed successfully"
    fi

    echo
    info "Taking a 5-7 seconds to gather information..."
    echo
}

# Get valid hostname
get_hostname() {
    local hostname
    while true; do
        read -r -p "Enter desired hostname for the Virtual Machine: " hostname
        [[ "$hostname" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] && break
        warning "Invalid hostname. Use only letters, numbers, and hyphens (not at start/end)"
    done
    echo "$hostname"
}

# Get VM ID
get_vm_id() {
    local next_id vm_id
    next_id=$(pvesh get /cluster/nextid)
    
    read -r -p "Enter VM ID or press Enter for next available ($next_id): " vm_id
    vm_id=${vm_id:-$next_id}
    
    # Check if ID is in use
    if ! qm status "$vm_id" >/dev/null 2>&1; then
        echo
        echo "The VM number will be $vm_id"
        echo
        printf "%s" "$vm_id"
        return 0
    else
        error_exit "VM ID $vm_id is already in use"
    fi
}

# Get user credentials
get_user_credentials() {
    local username password1 password2 hashed_password ssh_key ssh_auth="false"
    
    read -r -p "Enter desired VM username: " username
    
    while true; do
        read -r -s -p "Please enter password for the user: " password1; echo
        read -r -s -p "Please repeat password for the user: " password2; echo
        
        [ "$password1" = "$password2" ] && break
        warning "Passwords do not match. Please try again."
        echo
    done
    
    hashed_password=$(openssl passwd -1 -salt SaltSalt "$password1")
    
    read -r -p "Do you want to add an SSH key? [y/N] " response
    if [[ "$response" =~ ^[Yy] ]]; then
        while true; do
            read -r -p "Enter path to SSH public key: " key_path
            [[ -f "$key_path" ]] && { ssh_key=$(cat "$key_path"); break; }
            warning "File not found. Please try again."
        done
    fi
    
    read -r -p "Enable SSH password authentication? [y/N] " response
    [[ "$response" =~ ^[Yy] ]] && ssh_auth="true"
    
    echo "username='$username' password='$hashed_password' ssh_key='${ssh_key:-}' ssh_auth='$ssh_auth'"
}

# Configure storage
configure_storage() {
    info "Configuring storage options..."
    
    echo "Please select the storage the VM will run on:"
    local storage
    mapfile -t storages < <(awk '{if(/:/) print $2}' /etc/pve/storage.cfg)
    
    PS3="Select storage number: "
    select storage in "${storages[@]}"; do
        if [[ -n "$storage" ]]; then
            echo "The storage you selected for the VM is $storage"
            echo
            printf "%s" "$storage"
            break
        else
            warning "Invalid selection. Please try again."
        fi
    done
}

# Configure VM resources
configure_vm() {
    local cores memory vm_id="$1" hostname="$2" image_url="$3"
    
    read -r -p "CPU cores [$DEFAULT_CORES]: " cores
    read -r -p "Memory in MB [$DEFAULT_MEMORY]: " memory
    
    cores=${cores:-$DEFAULT_CORES}
    memory=${memory:-$DEFAULT_MEMORY}
    
    info "Creating VM $vm_id ($hostname)..."
    
    # Download the cloud image
    local image_file temp_dir
    temp_dir=$(mktemp -d)
    image_file="$temp_dir/$(basename "$image_url")"
    
    info "Starting cloud image download..."
    echo "URL: $image_url"
    echo "Destination: $image_file"
    echo

    if ! wget --quiet --show-progress --progress=bar:force:noscroll -O "$image_file" "$image_url" 2>&1; then
        rm -rf "$temp_dir"
        error_exit "Failed to download cloud image. Please check your internet connection and try again."
    fi
    
    # Verify file was downloaded and is not empty
    if [[ ! -s "$image_file" ]]; then
        rm -rf "$temp_dir"
        error_exit "Downloaded image file is empty"
    fi
    
    # Create and configure VM
    info "Creating VM configuration..."
    if ! qm create "$vm_id" \
        --name "$hostname" \
        --cores "$cores" \
        --memory "$memory" \
        --net0 "virtio,bridge=vmbr0" \
        --bootdisk scsi0 \
        --onboot 1 \
        --agent 1; then
        rm -rf "$temp_dir"
        error_exit "Failed to create VM"
    fi
    
    # Import the disk
    info "Importing disk..."
    if ! qm importdisk "$vm_id" "$image_file" "$storage"; then
        rm -rf "$temp_dir"
        qm destroy "$vm_id"
        error_exit "Failed to import disk"
    fi
    
    # Configure the imported disk
    info "Configuring disk..."
    if ! qm set "$vm_id" --scsihw virtio-scsi-pci --scsi0 "$storage:vm-$vm_id-disk-0,discard=on"; then
        qm destroy "$vm_id"
        error_exit "Failed to configure disk"
    fi
    
    # Configure cloud-init
    info "Setting up cloud-init..."
    if ! qm set "$vm_id" --ide2 "$storage:cloudinit"; then
        qm destroy "$vm_id"
        error_exit "Failed to configure cloud-init drive"
    fi
    
    # Set user data
    if ! qm set "$vm_id" --ciuser "$username" --cipassword "$password" --sshkeys "$ssh_key"; then
        qm destroy "$vm_id"
        error_exit "Failed to configure cloud-init user data"
    fi
    
    # Ask about disk resize
    local disk_size
    read -r -p "Enter additional disk size in GB (0 for no resize): " disk_size
    if [[ "$disk_size" =~ ^[0-9]+$ ]] && [ "$disk_size" -gt 0 ]; then
        info "Resizing disk..."
        if ! qm resize "$vm_id" scsi0 "+${disk_size}G"; then
            warning "Failed to resize disk, continuing anyway..."
        fi
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    success "VM configured successfully"
    
    # Ask about starting the VM
    read -r -p "Start the VM now? [y/N] " start_vm
    if [[ "$start_vm" =~ ^[Yy] ]]; then
        info "Starting VM..."
        if ! qm start "$vm_id"; then
            warning "Failed to start VM"
        else
            success "VM started successfully"
        fi
    fi
}

# Main function
main() {
    show_banner
    check_for_updates
    check_prerequisites
    
    # Get basic VM configuration
    local hostname vm_id image_url user_creds storage
    
    info "Configuring VM basics..."
    hostname=$(get_hostname) || error_exit "Failed to get hostname"
    vm_id=$(get_vm_id) || error_exit "Failed to get VM ID"
    
    echo
    info "Selecting operating system..."
    image_url=$(select_cloud_image) || error_exit "Failed to select operating system"
    
    echo
    info "Configuring user access..."
    user_creds=$(get_user_credentials) || error_exit "Failed to get user credentials"
    eval "$user_creds"
    
    echo
    info "Configuring storage..."
    storage=$(configure_storage) || error_exit "Failed to configure storage"
    
    echo
    info "Creating and configuring VM..."
    configure_vm "$vm_id" "$hostname" "$image_url"
    
    echo
    info "VM Details:"
    echo "  Hostname: $hostname"
    echo "  VM ID: $vm_id"
    echo "  Storage: $storage"
    echo
    success "VM creation completed successfully"
    echo "You can manage this VM through the Proxmox web interface or using 'qm' commands"
}

# Run script
main "$@"
