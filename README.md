<div align="center">
  
![vm-builder track](https://github.com/MinerAle00/vmbuilder/assets/66887063/f008673b-9b8f-493d-aeb6-061b4dfd0a92)

# Proxmox VM Builder

A powerful script for automated VM creation using cloud images in Proxmox VE

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Proxmox](https://img.shields.io/badge/Proxmox-7.x%20%7C%208.x-orange)](https://www.proxmox.com/)

</div>

## 🚀 Overview

Proxmox VM Builder is a sophisticated automation script that streamlines the process of creating virtual machines in Proxmox using cloud images. With this tool, you can have a fully configured VM up and running in less than 3 minutes.

Whether you're a Proxmox beginner or an experienced administrator, this script offers a streamlined approach to VM deployment while maintaining full control over the configuration options.

## ✨ Key Features

- **Quick Deployment**: Create and start VMs in under 3 minutes
- **Cloud Image Integration**: Automatic download of the latest cloud images
- **Flexible Configuration**: Comprehensive customization options for your VMs
- **Cluster Support**: Built-in capabilities for Proxmox cluster environments
- **Storage Management**: Smart handling of different storage types and snippets
- **Network Configuration**: Advanced networking options including VLAN support

## 📋 Prerequisites

- Proxmox VE 7.x or 8.x
- Enabled snippet storage in Proxmox
- Sufficient storage space for cloud images
- Network connectivity for image downloads

## 💾 Supported Cloud Images

| Distribution | Version | EOL Date |
|-------------|---------|----------|
| Ubuntu | 24.04 (Noble) | Jun 2029 |
| Ubuntu | 23.10 (Mantic) | Jul 2024 |
| Ubuntu | 22.04 (Jammy) | Apr 2027 |
| Ubuntu | 20.04 (Focal) | Apr 2025 |
| Debian | 12 | Jun 2026 |
| Debian | 11 | Jul 2024 |
| Rocky Linux | 9.3 | May 2027 |
| AlmaLinux | 9.3 | May 2027 |
| Fedora | 40 | May 2025 |
| Fedora | 39 | Dec 2024 |
| Fedora | 38 | May 2024 |
| CentOS | 7 | Jun 2024 |
| Arch Linux | Latest | Rolling |

## 🛠️ Installation

1. Download the script to your Proxmox node:
   ```bash
   wget https://raw.githubusercontent.com/mineraleyt/vmbuilder/main/vmbuilder.sh
   ```

2. Make it executable:
   ```bash
   chmod +x vmbuilder.sh
   ```

3. Verify snippet storage:
   - Navigate to Datacenter → Storage in Proxmox GUI
   - Ensure snippets are enabled on your desired storage

4. Run the script:
   ```bash
   ./vmbuilder.sh
   ```

## 🎯 Configuration Options

### VM Settings
- VM Name and ID
- CPU cores and RAM allocation
- Storage location selection
- Disk size customization
- Display type configuration
- Machine type (pc/q35)
- Boot configuration
- VM protection settings
- Template conversion option

### Network Configuration
- DHCP or Static IP
- VLAN tagging
- Network bridge selection
- Gateway configuration

### User Management
- Username creation
- Password configuration
- SSH key integration
- SSH password authentication toggle

### System Integration
- QEMU guest agent installation
- Autostart configuration
- Cluster node placement
- Storage location for snippets

## 🔄 Workflow

1. **Initial Setup**: Script performs system checks and gathers available resources
2. **User Input**: Interactive prompts for configuration choices
3. **Resource Verification**: Validates all selected options
4. **Image Management**: Downloads cloud image if needed
5. **VM Creation**: Configures and creates the VM with specified settings
6. **Final Configuration**: Applies post-creation settings and optional template conversion

## 🔮 Roadmap

- [ ] Enhanced processor specification options
- [ ] VM ID assignment optimization
- [ ] vIOMMU support evaluation
- [ ] Automatic virtIO RNG installation for RHEL-based VMs
- [ ] Additional package installation options
- [ ] Multi-language support
- [ ] Backup integration
- [ ] Advanced networking features

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## ⚠️ Important Notes

- Always verify snippet storage configuration before running
- Ensure sufficient storage space for cloud images
- Check network connectivity for image downloads
- Review VM ID availability before creation
- Consider using SSH keys over password authentication

## 🙏 Acknowledgments

- Originally written by Francis Munch
- Maintained and enhanced by MinerAleyt
