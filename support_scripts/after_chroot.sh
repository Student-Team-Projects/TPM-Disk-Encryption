echo "Setting the time zone"
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
echo "Synchronizing system and hardware clock"
hwclock --systohc

echo "Localization configuration"
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "Keyboard layout configuration"
echo "KEYMAP=us" >> /etc/vconsole.conf

echo "Network configuration"
echo "Creating hostname file"
echo "myhostname" >> /etc/hostname
echo "Adding matching entries to the hosts"
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts
echo "Setting the hooks"
sed -i "s|^HOOKS=.*|HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block tpm sd-encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
echo "Running mkinitcpio"
mkinitcpio -p linux

echo "Setup password for root"
passwd
echo "Installing grub"
pacman -S grub
echo "Adding keys to GRUB configuration"
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
export BLKID=$(blkid | grep sda4 | cut -d '"' -f 2)
export GRUBCMD="\"rd.luks.name=$BLKID=cryptlvm root=/dev/vg/root\""
echo GRUB_CMDLINE_LINUX=${GRUBCMD} >> /etc/default/grub

echo "Installing efibootmanager"
pacman -S efibootmgr
echo "Installing Boot to the mounted ESP for UEFI booting"
grub-install --target=x86_64-efi --efi-directory=/efi --modules="tpm" --disable-shim-lock
echo "Installing intel-ucode"
pacman -S intel-ucode
echo "Generating GRUB configuration file"
grub-mkconfig -o /boot/grub/grub.cfg

chmod 700 /boot