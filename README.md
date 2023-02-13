# Disc encryption via TPM 1.2 and LUKS

## Introduction

Encrypted LUKS containers provide safe way of securing data on hard drive. The whole system is agreed to be impenetrable using straight-up brute force attack. However, to be used, container has be decrypted after every boot. Typical means of decrypting consist of providing a password, however, human created passphases tend to be word-based to be easier to remember, which renders them vulnerable to dictionary attacks. Alternative is to create complex password and store it in some removable memory, like pendrive, and provide it this way on every boot, which in turn is inconvenient.

The aim of this repo is to get encrypted with complex password LUKS container and being able to decrypt it in a safe way without need to provide password manually. It is achieved by the use of TPM (Trusted Platform Module) to store the key to the container. During the boot and decryption process TPM will release the key only if the boot process wasn't compromised. This way, when login screen is loaded we can expect that system hadn't been tampered with. From the perspective of attackers, they should not be able to brute-force dictionary attack system because of software timeout and should not be able to directly decrypt the hard drive because of the complex key. Similarly, after try to overwrite the bootloader, the TPM will not release the key, because the boot process didn't match the expected one. More about the whole process can be found in Details section.

## Installation

You need to make sure that you have cleared and ready-to-take-ownership-of TPM 1.2 module on your machine (this should be archievable is BIOS settings provided appropriate hardware). The scripts available in this repo assume freshly installed ArchLinux distribution - they wipe out whole hard drive and create they own partitions. In case of more specific needs, parts of the scripts can be modyfied to match situation, e.g. when you have already set up LUKS container and want only to store the key to it in the TPM.

To start installation, copy this repo on your machine (e.g. by mounting pendrive with this repo), connect to the internet, run the scripts named `install*.sh` in the order and follow instructions - some parts are not fully automated, like connecting to the internet or making sure that TPM is in appropriate state.

## Details

### Signing

### TPM

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

After any intended changes to kernel or bootloader run `tpm_storesecret --no-seal` to allow TPM to release LUKS key without checking the PCRs (as they are going to be different at next boot). After reboot, run `tpm_storesecret` to seal the key to new boot sequence (there is need to do this, because system has to determine values of PCRs after changes before being able to seal with them). It can be improved to one reboot e.g. if we seal with new values of PCRs just after retrieving the key (TODO?).

## Credits