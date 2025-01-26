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
    
    # Check if jq is available for better JSON parsing
    if command -v jq >/dev/null 2>&1; then
        # Use jq to get formatted list of images
        echo "Available operating systems:"
        echo
        
        # Create array of OS choices
        mapfile -t os_list < <(jq -r '.images[] | "\(.os) \(.version) (\(.codename // ""))"' "$CLOUD_IMAGES_FILE" | sed 's/  / /g' | sed 's/ ()//g')
        
        PS3="Select an operating system (enter number): "
        select os in "${os_list[@]}"; do
            if [[ -n "$os" ]]; then
                # Get the URL for selected OS
                local os_name version
                read -r os_name version _ <<< "$os"
                image_url=$(jq -r --arg os "$os_name" --arg ver "$version" '.images[] | select(.os == $os and .version == $ver) | .url' "$CLOUD_IMAGES_FILE")
                break
            else
                warning "Invalid selection. Please try again."
            fi
        done
    else
        # Fallback to basic parsing if jq is not available
        warning "jq not installed. Using basic selection method."
        # Read the file line by line and extract OS information
        while IFS= read -r line; do
            if [[ $line =~ \"os\":\ *\"([^\"]+)\" ]]; then
                os_name="${BASH_REMATCH[1]}"
                echo "$os_name"
            fi
        done < "$CLOUD_IMAGES_FILE"
    fi
    
    echo "$image_url"
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
    
    if curl -sL "https://raw.githubusercontent.com/$GITHUB_REPO/main/vmbuilder.sh" -o "$temp_file"; then
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
    echo "#############################################################################################"
    echo "###"
    echo "# Welcome to the Proxmox Virtual Machine Builder script that uses Cloud Images"
    echo "# This will automate so much and make it so easy to spin up a VM machine from a cloud image."
    echo "# A VM Machine typically will be spun up and ready in less then 3 minutes."
    echo "#"
    echo "# Originally written by Francis Munch"
    echo "# github: https://github.com/francismunch/vmbuilder"
    echo "#"
    echo "# Updated and maintained by Mineraleyt"
    echo "# github: https://github.com/mineraleyt/vmbuilder"
    echo "###"
    echo "#############################################################################################"
    echo
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

    # Recommend jq for better JSON handling
    if ! command -v jq >/dev/null 2>&1; then
        warning "jq is recommended for better JSON handling. Install with: apt install jq"
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
    local image_file
    image_file="/tmp/$(basename "$image_url")"
    info "Downloading cloud image..."
    wget -O "$image_file" "$image_url" || error_exit "Failed to download cloud image"
    
    # Create and configure VM
    qm create "$vm_id" \
        --name "$hostname" \
        --cores "$cores" \
        --memory "$memory" \
        --net0 "virtio,bridge=vmbr0" \
        --bootdisk scsi0 \
        --onboot 1 \
        --agent 1 || error_exit "Failed to create VM"
    
    # Import the disk
    info "Importing disk..."
    qm importdisk "$vm_id" "$image_file" "$storage" || error_exit "Failed to import disk"
    
    # Clean up
    rm -f "$image_file"
}

# Main function
main() {
    show_banner
    check_for_updates
    check_prerequisites
    
    # Get basic VM configuration
    local hostname vm_id image_url
    hostname=$(get_hostname)
    vm_id=$(get_vm_id)
    image_url=$(select_cloud_image)
    
    # Get user credentials
    eval "$(get_user_credentials)"
    
    # Configure storage
    local storage
    storage=$(configure_storage)
    
    # Create VM
    configure_vm "$vm_id" "$hostname" "$image_url"
    
    success "VM $hostname ($vm_id) created successfully"
}

# Run script
main "$@"
