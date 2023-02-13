echo "" > /root/tpm.log
if [[ $(cat /root/tpm.log) != "DONE" ]]
then
	pacman -S base-devel
	pacman -S git
	echo "Enter name and password for user which installs packages"
	read -p "Username: " user_name
	useradd -m ${user_name}
	passwd ${user_name}
	sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g" /etc/sudoers
	usermod -aG wheel ${user_name}

	chmod 777 details/makepkgs.sh
	su -c ./details/makepkgs.sh ${user_name}

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

tcsd
if [[ $? -ne 0 ]]
then
	echo "Check if installation of packages was succesful then restart this script"
	exit 1
fi
echo "Setup password for TPM"
tpm_takeownership -z

dd bs=1 count=256 if=/dev/urandom of=/etc/tpm-secret/secret_key.bin
chmod 0700 /etc/tpm-secret/secret_key.bin
cryptsetup luksAddKey /dev/sda4 /etc/tpm-secret/secret_key.bin
chmod +x /etc/tpm-secret/tpm_storesecret.sh
chmod +x /etc/tpm-secret/tpm_getsecret.sh

sed -i "s|^MODULES=.*|MODULES=(quota_v2 quota_tree tpm tpm_tis)|g" /etc/mkinitcpio.conf
sed -i "s|^HOOKS=.*|HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block tpm sd-encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf

BLKID=$(blkid | grep sda4 | cut -d '"' -f 2)
echo "cryptlvm1      UUID=${BLKID}    /secret_key.bin" > /etc/crypttab.initramfs

# backup, if something goes wrong
cp /boot/initramfs-linux-lts.img /boot/initramfs-linux-lts.img.orig
mkinitcpio -P

# next boot sequence will differ from last one, so --no-seal option saves us from
# entering password to LUKS manually. After reboot, new boot sequence will be in PCRs,
# then we can seal using them for next time
/etc/tpm-secret/tpm_storesecret.sh --no-seal
rm /root/tpm.log

# softlink, for convenient update process
ln -s /etc/tpm-secret/tpm_storesecret.sh /bin/tpm_storesecret

echo Reboot the system and run tpm_storesecret to seal the key to new boot sequence.