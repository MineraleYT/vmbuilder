#!/bin/bash

# shellcheck disable=SC2162

###############################################################################
# Proxmox VM Builder
# Author: Originally by Francis Munch, maintained by MinerAle00
# Description: Automated VM creation script using cloud images for Proxmox
###############################################################################

set -euo pipefail

# Constants
readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
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

# Display banner
show_banner() {
    clear
    cat << "EOF"
#############################################################################################
###
# Welcome to the Proxmox Virtual Machine Builder script that uses Cloud Images
# This will automate so much and make it so easy to spin up a VM machine from a cloud image.
# A VM Machine typically will be spun up and ready in less then 3 minutes.
#
# Originally written by Francis Munch
# github: https://github.com/francismunch/vmbuilder
#
# Updated and maintained by MinerAle00
# github: https://github.com/MinerAle00/vmbuilder
###
#############################################################################################

EOF
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
            echo "$vm_id"
            break
        fi
        warning "VM ID $vm_id is already in use"
    done
}

# Get user credentials
get_user_credentials() {
    local username password1 password2 hashed_password ssh_key ssh_auth="false"
    
    read -r -p "Enter username: " username
    
    while true; do
        read -r -s -p "Enter password: " password1; echo
        read -r -s -p "Confirm password: " password2; echo
        
        [ "$password1" = "$password2" ] && break
        warning "Passwords do not match"
    done
    
    hashed_password=$(openssl passwd -1 -salt SaltSalt "$password1")
    
    read -r -p "Add SSH key? [y/N] " response
    if [[ "$response" =~ ^[Yy] ]]; then
        while true; do
            read -r -p "Path to SSH public key: " key_path
            [[ -f "$key_path" ]] && { ssh_key=$(cat "$key_path"); break; }
            warning "File not found"
        done
    fi
    
    read -r -p "Enable SSH password authentication? [y/N] " response
    [[ "$response" =~ ^[Yy] ]] && ssh_auth="true"
    
    echo "username='$username' password='$hashed_password' ssh_key='${ssh_key:-}' ssh_auth='$ssh_auth'"
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

# Configure storage
configure_storage() {
    local storage vm_id="$1"
    
    # List available storages
    echo "Available storages:"
    mapfile -t storages < <(pvesm status -content images | awk 'NR>1 {print $1}')
    
    select storage in "${storages[@]}"; do
        [[ -n "$storage" ]] && break
        warning "Invalid selection"
    done
    
    echo "$storage"
}

# Import cloud image
import_image() {
    local vm_id="$1" storage="$2" os="$3"
    local image_url="${CLOUD_IMAGES[$os]}"
    local image_file="/tmp/$(basename "$image_url")"
    
    info "Downloading cloud image..."
    wget -O "$image_file" "$image_url" || error_exit "Failed to download image"
    
    info "Importing disk..."
    qm importdisk "$vm_id" "$image_file" "$storage" || error_exit "Failed to import disk"
    
    rm -f "$image_file"
}

# Configure cloud-init
configure_cloudinit() {
    local vm_id="$1" username="$2" password="$3" ssh_key="$4" ssh_auth="$5"
    local config_dir="/etc/pve/nodes/$(hostname)/qemu-server"
    
    # Ensure directory exists
    mkdir -p "$config_dir"
    
    # Create cloud-init config
    cat > "$config_dir/$vm_id.conf" << EOF
user: $username
password: $password
ssh_authorized_keys:
  - ${ssh_key:-}
chpasswd:
  expire: false
ssh_pwauth: $ssh_auth
EOF
}

# Main function
main() {
    show_banner
    check_prerequisites
    
    # Get basic VM configuration
    local hostname vm_id
    hostname=$(get_hostname)
    vm_id=$(get_vm_id)
    
    # Get user credentials
    eval "$(get_user_credentials)"
    
    # Configure storage
    local storage
    storage=$(configure_storage "$vm_id")
    
    # Select and import cloud image
    echo "Available operating systems:"
    select os in "${!CLOUD_IMAGES[@]}"; do
        [[ -n "$os" ]] && break
        warning "Invalid selection"
    done
    
    # Create VM
    configure_vm "$vm_id" "$hostname"
    import_image "$vm_id" "$storage" "$os"
    configure_cloudinit "$vm_id" "$username" "$password" "${ssh_key:-}" "$ssh_auth"
    
    success "VM $hostname ($vm_id) created successfully"
    qm start "$vm_id"
}

# Run script
main "$@"
