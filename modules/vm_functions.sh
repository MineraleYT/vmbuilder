#!/bin/bash

# Get script directory if not already set
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Source utility functions
source "${SCRIPT_DIR}/modules/utils.sh"

# Function to handle cloud image selection and download
select_cloud_image() {
    local isostorage=$1
    
    if [ ! -d "$isostorage" ]; then
        echo "Error: ISO storage directory does not exist: $isostorage" >&2
        return 1
    }
    
    echo "Please select the cloud image you would like to use:"
    echo "------------------------------------------------"
    
    # Get the OS image mapping
    local os_map_result
    os_map_result=$(list_os_images)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to list OS images" >&2
        return 1
    }
    eval "$os_map_result"
    
    # Get user selection
    read -p "Enter selection number: " selection
    
    # Validate selection
    if [[ ! ${os_map[$selection]} ]]; then
        echo "Error: Invalid selection" >&2
        return 1
    fi
    
    # Parse selection
    IFS='|' read -r os_type version <<< "${os_map[$selection]}"
    
    # Get image details
    local name filename url
    name=$(get_os_image_details "$os_type" "$version" "name")
    filename=$(get_os_image_details "$os_type" "$version" "filename")
    url=$(get_os_image_details "$os_type" "$version" "url")
    
    if [ -z "$name" ] || [ -z "$filename" ] || [ -z "$url" ]; then
        echo "Error: Failed to get image details" >&2
        return 1
    }
    
    # Check if image exists, if not download it
    if [ ! -f "$isostorage/$filename" ]; then
        echo "Downloading cloud image: $name"
        if ! wget -q --show-progress "$url" -O "$isostorage/$filename"; then
            echo "Error: Failed to download image" >&2
            rm -f "$isostorage/$filename"
            return 1
        fi
    else
        echo "Using existing cloud image: $name"
    fi
    
    echo "Selected cloud image: $name"
    echo "Image path: $isostorage/$filename"
    
    # Return the image path
    echo "$isostorage/$filename"
}

# Function to configure networking
configure_networking() {
    local vmid=$1
    local vmbrused=$2
    
    if [ -z "$vmid" ] || [ -z "$vmbrused" ]; then
        echo "Error: Missing required parameters for networking configuration" >&2
        return 1
    }

    local vlan=""
    local ip_config=""

    # VLAN configuration
    read -r -p "Do you need to enter a VLAN number? [Y/n] " vlan_choice
    case $vlan_choice in
        [Yy]*)
            while true; do
                read -p "Enter VLAN number (0-4096): " vlan_num
                if validate_vlan "$vlan_num"; then
                    vlan="tag=$vlan_num"
                    break
                fi
            done
            ;;
    esac

    # IP configuration
    read -p "Use DHCP for IP? [Y/n] " dhcp_choice
    case $dhcp_choice in
        [Nn]*)
            while true; do
                read -p "Enter IP address (format: 192.168.1.50/24): " ip
                if validate_ip "$ip"; then
                    read -p "Enter gateway (format: 192.168.1.1): " gateway
                    if validate_ip "$gateway"; then
                        ip_config="ip=$ip,gw=$gateway"
                        break
                    fi
                fi
                echo "Invalid IP or gateway format"
            done
            ;;
        *)
            ip_config="ip=dhcp"
            ;;
    esac

    # Configure network
    if ! qm set "$vmid" --net0 "virtio,bridge=$vmbrused${vlan:+,$vlan}"; then
        echo "Error: Failed to configure network interface" >&2
        return 1
    fi
    
    if ! qm set "$vmid" --ipconfig0 "$ip_config"; then
        echo "Error: Failed to configure IP settings" >&2
        return 1
    fi
}

# Function to configure resources
configure_resources() {
    local vmid=$1
    if [ -z "$vmid" ]; then
        echo "Error: VM ID not provided" >&2
        return 1
    }

    local cores=4
    local memory=2048
    local disk_size=""

    read -r -p "Would you like to customize CPU and memory? [y/N] " resource_choice
    case $resource_choice in
        [Yy]*)
            while true; do
                read -p "Enter number of CPU cores [4]: " new_cores
                new_cores=${new_cores:-4}
                if validate_cores "$new_cores"; then
                    cores=$new_cores
                    break
                fi
            done

            while true; do
                read -p "Enter memory in MB [2048]: " new_memory
                new_memory=${new_memory:-2048}
                if validate_memory "$new_memory"; then
                    memory=$new_memory
                    break
                fi
            done
            ;;
    esac

    read -r -p "Would you like to resize the disk? [y/N] " resize_choice
    case $resize_choice in
        [Yy]*)
            while true; do
                read -p "Enter additional size in GB: " disk_size
                if [[ $disk_size =~ ^[0-9]+$ ]]; then
                    break
                fi
                echo "Invalid disk size"
            done
            ;;
    esac

    # Configure VM resources
    if ! qm set "$vmid" --cores "$cores"; then
        echo "Error: Failed to set CPU cores" >&2
        return 1
    fi
    
    if ! qm set "$vmid" --memory "$memory"; then
        echo "Error: Failed to set memory" >&2
        return 1
    fi
    
    if [ -n "$disk_size" ]; then
        if ! qm resize "$vmid" scsi0 "+${disk_size}G"; then
            echo "Error: Failed to resize disk" >&2
            return 1
        fi
    fi
}

