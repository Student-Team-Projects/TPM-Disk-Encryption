# Disc encryption via TPM 1.2 and LUKS

## Introduction

Encrypted LUKS containers provide safe way of securing data on hard drive. The whole system is agreed to be impenetrable using straight-up brute force attack. However, to be used, container has be decrypted after every boot. Typical means of decrypting consist of providing a password, however, human created passphases tend to be word-based to be easier to remember, which renders them vulnerable to dictionary attacks. Alternative is to create complex password and store it in some removable memory, like pendrive, and provide it this way on every boot, which in turn is inconvenient.

The aim of this repo is to get encrypted with complex password LUKS container and being able to decrypt it in a safe way without need to provide password manually. It is achieved by the use of TPM (Trusted Platform Module) to store the key to the container. During the boot and decryption process TPM will release the key only if the boot process wasn't compromised. This way, when login screen is loaded we can expect that system hadn't been tampered with. From the perspective of attackers, they should not be able to brute-force dictionary attack system because of software timeout and should not be able to directly decrypt the hard drive because of the complex key. Similarly, after try to overwrite the bootloader, the TPM will not release the key, because the boot process didn't match the expected one. More about the whole process can be found in Details section.

## Installation

You need to make sure that you have cleared and ready-to-take-ownership-of TPM 1.2 module on your machine (this should be archievable is BIOS settings provided appropriate hardware). The scripts available in this repo assume freshly installed ArchLinux distribution - they wipe out whole hard drive and create they own partitions. In case of more specific needs, parts of the scripts can be modyfied to match situation, e.g. when you have already set up LUKS container and want only to store the key to it in the TPM.

To start installation, copy this repo on your machine (e.g. by mounting pendrive with this repo), connect to the internet, run the scripts named `install*.sh` in the order and follow instructions - some parts are not fully automated, like connecting to the internet or making sure that TPM is in appropriate state.

### Pre-installation

#### Get Arch Linux ISO

