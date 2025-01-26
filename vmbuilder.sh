#!/bin/bash

# shellcheck disable=SC2162

###############################################################################
# Proxmox VM Builder
# Author: Originally by Francis Munch, maintained by MinerAle00
# Description: Automated VM creation script using cloud images for Proxmox
###############################################################################

set -euo pipefail

# Constants
readonly GITHUB_REPO="MinerAle00/vmbuilder"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_PATH="$(readlink -f "$0")"
readonly MIN_DISK_SIZE=1
readonly MAX_DISK_SIZE=2048
readonly DEFAULT_CORES=4
readonly DEFAULT_MEMORY=2048
readonly DEFAULT_CPU_TYPE="kvm64"
readonly DEFAULT_VM_TYPE="pc"
readonly DEFAULT_DISPLAY="serial0"

# Initialize cloud images array
declare -A CLOUD_IMAGES
CLOUD_IMAGES=(
    ["Ubuntu 24.04"]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ["Ubuntu 23.10"]="https://cloud-images.ubuntu.com/mantic/current/mantic-server-cloudimg-amd64.img"
    ["Ubuntu 22.04"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64-disk-kvm.img"
    ["Ubuntu 20.04"]="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64-disk-kvm.img"
    ["Debian 12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    ["Debian 11"]="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
    ["Rocky Linux 9.3"]="https://download.rockylinux.org/pub/rocky/9.3/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
    ["AlmaLinux 9.3"]="https://repo.almalinux.org/almalinux/9.3/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    ["Arch Linux"]="https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2"
    ["Fedora 40"]="https://mirror.init7.net/fedora/fedora/linux/releases/40/Cloud/x86_64/images/Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2"
    ["Fedora 39"]="https://mirror.init7.net/fedora/fedora/linux/releases/39/Cloud/x86_64/images/Fedora-Cloud-Base-39-1.5.x86_64.qcow2"
)

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
            echo
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

[[ ! -f "$SCRIPT_PATH" ]] && error_exit "Cannot determine script location"

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
    echo "# Updated and maintained by MinerAle00"
    echo "# github: https://github.com/MinerAle00/vmbuilder"
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
    
    while true; do
        read -r -p "Enter VM ID or press Enter for next available ($next_id): " vm_id
        vm_id=${vm_id:-$next_id}
        
        # Check if ID is in use
        if ! qm status "$vm_id" >/dev/null 2>&1; then
            echo "The VM number will be $vm_id"
            echo
            echo "$vm_id"
            break
        fi
        warning "VM ID $vm_id is already in use"
    done
}

# Get user credentials
get_user_credentials() {
    local username password1 password2 hashed_password
    
    read -r -p "Enter desired VM username: " username
    
    while true; do
        read -r -s -p "Please enter password for the user: " password1; echo
        read -r -s -p "Please repeat password for the user: " password2; echo
        
        [ "$password1" = "$password2" ] && break
        warning "Passwords do not match. Please try again."
        echo
    done
    
    hashed_password=$(openssl passwd -1 -salt SaltSalt "$password1")
    
    # SSH key configuration
    read -r -p "Do you want to add an SSH key? [y/N] " response
    if [[ "$response" =~ ^[Yy] ]]; then
        while true; do
            read -r -p "Enter path to SSH public key: " key_path
            [[ -f "$key_path" ]] && { ssh_key=$(cat "$key_path"); break; }
            warning "SSH key file not found. Please try again."
        done
    fi

    # SSH password authentication
    read -r -p "Enable SSH password authentication? [y/N] " response
    local ssh_password_auth="false"
    if [[ "$response" =~ ^[Yy] ]]; then
        ssh_password_auth="true"
    fi

    echo "username='$username' password='$hashed_password' ssh_key='${ssh_key:-}' ssh_password_auth='$ssh_password_auth'"
}

# Configure storage options
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
            break
        else
            warning "Invalid selection. Please try again."
        fi
    done
    
    echo "$storage"
}

# Configure VM resources
configure_vm() {
    local cores memory vm_id="$1" hostname="$2"
    
    read -r -p "CPU cores [$DEFAULT_CORES]: " cores
    read -r -p "Memory in MB [$DEFAULT_MEMORY]: " memory
    
    cores=${cores:-$DEFAULT_CORES}
    memory=${memory:-$DEFAULT_MEMORY}
    
    info "Creating VM $vm_id ($hostname)..."
    
    qm create "$vm_id" \
        --name "$hostname" \
        --cores "$cores" \
        --memory "$memory" \
        --net0 "virtio,bridge=vmbr0" \
        --bootdisk scsi0 \
        --onboot 1 \
        --agent 1
}

# Main function
main() {
    show_banner
    check_for_updates
    check_prerequisites
    
    # Get basic VM configuration
    local hostname vm_id
    hostname=$(get_hostname)
    vm_id=$(get_vm_id)
    
    # Get user credentials
    eval "$(get_user_credentials)"
    
    # Configure storage
    local storage
    storage=$(configure_storage)
    
    # Create VM
    configure_vm "$vm_id" "$hostname"
    
    success "VM $hostname ($vm_id) created successfully"
}

# Run script
main "$@"
