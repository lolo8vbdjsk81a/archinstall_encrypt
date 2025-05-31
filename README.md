# Arch Linux Installation Script (Encrypted)
My custom shell script for installing Arch Linux with full disk encryption using LUKS.

## Usage
1. Boot into Arch Linux live environment

2. Connect to the internet or use ethernet.

3. Download the script in live USB environment:
   ```bash
   curl -O https://raw.githubusercontent.com/lolo8vbdjsk81a/archinstall_encrypt/main/0-disk_setup.sh
   ```

4. Run the script in USB live environment:
   ```bash
   sh 0-disk_setup.sh
   ```

5. `1-chroot_setup.sh` is downloaded and executed automatically after first script is run, and removed before rebooting to the new system.

6. `2-user_setup.sh` is downloaded to $HOME from `1-chroot_setup.sh` before rebooting to arch.

7. After rebooting, run the script for installing window manager and softwares:
   ```bash
   ./2-user_setup.sh
   ```
