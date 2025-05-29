#!/bin/bash
# This script installs an arch linux system with full disk encryption.

echo "\nPlease make sure you have internet connection with configured disk when running this script.\n"

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
echo "EFI and SWAP initialized\n"

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

export DISK="${DISK}"
export ROOT="${ROOT}"
export CRYPT_NAME="${CRYPT_NAME}"

cat > /mnt/chroot-setup.sh << EOF

#!/bin/bash
echo "Available regions:"
ls /usr/share/zoneinfo/
echo "Enter your region:"
read -r region

# Show cities for selected region if the directory exists
if [[ -d "/usr/share/zoneinfo/${region}" ]]; then
	echo "Available cities in ${region}:"
	ls "/usr/share/zoneinfo/${region}"
	echo "Enter city name:"
	read -r city
	# Set timezone if city file exists
	if [[ -f "/usr/share/zoneinfo/${region}/${city}" ]]; then
		ln -sf /usr/share/zoneinfo/${region}/${city}
		hwclock --systohc
		echo "Current time for selected timezone is"
		date
	fi
fi

echo "Would you like to edit locale.gen and locale.conf manually? Default is en_US.UTF-8 (Y/N)"
read -r edit_locale

if [[ "${edit_locale}" == "Y" || "${edit_locale}" == "y" ]]; then
	vim /etc/locale.gen
else
	sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
fi

locale-gen

if [[ "${edit_locale}" == "Y" || "${edit_locale}" == "y" ]]; then
	vim /etc/locale.conf
else
	echo "LANG=en_US.UTF-8" > /etc/locale.conf
fi

# Systemwide
echo "Systemwide configuration"
echo "Please enter your Hostname"
read -r HOST
echo ${HOST} > /etc/hostname

echo "Please enter your ROOT Password"
passwd

# Uncomment wheel group
sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL:ALL)\s\+ALL\)/\1/' /etc/sudoers

# User
echo "User configuration"
echo "Please enter your Username"
read -r USER
useradd -m -G wheel -s /bin/bash "${USER}"
passwd ${USER}

# Edit /etc/mkinitcpio.conf
sed -i 's/^HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Grub bootloader
grub-install --efi-directory=/boot "${DISK}"
CRYPT_UUID=$(blkid -o value -s UUID /dev/${ROOT})
ROOT_UUID=$(blkid -o value -s UUID /dev/mapper/cryptroot)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=${CRYPT_UUID}:${CRYPT_NAME} root=UUID=${ROOT_UUID}\"|" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Systemctl
systemctl enable NetworkManager

echo "Installation complete! You can now reboot."
exit
EOF

# Make the chroot script executable
chmod +x /mnt/chroot-setup.sh

# Execute chroot script
arch-chroot /mnt /chroot-setup.sh
