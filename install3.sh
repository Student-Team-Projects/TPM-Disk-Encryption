echo "Make sure you are connected to the internet"
echo "" > /root/tpm.log
if [[ $(cat /root/tpm.log) != "DONE" ]]
then
	echo "Installing base-devel and git packages"
	pacman -S base-devel
	pacman -S git
	echo "Creating user for AUR packages"
	echo "Enter name and password for user which installs packages"
	read -p "Username: " user_name
	useradd -m ${user_name}
	passwd ${user_name}
	sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g" /etc/sudoers
	usermod -aG wheel ${user_name}

	chmod 777 support_scripts/makepkgs.sh
	echo "Running makepkgs.sh script as the new user"
	su -c ./support_scripts/makepkgs.sh ${user_name}

	echo "Copying etc directory from repository"
	cp -r etc/* /etc/
	echo "DONE" > /root/tpm.log
fi

if [[ $(cat /sys/class/tpm/tpm0/active) != "1" ]]
then
	echo "Activate TPM then restart this script"
	exit 1
fi

if [[ $(cat /sys/class/tpm/tpm0/enable) != "1" ]]
then
	echo "Enable TPM then restart this script"
	exit 1
fi

echo "Running tcsd"
tcsd
if [[ $? -ne 0 ]]
then
	echo "Check if installation of packages was succesful then restart this script"
	exit 1
fi
echo "Setup password for TPM"
tpm_takeownership -z

echo "Creating a new keyfile"
dd bs=1 count=256 if=/dev/urandom of=/etc/tpm-secret/secret_key.bin
chmod 0700 /etc/tpm-secret/secret_key.bin
echo "Adding the keyfile to LUKS partition"
cryptsetup luksAddKey /dev/sda4 /etc/tpm-secret/secret_key.bin
chmod +x /etc/tpm-secret/tpm_storesecret.sh
chmod +x /etc/tpm-secret/tpm_getsecret.sh

echo "Updating modules in mkinitcpio"
sed -i "s|^MODULES=.*|MODULES=(quota_v2 quota_tree tpm tpm_tis)|g" /etc/mkinitcpio.conf
echo "Updating hooks in mkinitcpio"
sed -i "s|^HOOKS=.*|HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block tpm sd-encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf

echo "Adding LUKS partition UUID and path to keyfile to /etc/crypttab.initramfs"
BLKID=$(blkid | grep sda4 | cut -d '"' -f 2)
echo "cryptlvm1      UUID=${BLKID}    /secret_key.bin" > /etc/crypttab.initramfs

# backup, if something goes wrong
echo "Creating a backup of the initramfs image"
cp /boot/initramfs-linux-lts.img /boot/initramfs-linux-lts.img.orig
echo "Running mkinitcpio"
mkinitcpio -P

# next boot sequence will differ from last one, so --no-seal option saves us from
# entering password to LUKS manually. After reboot, new boot sequence will be in PCRs,
# then we can seal using them for next time
echo "Store the keyfile in TPM without sealing"
/etc/tpm-secret/tpm_storesecret.sh --no-seal
rm /root/tpm.log

# softlink, for convenient update process
ln -s /etc/tpm-secret/tpm_storesecret.sh /bin/tpm_storesecret

echo "Reboot the system and run tpm_storesecret to seal the key to new boot sequence."