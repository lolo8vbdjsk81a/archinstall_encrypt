#!/bin/bash
# This script installs an arch linux system with full disk encryption.

echo -ne "\nPlease make sure you have internet connection with configured disk when running this script.\n"

# Input disk to install arch linux on
echo "Please input the disk you are installing the system onto: (e.g. /dev/sda or /dev/nvme0n1p1)"
read DISK

if [[ ! -b "${DISK}" ]]; then
    echo "Error: Disk ${DISK} not found"
    exit 1
fi

echo -ne "\nWARNING: This will erase ALL data on ${DISK}. Are you sure? (Y/N) "
read confirm

if [[ "${confirm}" != "Y" && "${confirm}" != "y" ]]; then
	echo "Aborting."
	exit 1
fi

########## Partitioning ##########
echo "Clearing partition table..."
umount -AR /mnt 2>/dev/null || true
sgdisk -Z "${DISK}"			# zap (destroy)
sgdisk -a 2048 -o ${DISK}	# 2048 is optimal alignment

echo "Creating partitions..."
swap_=$(free -g | awk '/^Mem:/{print $2}')
sgdisk -n 1::+512M -t 1:ef00 -c 1:'EFIBOOT' "${DISK}" # EFI
sgdisk -A 1:set:2 ${DISK}
sgdisk -n 2::+4G -t 2:8200 -c 2:'SWAP' "${DISK}" # SWAP
sgdisk -n 3::-0 -t 3:8300 -c 3:'ROOT' "${DISK}" # ROOT
partprobe "${DISK}"

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
    echo "Error: Partitioning failed"
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

# Execute chroot script
echo -ne "\nEntering chroot environment...\n"
arch-chroot /mnt
