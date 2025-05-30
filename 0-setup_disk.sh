#!/bin/bash
# This script installs an arch linux system with full disk encryption.
SCRIPT_URL="https://raw.githubusercontent.com/lolo8vbdjsk81a/archinstall_encrypt/main/"

echo -ne "\e[36m
 ____  _     _      ____       _               
|  _ \(_)___| | __ / ___|  ___| |_ _   _ _ __  
| | | | / __| |/ / \___ \ / _ \ __| | | | '_ \ 
| |_| | \__ \   <   ___) |  __/ |_| |_| | |_) |
|____/|_|___/_|\_\ |____/ \___|\__|\__,_| .__/ 
                                        |_|    
\e[0m"

echo -e "\nPlease make sure you have internet connection with configured disk when running this script.\n"

# Input disk to install arch linux on
echo -e "\e[33mPlease input the disk you are installing the system onto: (e.g. /dev/sda or /dev/nvme0n1)\e[0m"
read DISK

if [[ ! -b "${DISK}" ]]; then
    echo "Error: Disk ${DISK} not found"
    exit 1
fi

echo -e "\n\e[31mWARNING: This will erase ALL data on ${DISK}. Are you sure? (Y/N)\e[0m "
read confirm

if [[ "${confirm}" != "Y" && "${confirm}" != "y" ]]; then
	echo "Aborting."
	exit 1
fi

########## Partitioning ##########

# Below have 6 sgdisk operations which each one returns a message when finished.
# I will print one message if all 6 are successful.
# 000000 = no operations complete
# 111111 = all operations complete (63 in decimal)

OP_ZAP=1		# 000001
OP_ALIGN=2		# 000010
OP_EFI=4		# 000100
OP_EFI_FLAG=8	# 001000
OP_SWAP=16		# 010000
OP_ROOT=32		# 100000

echo "Clearing partition table..."
umount -AR /mnt 2>/dev/null || true
sgdisk -Z "${DISK}" >/dev/null && status="$((status | OP_ZAP))"	# zap (destroy)
sgdisk -a 2048 -o ${DISK} >/dev/null && status="$((status | OP_ALIGN))"	# 2048 is optimal alignment

echo "Creating partitions..."
swap_=$(free -g | awk '/^Mem:/{print $2}')
sgdisk -n 1::+512M -t 1:ef00 -c 1:'EFIBOOT' "${DISK}" >/dev/null && status="$((status | OP_EFI))"	# EFI
sgdisk -A 1:set:2 ${DISK} >/dev/null && status="$((status | OP_EFI_FLAG))"
sgdisk -n 2::+4G -t 2:8200 -c 2:'SWAP' "${DISK}" >/dev/null && status="$((status | OP_SWAP))"	# SWAP
sgdisk -n 3::-0 -t 3:8300 -c 3:'ROOT' "${DISK}" >/dev/null && status="$((status | OP_ROOT))"	# ROOT

if [ $status -eq 63 ]; then
	echo -e "\e[32mAll partition operations completed successfully. Status: $(printf '%06b' $status)\e[0m"
	partprobe "${DISK}"
else
	echo "Some operations failed. Status bitmap: $(printf '%06b' $status)"
	echo "Failed operations:"
	[ $((status & OP_ZAP)) -eq 0 ] && echo -e "\e[31m- Disk zap failed\e[0m"
	[ $((status & OP_ALIGN)) -eq 0 ] && echo -e "\e[31m- Alignment failed\e[0m"
	[ $((status & OP_EFI)) -eq 0 ] && echo -e "\e[31m- EFI partition creation failed\e[0m"
	[ $((status & OP_EFI_FLAG)) -eq 0 ] && echo -e "\e[31m- EFI flag setting failed\e[0m"
	[ $((status & OP_SWAP)) -eq 0 ] && echo -e "\e[31m- Swap partition creation failed\e[0m"
	[ $((status & OP_ROOT)) -eq 0 ] && echo -e "\e[31m- Root partition creation failed\e[0m"
	exit 1
fi

if [[ "${DISK}" =~ "nvme" ]]; then
    EFI="${DISK}p1"
    SWAP="${DISK}p2"
    ROOT="${DISK}p3"
else
    EFI="${DISK}1"
    SWAP="${DISK}2"
    ROOT="${DISK}3"
fi

# Check if partitions exists
if [[ ! -b "${EFI}" ]] || [[ ! -b "${SWAP}" ]] || [[ ! -b "${ROOT}" ]]; then
    echo -e "\e[31m-Error: Partitioning failed\e[0m"
    exit 1
fi

# Format partitions
echo -ne "\nFormatting EFI and SWAP partitions...\n"
mkfs.fat -F32 "${EFI}"
mkswap "${SWAP}"
swapon "${SWAP}"

########## Full Disk Encryption ##########
echo -ne "\nSetting up encryption for root partition...\n"
cryptsetup luksFormat --batch-mode "${ROOT}"
CRYPT_NAME="cryptroot"

echo "The default name for the encrypted ROOT partition is 'cryptroot', do you want to change it? (Y/N)"
read flag

if [[ "${flag}" == "Y" || "${flag}" == "y" ]]; then
	echo "Enter new name for the encrypted partition:"
	read -r CRYPT_NAME
fi

echo -ne "\nOpens (unlocks) the encrypted container\n"
cryptsetup open "${ROOT}" "${CRYPT_NAME}"

# Format encrypted partition
mkfs.ext4 /dev/mapper/"${CRYPT_NAME}"

# mount partitions
echo -ne "\nMounting partitions...\n"
mount /dev/mapper/"${CRYPT_NAME}" /mnt
mkdir /mnt/boot
mount "${EFI}" /mnt/boot

# Installation
echo -ne "\nInstalling base system...\n"
pacstrap /mnt base base-devel nano vim neovim networkmanager lvm2 cryptsetup grub efibootmgr linux linux-firmware
genfstab -U /mnt > /mnt/etc/fstab

echo -ne "\n\e[32mBase system installed successfully.\e[0m\n"

echo -ne "\nDownloading chroot setup script in /mnt...\n"
curl -o /mnt/1-chroot_setup.sh "https://raw.githubusercontent.com/lolo8vbdjsk81a/archinstall_encrypt/main/1-chroot_setup.sh"
chmod +x /mnt/1-chroot_setup.sh

# Execute chroot script
echo -ne "\n\e[34mEntering chroot environment...\n\e[0m"
arch-chroot /mnt /bin/bash -c "DISK='${DISK}' ROOT='${ROOT}' CRYPT_NAME='${CRYPT_NAME}' ./1-chroot_setup.sh"
