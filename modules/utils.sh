#!/bin/bash

# Get script directory if not already set
if [ -z "$SCRIPT_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Display header function
display_header() {
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
}

# Function to parse JSON using jq
parse_json() {
    local json_file=$1
    local query=$2

    # Check if file exists
    if [ ! -f "$json_file" ]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    }

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "jq is required but not installed. Installing..."
        if ! apt-get update && apt-get install -y jq; then
            echo "Error: Failed to install jq" >&2
            return 1
        fi
    fi

    # Parse JSON with error handling
    local result
    result=$(jq -r "$query" "$json_file" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to parse JSON" >&2
        return 1
    fi

    echo "$result"
}

# Function to list available OS images
list_os_images() {
    local json_file="$SCRIPT_DIR/config/os_images.json"
    
    # Check if config file exists
    if [ ! -f "$json_file" ]; then
        echo "Error: OS images configuration file not found" >&2
        return 1
    }

    local count=1
    declare -A os_map

    # Get all OS names using jq with error handling
    while IFS= read -r os_name; do
        while IFS= read -r version; do
            local name
            name=$(parse_json "$json_file" ".${os_name}.\"${version}\".name")
            if [ $? -ne 0 ]; then
                echo "Error: Failed to parse OS image data" >&2
                return 1
            fi
            echo "$count) $name"
            os_map["$count"]="${os_name}|${version}"
            ((count++))
        done < <(parse_json "$json_file" ".${os_name} | keys[]")
    done < <(parse_json "$json_file" "keys[]")

    # Export the os_map array for use in other functions
    declare -p os_map
}

# Function to get OS image details
get_os_image_details() {
    local json_file="$SCRIPT_DIR/config/os_images.json"
    local os_type=$1
    local version=$2
    local field=$3
    
    # Check parameters
    if [ -z "$os_type" ] || [ -z "$version" ] || [ -z "$field" ]; then
        echo "Error: Missing required parameters for get_os_image_details" >&2
        return 1
    }

    parse_json "$json_file" ".${os_type}.\"${version}\".${field}"
}

# Function to validate input
validate_input() {
    local input=$1
    local pattern=$2
    if [[ $input =~ $pattern ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get next available VM ID
get_next_vmid() {
    local vmid
    vmid=$(pvesh get /cluster/nextid 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get next VM ID" >&2
        return 1
    fi
    echo "$vmid"
}

# Function to check if a VM ID exists
check_vmid_exists() {
    local vmid=$1
    if [ -z "$vmid" ]; then
        echo "Error: VM ID not provided" >&2
        return 1
    fi
    qm status "$vmid" >/dev/null 2>&1
}

# Function to validate hostname
validate_hostname() {
    local hostname=$1
    if [ -z "$hostname" ]; then
        echo "Error: Hostname not provided" >&2
        return 1
    fi
    if [[ ! $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
        echo "Error: Invalid hostname. Use only alphanumeric characters and hyphens." >&2
        return 1
    fi
    return 0
}

# Function to get available storages
get_available_storages() {
    if [ ! -f "/etc/pve/storage.cfg" ]; then
        echo "Error: Proxmox storage configuration not found" >&2
        return 1
    fi
    awk '{if(/:/) print $2}' /etc/pve/storage.cfg
}

# Function to get available network bridges
get_network_bridges() {
    if [ ! -f "/etc/network/interfaces" ]; then
        echo "Error: Network interfaces configuration not found" >&2
        return 1
    fi
    awk '{if(/vmbr/) print $2}' /etc/network/interfaces | sort -u
}

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [ -z "$ip" ]; then
        echo "Error: IP address not provided" >&2
        return 1
    fi
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}(/[0-9]{1,2})?$ ]]; then
        return 1
    fi
    return 0
}

# Function to check if running in cluster
is_cluster() {
    [ -f "/etc/pve/corosync.conf" ]
    return $?
}

# Function to get local node name
get_local_node() {
    if [ ! -f "/etc/hostname" ]; then
        echo "Error: Hostname file not found" >&2
        return 1
    fi
    cat '/etc/hostname'
}

# Function to get available cluster nodes
get_cluster_nodes() {
    if ! is_cluster; then
        return 1
    fi
    pvecm nodes | awk '{print $3}' | sed '/Name/d'
}

# Function to validate memory size
validate_memory() {
    local mem=$1
    if [ -z "$mem" ]; then
        echo "Error: Memory size not provided" >&2
        return 1
    fi
    if [[ ! $mem =~ ^[0-9]+$ ]] || [ "$mem" -lt 512 ] || [ "$mem" -gt 1048576 ]; then
        echo "Error: Invalid memory size. Must be between 512 and 1048576 MB" >&2
        return 1
    fi
    return 0
}

# Function to validate CPU cores
validate_cores() {
    local cores=$1
    if [ -z "$cores" ]; then
        echo "Error: Number of cores not provided" >&2
        return 1
    fi
    if [[ ! $cores =~ ^[0-9]+$ ]] || [ "$cores" -lt 1 ] || [ "$cores" -gt 128 ]; then
        echo "Error: Invalid number of cores. Must be between 1 and 128" >&2
        return 1
    fi
    return 0
}

# Function to check if a path exists
check_path_exists() {
    if [ -z "$1" ]; then
        echo "Error: Path not provided" >&2
        return 1
    fi
    [ -e "$1" ]
    return $?
}

# Function to validate VLAN ID
validate_vlan() {
    local vlan=$1
    if [ -z "$vlan" ]; then
        echo "Error: VLAN ID not provided" >&2
        return 1
    fi
    if [[ ! $vlan =~ ^[0-9]+$ ]] || [ "$vlan" -lt 0 ] || [ "$vlan" -gt 4096 ]; then
        echo "Error: Invalid VLAN ID. Must be between 0 and 4096" >&2
        return 1
    fi
    return 0
}

# Function to generate a secure password hash
generate_password_hash() {
    local password=$1
    if [ -z "$password" ]; then
        echo "Error: Password not provided" >&2
        return 1
    fi
    openssl passwd -1 -salt SaltSalt "$password"
}

# Export all functions
export -f display_header
export -f parse_json
export -f list_os_images
export -f get_os_image_details
export -f validate_input
export -f get_next_vmid
export -f check_vmid_exists
export -f validate_hostname
export -f get_available_storages
export -f get_network_bridges
export -f validate_ip
export -f is_cluster
export -f get_local_node
export -f get_cluster_nodes
export -f validate_memory
export -f validate_cores
export -f check_path_exists
export -f validate_vlan
export -f generate_password_hash