# Function to configure cloud-init
configure_cloudinit() {
    local vmid=$1
    local snippetstorage=$2
    local vm_hostname=$3
    
    if [ -z "$vmid" ] || [ -z "$snippetstorage" ] || [ -z "$vm_hostname" ]; then
        echo "Error: Missing required parameters for cloud-init configuration" >&2
        return 1
    }

    local username=""
    local password=""
    local ssh_key=""

    # Get username and password
    while true; do
        read -p "Enter username: " username
        if [[ $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            break
        fi
        echo "Invalid username format"
    done

    while true; do
        read -s -p "Enter password: " password
        echo
        read -s -p "Confirm password: " password2
        echo
        [ "$password" = "$password2" ] && break
        echo "Passwords do not match, try again"
    done

    # SSH key configuration
    read -r -p "Add SSH key? [y/N] " ssh_choice
    case $ssh_choice in
        [Yy]*)
            while true; do
                read -p "Enter path to SSH public key: " key_path
                if [ -f "$key_path" ]; then
                    ssh_key=$(cat "$key_path")
                    break
                fi
                echo "File not found"
            done
            ;;
    esac

    # Create cloud-init config
    local ci_file="$snippetstorage/$vmid.yaml"
    if ! cat > "$ci_file" << EOF
#cloud-config
hostname: $vm_hostname
manage_etc_hosts: true
user: $username
password: $(generate_password_hash "$password")
ssh_authorized_keys:
  - ${ssh_key:-""}
chpasswd:
  expire: False
ssh_pwauth: ${ssh_key:+false}
package_upgrade: true
packages:
  - qemu-guest-agent
EOF
    then
        echo "Error: Failed to create cloud-init configuration" >&2
        return 1
    fi

    # Configure cloud-init drive
    if ! qm set "$vmid" --ide2 "$snippetstorage:cloudinit"; then
        echo "Error: Failed to set cloud-init drive" >&2
        return 1
    fi
    
    if ! qm set "$vmid" --boot c --bootdisk scsi0; then
        echo "Error: Failed to set boot configuration" >&2
        return 1
    fi
    
    if ! qm set "$vmid" --serial0 socket --vga serial0; then
        echo "Error: Failed to set display configuration" >&2
        return 1
    fi
}

# Main VM creation function
create_manual_vm() {
    # Get VM ID and hostname
    local vmid hostname
    vmid=$(get_next_vmid)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get VM ID" >&2
        return 1
    fi

    read -p "Enter hostname: " hostname
    if ! validate_hostname "$hostname"; then
        return 1
    fi

    # Select storages
    echo "Selecting storage configuration..."
    local vmstorage isostorage snippetstorage
    
    vmstorage=$(get_available_storages | head -n1)
    if [ -z "$vmstorage" ]; then
        echo "Error: No storage available" >&2
        return 1
    fi
    
    isostorage="/var/lib/vz/template/iso"
    snippetstorage="/var/lib/vz/snippets"

    # Create required directories
    mkdir -p "$isostorage" "$snippetstorage"

    # Select cloud image
    local cloudimage
    cloudimage=$(select_cloud_image "$isostorage")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Create VM
    echo "Creating VM..."
    if ! qm create "$vmid" --name "$hostname" --memory 2048 --cores 2 --net0 virtio --scsihw virtio-scsi-pci; then
        echo "Error: Failed to create VM" >&2
        return 1
    fi

    # Import disk
    echo "Importing disk..."
    if ! qm importdisk "$vmid" "$cloudimage" "$vmstorage"; then
        echo "Error: Failed to import disk" >&2
        return 1
    fi
    
    if ! qm set "$vmid" --scsi0 "$vmstorage:vm-$vmid-disk-0,discard=on"; then
        echo "Error: Failed to configure disk" >&2
        return 1
    fi

    # Configure networking
    echo "Configuring network..."
    if ! configure_networking "$vmid" "vmbr0"; then
        return 1
    fi

    # Configure resources
    echo "Configuring resources..."
    if ! configure_resources "$vmid"; then
        return 1
    fi

    # Configure cloud-init
    echo "Configuring cloud-init..."
    if ! configure_cloudinit "$vmid" "$snippetstorage" "$hostname"; then
        return 1
    fi

    # Handle template mode
    if [ "${TEMPLATE_MODE:-false}" = true ]; then
        if ! qm template "$vmid"; then
            echo "Error: Failed to convert VM to template" >&2
            return 1
        fi
        echo "VM converted to template"
    else
        read -r -p "Start VM now? [y/N] " start_choice
        case $start_choice in
            [Yy]*)
                if ! qm start "$vmid"; then
                    echo "Error: Failed to start VM" >&2
                    return 1
                fi
                ;;
        esac
    fi

    # Store VM ID for other functions
    export VMID=$vmid
    return 0
}

# Export functions
export -f select_cloud_image
export -f configure_networking
export -f configure_resources
export -f configure_cloudinit
export -f create_manual_vm
