#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create required directories first
mkdir -p "${SCRIPT_DIR}/templates"
mkdir -p "${SCRIPT_DIR}/modules"
mkdir -p "${SCRIPT_DIR}/config"

# Source required modules
source "${SCRIPT_DIR}/modules/utils.sh"
source "${SCRIPT_DIR}/modules/vm_functions.sh"
source "${SCRIPT_DIR}/modules/template_functions.sh"

# Function to check dependencies
check_dependencies() {
    local deps=("wget" "openssl" "qm" "pvesh")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo "Error: Missing required dependencies: ${missing[*]}" >&2
        return 1
    fi

    # Check for Proxmox specific files
    if [ ! -f "/usr/bin/pvesh" ]; then
        echo "Error: This script must be run on a Proxmox VE server" >&2
        return 1
    fi

    # Check for storage configuration
    if [ ! -f "/etc/pve/storage.cfg" ]; then
        echo "Error: Proxmox storage configuration not found" >&2
        return 1
    fi

    return 0
}

# Function to check configuration files
check_config() {
    local config_file="${SCRIPT_DIR}/config/os_images.json"
    
    if [ ! -f "$config_file" ]; then
        echo "Error: OS images configuration file not found: $config_file" >&2
        return 1
    fi

    # Validate JSON syntax
    if ! jq empty "$config_file" 2>/dev/null; then
        echo "Error: Invalid JSON in configuration file" >&2
        return 1
    fi

    return 0
}

# Main menu function
show_main_menu() {
    while true; do
        display_header
        echo "Please select an option:"
        echo "1) Create a manual virtual machine"
        echo "2) Create a template"
        echo "3) Create a virtual machine from template"
        echo "4) List available templates"
        echo "5) Exit"
        echo
        read -p "Enter your choice (1-5): " choice
        
        case $choice in
            1)
                create_manual_vm
                if [ $? -eq 0 ]; then
                    echo "VM creation completed successfully"
                else
                    echo "VM creation failed"
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                create_new_template
                if [ $? -eq 0 ]; then
                    echo "Template creation completed successfully"
                else
                    echo "Template creation failed"
                fi
                read -p "Press Enter to continue..."
                ;;
            3)
                create_vm_from_template
                if [ $? -eq 0 ]; then
                    echo "VM creation from template completed successfully"
                else
                    echo "VM creation from template failed"
                fi
                read -p "Press Enter to continue..."
                ;;
            4)
                list_templates
                read -p "Press Enter to continue..."
                ;;
            5)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Check if running as root
if [ "$(id -u)" != "0" ]; then
    echo "Error: This script must be run as root" >&2
    exit 1
fi

# Perform initial checks
if ! check_dependencies; then
    exit 1
fi

if ! check_config; then
    exit 1
fi

# Start the script
show_main_menu
