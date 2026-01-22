# UBI 9 Virtual Machine Emulator with Non-Root User

This container image adds a non-root user configuration on top of the vm-emu minimal image, providing a secure environment for testing webMethods installations.

## User Configuration

- **User**: `webmethods` (UID: 1001)
- **Group**: `webmethods` (GID: 1001)
- **Home**: `/home/webmethods`

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `IWCD_VM_EMU_AUDIT_BASE_DIR` | `/var/webmethods/audit` | Directory for POSIX utils audit logs and framework audit files |
| `IWCD_VM_EMU_INSTALL_DIR` | `/opt/webmethods` | Target directory for webMethods product installations |
| `IWCD_VM_EMU_LOCAL_SCRIPTS_HOME` | `/mnt/scripts` | Mount point for user-provided test scripts (bind mount expected) |
| `IWCD_VM_EMU_UPD_MGR_HOME` | `/opt/wm-upd-mgr-v11` | Home directory for webMethods Update Manager v11 |
| `IWCD_VM_EMU_USER_HOME` | `/home/webmethods` | Standard home directory for the webmethods user |

## Volumes

The following directories are declared as volumes and owned by the `webmethods` user:

- `${IWCD_VM_EMU_AUDIT_BASE_DIR}` - For POSIX utils audit logs
- `${IWCD_VM_EMU_INSTALL_DIR}` - For webMethods product installations
- `${IWCD_VM_EMU_UPD_MGR_HOME}` - For Update Manager files
- `${IWCD_VM_EMU_LOCAL_SCRIPTS_HOME}` - For user test scripts (bind mount)
- `${IWCD_VM_EMU_USER_HOME}` - For user data and configurations

## Usage

This image is designed to be used with bind mounts for the scripts directory:

```bash
docker run -v /path/to/scripts:/mnt/scripts vm-emu-minimal-u:ubi9
```

All volumes are pre-created and owned by the `webmethods` user (UID 1001), ensuring proper permissions for non-root execution.