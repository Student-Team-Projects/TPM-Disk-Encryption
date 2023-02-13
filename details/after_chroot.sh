ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
hwclock --systohc
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "KEYMAP=us" >> /etc/vconsole.conf
echo "myhostname" >> /etc/hostname
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts
sed -i "s|^HOOKS=.*|HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block tpm sd-encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
mkinitcpio -p linux

echo "Setup password for root"
passwd
pacman -S grub
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
export BLKID=$(blkid | grep sda4 | cut -d '"' -f 2)
export GRUBCMD="\"rd.luks.name=$BLKID=cryptlvm root=/dev/vg/root\""
echo GRUB_CMDLINE_LINUX=${GRUBCMD} >> /etc/default/grub

pacman -S efibootmgr
grub-install --target=x86_64-efi --efi-directory=/efi --modules="tpm" --disable-shim-lock
pacman -S intel-ucode
grub-mkconfig -o /boot/grub/grub.cfg

chmod 700 /boot
reboot