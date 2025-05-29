#!/bin/bash
echo "Available regions:"
ls /usr/share/zoneinfo/
echo "Enter your region:"
read -r region

# For small regions
if [[ -f "/usr/share/zoneinfo/${region}" ]]; then
	ln -sf /usr/share/zoneinfo/${region}
	hwclock --systohc
	echo "Current time for selected timezone is"
	date

# For big regions with cities
elif [[ -d "/usr/share/zoneinfo/${region}" ]]; then
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
sed -i 's/^HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Grub bootloader
grub-install --efi-directory=/boot "${DISK}"
CRYPT_UUID=$(blkid -o value -s UUID ${ROOT})
ROOT_UUID=$(blkid -o value -s UUID /dev/mapper/cryptroot)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=${CRYPT_UUID}:${CRYPT_NAME} root=UUID=${ROOT_UUID}\"|" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Systemctl
systemctl enable NetworkManager

echo "Installation complete! You can now reboot."
exit
