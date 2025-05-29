#!/bin/bash
# This script installs an arch linux system with full disk encryption.

echo -ne "\nPlease make sure you have internet connection with configured disk when running this script.\n"

# Input disk
echo "Please input the disk you are installing the system onto: (e.g. /dev/sda or /dev/nvme0n1p1)"
read DISK

if [[ ! -b "${DISK}" ]]; then
    echo "Error: Disk ${DISK} not found"
    exit 1
fi

# Input partitions
echo "Please input EFI partition: (e.g. /dev/sda1 or /dev/nvme0n1p1)"
read EFI

echo "Please input SWAP partition: (e.g. /dev/sda2)"
read SWAP

echo "Please enter ROOT partition: (e.g. /dev/sda3)"
read ROOT

if [[ ! -b "${EFI}" ]] || [[ ! -b "${SWAP}" ]] || [[ ! -b "${ROOT}" ]]; then
    echo "Error: One or more partitions not found"
    exit 1
fi

# make filesystems
echo "Making filesystems: EFI and SWAP"
mkfs.fat -F32 "${EFI}"
mkswap "${SWAP}"
swapon "${SWAP}"
echo -ne "EFI and SWAP initialized\n"

# Encryption
echo "Enter passphrase for encryption:"
cryptsetup luksFormat --batch-mode "${ROOT}"

CRYPT_NAME="cryptroot"

echo "The default name for the encrypted ROOT partition is 'cryptroot', do you want to change it? (Y/N)"
read flag

if [[ "${flag}" == "Y" || "${flag}" == "y" ]]; then
	echo "Enter new name for the encrypted partition:"
	read -r CRYPT_NAME
fi

cryptsetup open "${ROOT}" "${CRYPT_NAME}"

# make filesystems
mkfs.ext4 /dev/mapper/"${CRYPT_NAME}"

# mount
mount /dev/mapper/"${CRYPT_NAME}" /mnt
mkdir /mnt/boot
mount "${EFI}" /mnt/boot

# Pacman parallel downloads configuration
echo "Would you like to enable parallel downloads in pacman.conf? (Y/N)"
read -r parallel_flag

if [[ "${parallel_flag}" == "Y" || "${parallel_flag}" == "y" ]]; then
	echo "Enter number of parallel downloads number (Suggested to match the number of threads you have in your CPU):"
	read -r num_parallel
	sed -i "s/#ParallelDownloads = 5/ParallelDownloads = ${num_parallel}/" /etc/pacman.conf
fi

# Installation
pacstrap /mnt base base-devel nano vim neovim networkmanager lvm2 cryptsetup grub efibootmgr linux linux-firmware
genfstab -U /mnt > /mnt/etc/fstab

# Execute chroot script
arch-chroot /mnt /chroot-setup.sh
