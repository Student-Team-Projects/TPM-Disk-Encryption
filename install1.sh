echo Creating partitions
sgdisk --zap-all /dev/sda
sgdisk -n 1:0:+2MiB /dev/sda
sgdisk -n 2:0:+550MiB /dev/sda
sgdisk -n 3:0:+550MiB /dev/sda
sgdisk -n 4:0:0 /dev/sda

echo "Creating LUKS container on /dev/sda4"
cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 /dev/sda4

cryptsetup open /dev/sda4 cryptlvm
pvcreate /dev/mapper/cryptlvm
vgcreate vg /dev/mapper/cryptlvm

lvcreate -L 8G vg -n swap
lvcreate -L 32G vg -n root
lvcreate -l 100%FREE vg -n home

mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home
mkswap /dev/vg/swap

mount /dev/vg/root /mnt
mkdir /mnt/home
mount /dev/vg/home /mnt/home
swapon /dev/vg/swap

mkfs.fat -F32 /dev/sda2
mkdir /mnt/efi
mount /dev/sda2 /mnt/efi

mkfs.ext4 /dev/sda3
mkdir /mnt/boot
mount /dev/sda3 /mnt/boot

pacstrap /mnt base linux linux-firmware mkinitcpio lvm2 vi dhcpcd wpa_supplicant vim iwd ntfs-3g

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot ./details/after_chroot.sh /mnt