Download the iso from an [official Archlinux page](https://archlinux.org/download/) and flash it on a media of your choice. Then boot from it.

### Quick guide

#### Boot from arch iso

#### Connect to the internet

Plug in your Ethernet and go, or for wireless follow the commands.
List network interfaces to get available one e.g `wlan0`
```
iwctl device list
```
Scan for available networks and list them
```
iwctl station <interface> scan
iwctl station <interface> get-networks
```
Connect to the choosen one
```
iwctl station <interface> connect <ssid> --passphrase <passphrase>
```

#### Running scripts

```
./install1.sh
```
You will be asked to confirm disk erasure and prompted to enter new password to encrypted disk three times. It will later serve as boot password (it may be permanent one, however, better option could be to use simple one for the time of this installation and later supply better password for the container, simply to avoid typing safe passphase - obviously then weak password should be removed afterwards).

You will be asked to set root password and later to input encryption passphrase.

#### After rebooting

You will be asked to enter LUKS passphrase and login using root password. The scripts will be present in /root/scripts. Enter this directory.

#### Set up DHCP

```
./install2.sh
```

#### Connect to the internet as in "Connect to the internet"

#### Setup TPM disk encryption

```
./install3.sh
```
You will be asked to enter username and password for user building AUR packages. Later you will be asked to set TPM password and enter it a few times.

Now you have to reboot system and after it run

```
tpm_storesecret
```

In the following reboots you will not need to enter LUKS passphare. You should change it to more complex one with

```
cryptsetup luksChangeKey /dev/sda4

```

#### Unplug your arch-iso stick

#### Set UEFI supervisor (administrator) password
You must also set your UEFI firmware supervisor (administrator) password in the Security settings, so nobody can simply boot into UEFI setup utility and clear TPM.
You should never use the same UEFI firmware supervisor password as your encryption password, because on some old laptops, the supervisor password could be recovered as plaintext from the EEPROM chip.

## Details

Any command executed during boot process, BIOS configuration, code of the kernel and bootloader and various other factors contribute to final value of PCRs (Platform Configuration Registers) - more information can be found [here](https://ebrary.net/24779/computer_science/platform_configuration_registers). Realistically there is no feasible way of achieving same set of values of these registers if boot process was somehow altered.

TPM provides the mechanism for storing data in its NVRAM, and (if asked to) sealing it with set of current values of PCRs. After sealing, TPM will release its data only if current PCRs set matches the set at the moment of sealing.

This repo uses this mechanism to savely store key to LUKS container (BitLocker for Windows is based on very similar technique). At `etc/initcpio` there are hooks which run after boot process and try do retrieve the key from TPM to use it for decryption of LUKS partition. The boot process looks more or less like:

1. System start-up
2. GRUB bootloader
3. Various systems start up, like our tpm hook
    1. Hook runs and retrieves passphase from TPM
    2. If successful, key is stored in temporary file
4. LUKS container is decrypted using mentioned file
5. Login screen 

If process of retrieval fails, then user is prompted to input password to LUKS manually (it is a failsafe mechanism in case when we did not update values key is sealed with, after applying changes to some part of the boot process e.g. bootloader or kernel update). If we did not changed something personally it may indicate that the system is in some way compromised.

## Kernel update

After any intended changes to kernel or bootloader run `tpm_storesecret --no-seal` to allow TPM to release LUKS key without checking the PCRs (as they are going to be different at next boot). After reboot, run `tpm_storesecret` to seal the key to new boot sequence (there is need to do this, because system has to determine values of PCRs after changes before being able to seal with them). It can be improved to one reboot e.g. if we seal with new values of PCRs just after retrieving the key.

## Datailed guide

### Connect to the internet

Plug in your Ethernet and go, or for wireless follow the commands.
List network interfaces to get available one e.g `wlan0`
```
iwctl device list
```
Scan for available networks and list them
```
iwctl station <interface> scan
iwctl station <interface> get-networks
```
Connect to the choosen one
```
iwctl station <interface> connect <ssid> --passphrase <passphrase>
```

### Preparing the disk
#### Create EFI System, Linux LUKS and Linux boot partitions 
##### Create a 2MiB BIOS boot partition at start just in case it is ever needed in the future

```gdisk /dev/sda```
```
o
n
[Enter]
0
+2M
ef02
n
[Enter]
[Enter]
+550M
ef00
n
[Enter]
[Enter]
+550M
8300
n
[Enter]
[Enter]
[Enter]
8309
w
```

Partition table in ```gdisk -l``` should look simalarly to the one below:

Device    | Start   | End        | Sectors    | Size   | Name    |  
----------|---------|------------|------------|--------|---------|
/dev/sda1 |    2048 |       6143 |       4096 |     2M | BIOS boot          
/dev/sda2 |    6144 |    1054719 |    1048576 |   550M | EFI System                    
/dev/sda3 | 1054720 |    2103295 |    1048576 |   550M | Linux filesystem  
/dev/sda4 | 2103296 | 1953525134 | 1951421839 | ~464.7G | Linux LUKS 

#### Create the LUKS1 encrypted container on the Linux LUKS partition

```
cryptsetup luksFormat --type luks1 --use-random -S 1 -s 512 -h sha512 -i 5000 /dev/sda4
```

#### Open the container (decrypt it and make available at /dev/mapper/cryptlvm)

```
cryptsetup open /dev/sda4 cryptlvm
```

### Preparing the logical volumes

#### Create physical volume on top of the opened LUKS container

```
pvcreate /dev/mapper/cryptlvm
```

#### Create the volume group and add physical volume to it

```
vgcreate vg /dev/mapper/cryptlvm
```

#### Create logical volumes on the volume group for swap, root, and home

```
lvcreate -L 8G vg -n swap
lvcreate -L 32G vg -n root
lvcreate -l 100%FREE vg -n home
```

The size of the swap and root partitions are a matter of personal preference.

#### Format filesystems on each logical volume

```
mkfs.ext4 /dev/vg/root
mkfs.ext4 /dev/vg/home
mkswap /dev/vg/swap
```

#### Mount filesystems

```
mount /dev/vg/root /mnt
mkdir /mnt/home
mount /dev/vg/home /mnt/home
swapon /dev/vg/swap
```

### Preparing the EFI partition

#### Create FAT32 filesystem on the EFI system partition

```
mkfs.fat -F32 /dev/sda2
```

#### Create mountpoint for EFI system partition at /efi for compatibility with and mount it

```
mkdir /mnt/efi
mount /dev/sda2 /mnt/efi
```

### Preparing the boot partition

#### Create ext4 filesystem on the boot partition

```
mkfs.ext4 /dev/sda3
```

#### Create mountpoint for boot partition at /boot and mount it

```
mkdir /mnt/boot
mount /dev/sda3 /mnt/boot
```

### Install necessary packages

```
pacstrap /mnt base linux linux-firmware mkinitcpio lvm2 vi dhcpcd wpa_supplicant vim iwd ntfs-3g
```

### Generate an fstab file

```
genfstab -U /mnt >> /mnt/etc/fstab
```

### Enter new system chroot

```
arch-chroot /mnt
```

#### At this point you should have the following partitions and logical volumes:

```lsblk```

NAME           | MAJ:MIN | RM  |  SIZE  | RO  | TYPE  | MOUNTPOINT |
---------------|---------|-----|--------|-----|-------|------------|
sda            |  259:0  |  0  | 465.8G |  0  | disk  |            |
├─sda1         |  259:4  |  0  |     2M |  0  | part  |            |
├─sda2         |  259:5  |  0  |   550M |  0  | part  | /efi       |
├─sda3         |  259:5  |  0  |   550M |  0  | part  | /boot      |
├─sda4         |  259:6  |  0  | 465.2G |  0  | part  |            |
..└─cryptlvm   |  254:0  |  0  | 465.2G |  0  | crypt |            |
....├─vg-swap  |  254:1  |  0  |     8G |  0  | lvm   | [SWAP]     |
....├─vg-root  |  254:2  |  0  |    32G |  0  | lvm   | /          |
....└─vg-home  |  254:3  |  0  | 425.2G |  0  | lvm   | /home      |

### Time zone

#### Set the time zone

Replace `Europe/Warsaw` with your respective timezone found in `/usr/share/zoneinfo`
```
ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime
```

#### Run `hwclock` to generate ```/etc/adjtime```

Assumes hardware clock is set to UTC
```
hwclock --systohc
```

### Localization

#### Uncomment ```en_US.UTF-8 UTF-8``` in ```/etc/locale.gen``` and generate locale

```
sed -i '/#en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
```

#### Create ```locale.conf``` and set the ```LANG``` variable

```
touch /etc/locale.conf
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
```

#### Create ```vconsole.conf``` and set the ```KEYMAP``` variable

```
touch /etc/vconsole.conf
echo "KEYMAP=us" >> /etc/vconsole.conf
```

### Network configuration

#### Create the hostname file
```
touch /etc/hostname
echo "myhostname" >> /etc/hostname
```

#### Add matching entries to hosts

```
touch /etc/hosts
echo -e "127.0.0.1 localhost\n::1 localhost\n127.0.1.1 myhostname.localdomain myhostname" >> /etc/hosts
```

### Initramfs

#### Add the ```systemd```, ```kms```, ```keyboard```, ```sd-vconsole```, ```tpm```, ```sd-encrypt```, and ```lvm2``` hooks to ```/etc/mkinitcpio.conf```

*Note:* ordering matters.
```
sed -i "s|^HOOKS=.*|HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block tpm sd-encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
```

#### Recreate the initramfs image

```
mkinitcpio -p linux
```

### Root password

#### Set the root password
```
passwd
```

### Boot loader

#### Install GRUB

```
pacman -S grub
```

#### Configure GRUB to allow booting from /boot on a LUKS1 encrypted partition

```
echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub
```

#### Set kernel parameter to unlock the LVM physical volume at boot using ```encrypt``` hook

##### UUID is the partition containing the LUKS container

```
export BLKID=$(blkid | grep sda4 | cut -d '"' -f 2)
export GRUBCMD="\"rd.luks.name=$BLKID=cryptlvm root=/dev/vg/root\""
echo GRUB_CMDLINE_LINUX=${GRUBCMD} >> /etc/default/grub
```

#### Install GRUB to the mounted ESP for UEFI booting

```
pacman -S efibootmgr
grub-install --target=x86_64-efi --efi-directory=/efi --modules="tpm" --disable-shim-lock
```

#### Enable microcode updates

##### grub-mkconfig will automatically detect microcode updates and configure appropriately

```
pacman -S intel-ucode
```

Use intel-ucode for Intel CPUs and amd-ucode for AMD CPUs.

#### Generate GRUB's configuration file

```
grub-mkconfig -o /boot/grub/grub.cfg
```

### Restrict ```/boot``` permissions
```
chmod 700 /boot
```

The installation is now complete. Exit the chroot and reboot.
```
exit
reboot
```

You will be asked to enter LUKS passphrase.

### Post-installation

### Set up network and dhcp

```
echo "[General]\nEnableNetworkConfiguration=true" >> /etc/iwd/main.conf
systemctl enable --now iwd
systemctl enable --now dhcpcd
dhcpcd wlan0
```

#### Connect to the internet as in "Connect to the internet" in Quick guide

### Install base-devel and git packages

```
pacman -S base-devel
pacman -S git
```

### Create new user for building AUR packages and add him to wheel

```
useradd -m <user_name>
passwd <user_name>
usermod -aG wheel <user_name>
```

### Uncomment ```%wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL``` in ```/etc/sudoers```

```
sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g" /etc/sudoers
```

### Login as newly created user

#### Build and install ```trousers``` package from AUR

```
git clone https://aur.archlinux.org/trousers.git
cd trousers
makepkg -si
cd ..
```

#### Build and install ```opencryptoki``` package from AUR

```
git clone https://aur.archlinux.org/opencryptoki.git
cd opencryptoki
makepkg -si
cd ..
```

#### Build and install ```tpm-tools``` package from AUR

```
git clone https://aur.archlinux.org/tpm-tools.git
cd tpm-tools
makepkg -si
cd ..
```

### Login back as root

### Copy ```/etc/*``` contents of this repository to your system ```/etc``` folder

```
cp -r etc/* /etc/
```

### Configure TPM

If any error occurs during TPM configuration you might need to enable or clear it in BIOS.

#### Check if TPM is acitve and enabled

```
cat /sys/class/tpm/tpm0/active
cat /sys/class/tpm/tpm0/enable
```

Both commands should print 1.

#### Run tcsd

```
tcsd
```

#### Take ownership of TPM and set password

```
tpm_takeownership -z
```

### Add a new keyfile to LUKS

#### Create a new keyfile and change it's permissions

```
dd bs=1 count=256 if=/dev/urandom of=/etc/tpm-secret/secret_key.bin
chmod 0700 /etc/tpm-secret/secret_key.bin
```

#### Add the keyfile to the LUKS partition

```
cryptsetup luksAddKey /dev/sda4 /etc/tpm-secret/secret_key.bin
```

### Make TPM scripts executable

```
chmod +x /etc/tpm-secret/tpm_storesecret.sh
chmod +x /etc/tpm-secret/tpm_getsecret.sh
```

### Update modules and hooks in ```/etc/mkinitcpio.conf```

```
sed -i "s|^MODULES=.*|MODULES=(quota_v2 quota_tree tpm tpm_tis)|g" /etc/mkinitcpio.conf
sed -i "s|^HOOKS=.*|HOOKS=(base systemd autodetect modconf kms keyboard sd-vconsole block tpm sd-encrypt lvm2 filesystems fsck)|g" /etc/mkinitcpio.conf
```

### Add LUKS partition UUID and path to keyfile to ```/etc/crypttab.initramfs```

```
BLKID=$(blkid | grep sda4 | cut -d '"' -f 2)
echo "cryptlvm1      UUID=${BLKID}    /secret_key.bin" > /etc/crypttab.initramfs
```

### Create a backup of the initramfs image

```
cp /boot/initramfs-linux-lts.img /boot/initramfs-linux-lts.img.orig
```

### Recreate the initramfs image

```
mkinitcpio -P
```

### Store the keyfile in TPM without sealing it with PCRs

```
/etc/tpm-secret/tpm_storesecret.sh --no-seal
```
### Create a softlink for convenient update process

```
ln -s /etc/tpm-secret/tpm_storesecret.sh /bin/tpm_storesecret
```

### Reboot

If everything works you shouldn't be asked to enter LUKS password after reboot.

In case something went wrong within this process, or if there was a kernel update and your system won't read the contents of the NVRAM because the kernel-checksum has changed and systemd does not even ask for the LUKS passphrase on console: then press E in the GRUB boot menu, append an ".orig" on the line were the initrd is specified. Now press F10 to boot. This allows you to boot the “normal” way, by providing a LUKS passphrase.

### Store the keyfile with sealing

After the reboot the PCR values are updated according to the new initramfs image. Now we can use them to seal the keyfile.

```
tpm_storesecret.sh
```

## References

- https://gist.github.com/huntrar/e42aee630bee3295b2c671d098c81268
- https://github.com/archont00/arch-linux-luks-tpm-boot
- https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system
- https://wiki.archlinux.org/title/systemd
- https://wiki.archlinux.org/title/Trusted_Platform_Module