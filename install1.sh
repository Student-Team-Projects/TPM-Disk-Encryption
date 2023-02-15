echo "Make sure you are connected to the internet"
echo "Creating partitions"
sgdisk --zap-all /dev/sda
sgdisk -n 1:0:+2MiB /dev/sda
sgdisk -n 2:0:+550MiB /dev/sda
sgdisk -n 3:0:+550MiB /dev/sda
sgdisk -n 4:0:0 /dev/sda

echo "Creating LUKS container on /dev/sda4"
cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 /dev/sda4

echo "Opening the container"
cryptsetup open /dev/sda4 cryptlvm
echo "Preparing the logical volumes"
echo "Creating physical volume on top of the opened LUKS container"
pvcreate /dev/mapper/cryptlvm
echo "Creating the volume group and adding physical volume to it"
vgcreate vg /dev/mapper/cryptlvm

echo "Creating logical volumes on the volume group for swap, root and home"
lvcreate -L 8G vg -n swap
lvcreate -L 32G vg -n root
lvcreate -l 100%FREE vg -n home

echo "Formatting filesystems on each logical volume"
mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home
mkswap /dev/vg/swap

echo "Mounting filesystems"
mount /dev/vg/root /mnt
mkdir /mnt/home
mount /dev/vg/home /mnt/home
swapon /dev/vg/swap

echo "Preparing the EFI system partition"
echo "Creating FAT32 filesystem on the EFI system partition"
mkfs.fat -F32 /dev/sda2
echo "Creating mountpoint for EFI system partition at /efi"
mkdir /mnt/efi
mount /dev/sda2 /mnt/efi

echo "Preparing the Linux boot partition"
echo "Creating ext4 filesystem on the Linux boot partition"
mkfs.ext4 /dev/sda3
echo "Creating mountpoint for Linux boot partition at /boot"
mkdir /mnt/boot
mount /dev/sda3 /mnt/boot

echo "installing packages with pacstrap"
pacstrap /mnt base linux linux-firmware mkinitcpio lvm2 vi dhcpcd wpa_supplicant vim iwd ntfs-3g

echo "generating an fstab file"
genfstab -U /mnt >> /mnt/etc/fstab

echo "copying scripts to new root"
mkdir /mnt/root/scripts
cp -r * /mnt/root/scripts

echo "Entering new system chroot"
arch-chroot /mnt /root/support_scripts/after_chroot.sh

echo "Reboot"
reboot