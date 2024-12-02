#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source utility functions
source "${SCRIPT_DIR}/modules/utils.sh"

# Function to list available templates
list_templates() {
    echo "Available Templates:"
    echo "------------------"
    if ! qm list 2>/dev/null | grep -q "template"; then
        echo "No templates found"
        return 1
    fi
    
    qm list | grep "template" | while read -r line; do
        local vmid=$(echo "$line" | awk '{print $1}')
        local name=$(echo "$line" | awk '{print $2}')
        local status=$(echo "$line" | awk '{print $3}')
        echo "ID: $vmid, Name: $name, Status: $status"
    done
}

# Function to create a template from VM
convert_to_template() {
    local vmid=$1
    if ! check_vmid_exists "$vmid"; then
        echo "Error: VM $vmid does not exist"
        return 1
    fi

    echo "Converting VM $vmid to template..."
    qm stop "$vmid" >/dev/null 2>&1
    if ! qm template "$vmid"; then
        echo "Error: Failed to convert VM to template"
        return 1
    fi
    
    # Store template metadata
    local template_dir="${SCRIPT_DIR}/templates"
    mkdir -p "$template_dir"
    local metadata_file="$template_dir/$vmid.meta"
    
    # Get VM config details
    local name=$(qm config "$vmid" | grep "name:" | cut -d' ' -f2)
    local os_type=$(qm config "$vmid" | grep "ostype:" | cut -d' ' -f2)
    
    # Save metadata
    if ! cat > "$metadata_file" << EOF
name=$name
os_type=$os_type
created=$(date '+%Y-%m-%d %H:%M:%S')
description=Template created from VM $vmid
EOF
    then
        echo "Error: Failed to create template metadata"
        return 1
    fi

    echo "Template created successfully"
    return 0
}

# Function to create VM from template
create_vm_from_template() {
    # List available templates
    if ! list_templates; then
        return 1
    fi
    
    # Get template ID
    echo
    read -p "Enter template ID to use: " template_id
    if ! qm status "$template_id" >/dev/null 2>&1; then
        echo "Error: Template $template_id does not exist"
        return 1
    fi

    # Get new VM ID
    local next_id=$(get_next_vmid)
    read -p "Enter new VM ID [$next_id]: " new_vmid
    new_vmid=${new_vmid:-$next_id}
    
    if check_vmid_exists "$new_vmid"; then
        echo "Error: VM ID $new_vmid already exists"
        return 1
    fi

    # Get new VM name
    read -p "Enter new VM name: " new_name
    if ! validate_hostname "$new_name"; then
        echo "Error: Invalid hostname format"
        return 1
    fi

    # Clone the template
    echo "Creating new VM from template..."
    if ! qm clone "$template_id" "$new_vmid" --name "$new_name"; then
        echo "Error: Failed to clone template"
        return 1
    fi
    
    # Ask about starting the VM
    read -p "Would you like to start the VM now? [y/N] " start_vm
    case $start_vm in
        [Yy]* )
            if ! qm start "$new_vmid"; then
                echo "Error: Failed to start VM"
                return 1
            fi
            echo "VM $new_vmid started"
            ;;
    esac

    echo "VM created successfully from template"
    return 0
}

# Function to create a new template
create_new_template() {
    echo "Creating a new template..."
    
    # Set template creation mode
    export TEMPLATE_MODE=true
    
    # Create base VM
    if ! create_manual_vm; then
        echo "Failed to create base VM"
        return 1
    fi
    
    # Convert the created VM to template
    if ! convert_to_template "$VMID"; then
        echo "Failed to convert VM to template"
        return 1
    fi
    
    return 0
}

# Export functions
export -f list_templates
export -f convert_to_template
export -f create_vm_from_template
export -f create_new_template
