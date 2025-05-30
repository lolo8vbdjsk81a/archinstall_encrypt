#!/bin/bash
echo -ne "\n\e[32mEntered chroot environment, running second stage setup...\e[0m\n"
echo -ne "\e[36m
  ____ _                     _     ____       _               
 / ___| |__  _ __ ___   ___ | |_  / ___|  ___| |_ _   _ _ __  
| |   | '_ \| '__/ _ \ / _ \| __| \___ \ / _ \ __| | | | '_ \ 
| |___| | | | | | (_) | (_) | |_   ___) |  __/ |_| |_| | |_) |
 \____|_| |_|_|  \___/ \___/ \__| |____/ \___|\__|\__,_| .__/ 
                                                       |_|    
\e[0m"

echo "-------------------";
echo "Verifying variables:";
echo -e "\e[36mDISK\e[0m = ${DISK}";
echo -e "\e[36mROOT\e[0m = ${ROOT}";
echo -e "\e[36mCRYPT_NAME\e[0m = ${CRYPT_NAME}";
echo "-------------------";
echo "Available regions:"
ls /usr/share/zoneinfo/
echo "\e[33mEnter your region:\e[0m"
read -r region

# For small regions
if [[ -f "/usr/share/zoneinfo/${region}" ]]; then
	ln -sf /usr/share/zoneinfo/${region} /etc/localtime
	hwclock --systohc
	echo "Current time for selected timezone is"
	date

# For big regions with cities
elif [[ -d "/usr/share/zoneinfo/${region}" ]]; then
	echo "Available cities in ${region}:"
	ls "/usr/share/zoneinfo/${region}"
	echo "\e[33mEnter city name:\e[0m"
	read -r city
	# Set timezone if city file exists
	if [[ -f "/usr/share/zoneinfo/${region}/${city}" ]]; then
		ln -sf /usr/share/zoneinfo/${region}/${city} /etc/localtime
		hwclock --systohc
		echo "Current time for selected timezone is"
		date
	fi
fi

echo -e "\e[33mWould you like to edit locale.gen manually? Default is 'en_US.UTF-8' (Y/N)\e[0m"
read -r edit_locale

if [[ "${edit_locale}" == "Y" || "${edit_locale}" == "y" ]]; then
	vim /e\e[0m\e[0m\e[0mtc/locale.gen
else
	sed -i 's/#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
fi

locale-gen
locale | grep ^LANG= > /etc/locale.conf

# Systemwide
echo -e "\n\e[36mSystemwide configuration\e[0m"
echo -e "\e[33mPlease enter your Hostname\e[0m"
read -r HOST
echo ${HOST} > /etc/hostname

echo -e "\e[33mPlease enter your ROOT Password\e[0m"
passwd

# Uncomment wheel group
sed -i 's/^#\s*\(%wheel\s\+ALL=(ALL:ALL)\s\+ALL\)/\1/' /etc/sudoers

# User
echo -e "\n\e[36mUser configuration\e[0m"
echo -e "\e[33mPlease enter your Username\e[0m"
read -r USER
useradd -m -G wheel -s /bin/bash "${USER}"
passwd ${USER}

# Edit /etc/mkinitcpio.conf
sed -i 's/^HOOKS=.*$/HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt lvm2 filesystems fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Grub bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB "${DISK}"
CRYPT_UUID=$(blkid -o value -s UUID ${ROOT})
ROOT_UUID=$(blkid -o value -s UUID /dev/mapper/cryptroot)
sed -i "s|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=${CRYPT_UUID}:${CRYPT_NAME} root=UUID=${ROOT_UUID}\"|" /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Systemctl
systemctl enable NetworkManager

echo -e "\n\e[32mInstallation complete! Do you want to unmount everything and reboot now? (Y/N) \e[0m"
read -r reboot_now

if [[ "${reboot_now}" == "Y" || "${reboot_now}" == "y" ]]; then
	exit
	umount -R /mnt
	swapoff -a
	reboot
fi
