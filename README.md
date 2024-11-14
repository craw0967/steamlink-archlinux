# SteamLink-ArchLinux #

## THIS README IS OUT OF DATE! ##
The information below is tailored for the original script in the 'boot_disk_creator.sh' file. While some of the details here are improved over the Main branch README, such as the kernel compiling instructions, these instructions only loosely align with the new script.

Post install instructions are still valid.

If you wish to try the new script, run the 'boot_disk_wizard.sh' script. THERE WILL BE BUGS.

This is a work in progress.  There is absolutely no warranty, implied or otherwise, and I am not responsible for data loss or other damage.  I've tried my best to at least have the major functionality working before I committed this branch, but some things do not and will not work as expected without more updates.

## Read Me ##

This repository hosts a modified version of the script found in this GitHub repository - https://github.com/regmibijay/steamlink-archlinux

From regmibijay's repository:
>Create ArchLinux boot medium for steamlink with one script!

According to regmibijay, the kernel can supposedly be updated inside ArchLinux once you flash it, however I have not determined an easy method of doing that without compiling a new kernel.

The script in this repository will install a newer Linux kernel (6.6.54 Long Term) than the GitHub repository linked above (which installs kernel 5.4.24). If you prefer, you can also compile a different Linux kernel yourself. I've included instructions below.

You can also manually perform the steps that the script automates. The script is relatively straightforward, as far as scripts go, but you can also find a basic outline of steps on Reddit here - https://www.reddit.com/r/Steam_Link/comments/fgew5x/running_archlinux_on_steam_link_revisited/

You can also find more details on how to compile the kernel for the Steam Link and how to install the necessary files here - https://heap.ovh/getting-linux-on-valve-steam-link.html and here - https://web.archive.org/web/20190925025431/http://www.livxtrm.com/steamlink/. 

The kernel used in this repository was compiled by myself. The author of the post at heap.ovh has two earlier kernel versions compiled if you prefer, including the kernel used in the repository this one is based off of. These instructions do not support how to get the appropriate files from heap.ovh, or how to install them.

ArchLinux was chosen primarily because that is what others had already paved the way with, but also because of the ease of procuring and installing the ArchLinux user space. Other Linux distros user spaces, or a custom user space, could be used in theory, however I found it difficult to find and install just the user space of say, Ubuntu for example. 

## Disclaimer ##
Everything in this repository is provided as is, without warranty. I provide no support and am not responsible for damages caused by the use of this software or by following the instructions provided. I am also not responsible for what you do with this software.

In theory, this method of booting into an OS other than the default system on a Steam Link poses significantly less risk to your device than attempting to install a new OS on the built in storage, as you can simply remove the USB drive to return normal Steam Link functionality.

Just because there's less risk to your hardware though, does not mean it is risk free. You should take great caution when running scripts and using software taken from an unknown source. You should also be careful about copying and pasting random commands from the internet to run on your computer.

I have provided relatively detailed instructions so that this process can be followed along with ease and without a lot of experience, but I still strongly encourage you to read through the provided installation script and review and understand the commands I'm asking you to run.

Additionally, the provided kernel was compiled by someone other than you. By using the kernel included in this repository, you are trusting a stranger on the internet that the kernel is safe to use. If you're willing to take my word for it, I did compile the kernel from source from kernel.org, without modification, and I validated the signature of the source tarball before doing so.

This README provides a lot of detail, but the instructions contained in it still require a basic understanding of Linux, command line interfaces, and other various technologies, such as SSH, Git, and networking.

The instructions below are not intended as a one size fits all configuration, so feel free to only take from it what you need. They do provide a good baseline starting point for any project however.

## Default Passwords ##
#### Default User ####
User: `alarm` Password: `alarm`

#### Root User ####
User: `root` Password: `root`

## Available Interfaces ##
Note: HDMI does not work. You will not be able to use a monitor or TV with this installation. Running a Steam Link in this fashion will only work as a headless server. It might be possible that newer and/or future Linux kernels could provide drivers to enable HDMI output, but don't count on it.

The following lists were provided by https://heap.ovh. I have only tested Ethernet, USB, and WLAN, so your mileage may vary with the rest of the items.

#### Stuff That Works ####
- Ethernet (Works out of the box)
- USB (Works out of the box)
- WLAN (mwifiex mwifiex_sdio) (Setup required - Instructions included below)
- Bluetooth (btmrl btmrvl_sdio) (Setup required - No instructions provided by me at this time)
- i2c (i2c-designware) (I'm not aware if setup is required, so just expect it)
- temp sensor (berlin2-adc) (I'm not aware if setup is required, so just expect it)
- UART (I'm not aware if setup is required, so just expect it)

#### Stuff That Does Not Work ####
- NAND driver
- DMA controller
- Video/Audio output
- Suspend/Resume/Halt

## Installation Steps ##
This script has only been tested on Linux. This may work with Windows Subsystems for Linux, however I haven't tested it.

Open a terminal and clone this repository. Install Git if needed. (Installation commands for common package managers - `sudo apt install git`, `sudo pacman -S git`, `sudo yum install git`) Keep in mind, it will clone to whichever directory you currently have open.
```
git clone https://github.com/craw0967/steamlink-archlinux.git
```

Plug in the USB drive you wish to install ArchLinux onto. If you are using a Virtual Machine, ensure the USB drive is correctly passed through to the VM.

Confirm the USB drive name and partition you wish to install the OS onto.

```
lsblk -o NAME,TRAN
```
*Which will produce something similar to:*
```
sda                    sata
├─sda1
└─sda2           
sdb                    usb
└─sdb1                 
sr0                    sata
```
*If you'd like, you can add other options to get additional information (i.e. SIZE). You can also get a nice clean output by using the -S flag*
```
$ lsblk -So NAME,SIZE,TRAN

NAME   SIZE  TRAN
sda    400G  sata
sdb    16G   usb
sr0    1024M sata
```
Once you have verified the USB drive and partition you'd like to use, *sdb1* in the example above, we can move forward. If the USB drive does not have any partitions, for example if it was to only show up as *sdb* when using the `lsblk -o NAME,TRAN` command, then you must partition the drive before proceeding. The Steam Link will not boot from the USB drive unless it has at least one partition.

To make a new partition table in the device:
```
sudo fdisk /dev/sdb
```
- Then press letter `o` to create a new empty DOS partition table.

Make a new partition:
- Press letter `n` to add a new partition. 
- You will be prompted for the size of the partition. Make a primary partition when prompted, if you are not sure.
- Then press letter `w` to write table to disk and exit.

At this point, you could format the new volume for DOS if you wish (it's a fast format operation), however the script will be formatting it to ext3 format later, so this isn't necessary.
```
sudo mkfs.vfat /dev/sdb1
```

You are now ready to run the included script and set up the USB drive.

Confirm the script is executable:
```
sudo chown +x boot_device_creator.sh
```

Execute and run the script:
```
sudo ./boot_device_creator.sh
```

Follow the prompts and enter in the drive you wish to format and install ArchLinux to. Be very careful at this point as the script will format whatever drive you select.
```
/dev/sdb1
```

Once the script has completed, the drive is ready to be installed in the Steam Link. The script should have ejected the USB drive, but if not, it can be ejected with the following command:
```
sudo eject /dev/sdb
```

Remove the USB drive and insert into any USB port on the Steam Link. Connect the Steam Link to your network via the ethernet port. Power on the device.

After a short period, the Steam Link should be fully booted and connected to your network. Depending on your network setup, you may be able to SSH into a shell using the default host name.  The default host name is `alarm`, so you may be able to connect to `alarm` and/or `alarm.local` using port `22`.

If you're unable to connect using the devices host name, you will need to determine which IP address was assigned to the device. You can usually do this by reviewing DHCP leases on your router. Once determined, SSH into the device using the IP address and port `22`.

By default, and as a good security practice, you cannot log into the device via SSH with the `root` account.

SSH into the device using your preferred method/application, such as PuTTY or a terminal session, using the `alarm` account's default username and password noted at the top of this document.
```
login as: alarm
alarm@alarm.local's password:
```

Once you are logged in to the `alarm` account, switch to the `root` account using the `su` command and the `root` account's default username and password noted at the top of this document.
```
su root
```

Set new password for the `root` account. Make sure it is secure and something that you will remember.
```
passwd
```

Set a new password for `alarm` account.  Make sure it is secure and something you will remember.
```
passwd alarm
```

(Optional) To prevent having some of the custom files overwritten by pacman on system updates you might want to uncomment and edit the *IgnorePkg* line in the *pacman.conf* file.
```
nano /etc/pacman.conf
```

Find `#IgnorePkg` in the file.  You can use `Control-W` to search the file.  Once found, replace `#IgnorePkg` with the following:
```
IgnorePkg   = linux-api-headers linux-armv7 linux-armv7-headers kexec-tools
```

Save and exit the *pacman.conf* file by pressing `Control-X`, followed by `Y`, and then `Enter`.

To perform updates and install new applications, you must initialize the pacman keyring and verify the master keys.
```
pacman-key --init
pacman-key --populate archlinuxarm
```

Sync the package databases and upgrade the system.
```
pacman -Syu
```

You can find more information about the pacman keyring and updating the system via the ArchLinux wiki - https://wiki.archlinux.org/title/Pacman/Package_signing

For example, if a system upgrade has been delayed for an extended period, you should manually sync the package database and upgrade the *archlinux-keyring* before performing a system upgrade.
```
pacman -Sy archlinux-keyring && pacman -Su
```

After completing all updates, install sudo to enable specific users to perform elevated operations without having to be logged in as `root`.
```
pacman -S sudo
```

Create a new user for yourself. Replace `newuser` in this command with the desired username.
```
useradd --create-home newuser
```

Set a password for the new user. Replace `newuser` in this command with the previously created username.
```
passwd newuser
```

Add the new account to the `wheel` group. We will later add the `wheel` group to the *sudoers* file to allow accounts added to `wheel` to perform priveleged/adminstrator actions. Replace `newuser` in this command with the previously created username.
```
usermod -aG wheel newuser
```

Install vi so that you can edit the *sudoers* file.
```
pacman -S vi
```

Open the *sudoers* file
```
visudo
```

Scroll down until you find the following line and uncomment by it removing the `#` to grant sudo access to anyone in the `wheel` group.
```
# %wheel ALL=(ALL) ALL
```

You can also search for text in vi, however vi is not intuitive for new users. If you don't already know how, it's probably faster and easier just to scroll using the arrow keys. You can find some information on text searches here - https://linuxize.com/post/vim-search/, or by performing a search via a search engine.

Write and quit vi by entering a `:` to enter *command mode*.  Once in *command mode*, enter `wq` and press `enter`.

Optional - Edit the system's hostname.  You can set the hostname to something more appropriate for your network, but remember, the hostname can only contain the characters A-Z, 0-9 and '-'.
```
sudo nano /etc/hostname
```

Exit the root session
```
exit
```

Exit alarm session if you wish to log back in as the new sudo user you just created.
```
exit
```

Or, shutdown the Steam Link if you're not ready to perform additional tasks
```
shutdown now
```

At this point, your SSH session will terminate. Your are now finished with the intial setup of ArchLinux and you can log in via SSH as the new sudo user you just created.

If you changed the system's hostname, you will need to update your SSH connection configuration if you're using the hostname instead of the IP address.

## Optional - Setup and Enable WiFi ##

#### Install Firmware and Dependencies ####
Install marvell firmware for wifi.
```
pacman -S linux-firmware-marvell
```

Install wifi dependencies
```
pacman -S dialog
pacman -S wpa_supplicant
```

#### MAC Address Spoofing (Optional) ####
Note: This is really only necessary if you have more than one Steam Link on the same network at the same time. Every steam link I've tested (only 2) seems to have the same MAC address for the wireless interface `mlan0`. To help prevent IP address conflicts, we can change/spoof the wireless interface's MAC address to something unique.

Lookup the current WiFi MAC address and note it. It will be listed as `link/ether`.
```
sudo ip link show mlan0
```

*Which should produce something similar to this:*
```
$ sudo ip link show mlan0
5: mlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP mode DORMANT group default qlen 1000
    link/ether 00:50:43:02:fe:01 brd ff:ff:ff:ff:ff:ff

```

Lookup the current ethernet MAC address and note it. Again, it will be listed as `link/ether`.
```
sudo ip link show eth0
```

*Which should also produce something similar to this:*
```
$ sudo ip link show eth0
2: eth0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc pfifo_fast state DOWN mode DEFAULT group default qlen 1000
    link/ether e0:31:9e:0e:49:d8 brd ff:ff:ff:ff:ff:ff
```

Create a new systemd file to contain the spoofed MAC address configuration details.
```
sudo nano /etc/systemd/network/01-mac.link
```

Enter configuration details into the new systemd file by creating the following lines.
```
[Match]
PermanentMACAddress=00:50:43:02:fe:01

[Link]
MACAddress=e0:31:9e:23:d3:9d
```

You will need to replace the `PermanentMACAddress` value (under [Match]) in the example with the permanent MAC address you looked up and noted for the `mlan0` interface previously. You will alsso need to enter a new MAC address to to act as the spoofed MAC address by replacing the `MACAddress` value (under [Link]) in the example. I like to use the `eth0` interface's MAC address you noted earlier, with the final letter or number increased by 1 (a -> b, c -> d, 1 -> 2).  This seems to be how Valve did it in the original Steam Link system.

Restart the machine
```
sudo reboot
```

Once the machine has booted back up, SSH back in using the sudo user account.

#### Enable and Connect to WiFi ####
Run the wifi setup application
```
sudo wifi-menu
```

Highlight desire WiFi network's SSID and press `enter`.

Confirm the desired netctl profile name and press `enter`. This will default to the interface name followed by the SSID - `mlan0-SSIDName`

Type in the WiFi network's passcode and press `enter`

The wifi-menu application will take a minute to complete the setup before exiting back to the command line.

After the WiFi connection is formed and the netctl profile is creating, enable auto roaming so that WiFi will automatically connect after booting or after leaving and coming back into range of the network.
```
sudo systemctl enable netctl-auto@mlan0.service
```

Reboot the Steam Link.
```
sudo reboot
```

Verify WiFi has connected and you have an IP address on the `mlan0` interface. The IP address will be listed under `inet`.
```
ifconfig -a
```

You should see an entry for the `mlan0` interface that looks something like this:
```
mlan0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.1.86  netmask 255.255.255.0  broadcast 192.168.1.255
        inet6 fd5e:d40b:2317:4abe:e231:9eff:fe0e:49d9  prefixlen 64  scopeid 0x0<global>
        inet6 fe80::e231:9eff:fe0e:49d9  prefixlen 64  scopeid 0x20<link>
        ether e0:31:9e:0e:49:d9  txqueuelen 1000  (Ethernet)
        RX packets 6014  bytes 1586266 (1.5 MiB)
        RX errors 0  dropped 3  overruns 0  frame 0
        TX packets 645  bytes 103536 (101.1 KiB)
        TX errors 2  dropped 0 overruns 0  carrier 0  collisions 0
```

If the system did not connect to WiFi, you can connect to it manually with the following command, replacing `mlan0-SSIDName` with the profile name entered earlier.
```
sudo netctl-auto switch-to mlan0-SSIDName
```

The previous manual connection command oddly won't work until after a reboot, hence the earlier reboot. Starting the netctl profile first might avoid the need for a reboot. Replace `mlan0-SSIDName` with the profile name entered earlier.
```
sudo netctl start mlan0-SSIDName
```

Once WiFi has connected, permanently enable the netctl profile. This might be redundant at this point, but it doesn't harm anything. One more time, replace `mlan0-SSIDName` with the profile name entered earlier.
```
sudo netctl enable mlan0-SSIDName
```

## Instructions to Cross Compile Linux Kernel ##
The SteamLink hardware uses a 32-bit ARM CPU. For most of us, that means our primary computer's CPU is of a different architecture, e.g. x86. Since different CPU architectures use differing instruction sets, we can't just compile the Linux kernel using tools built for our CPU and expect it to work on the SteamLink. We need to cross compile the kernel to work with the 32-bit ARM CPU used in the SteamLink.

If you already had a SteamLink set up to boot into a custom Linux install, you could us the SteamLink to compile the Linux kernel without having to cross compile. I would recommend against doing this however, as the CPU in the SteamLink is not very powerful and it takes a very long time to complete.

My primary computer has a 64-bit x86 CPU, so the following instructions will be written for that architecture. At the time I wrote up these instructions, I believe I was running Ubuntu Desktop 23.10. I used Ubuntu because I was running it in a virtual machine, Ubuntu tends to be well optimized for that scenario, and it was relatively easy to find resources to help cross compile code. I have also followed these instructions successfully when running Pop!OS 22.04 LTS on bare metal. Pop!OS is based on Ubuntu.

I would imagine that you should also be able to cross compile the kernel using other flavors of Linux, Windows, a Mac with an Intel or M-series CPU, or other CPU architectures or OSes, however that is beyond the scope of these instructions.

#### Downloading the SteamLink SDK and the Linux Kernel ####
Ensure your system is up to date.
```
sudo apt update
sudo apt upgrade -y
```
Install Git
```
sudo apt install git
```
Create a directory to store the SteamLink SDK and Linux kernel files and navigate to the new directory.
```
mkdir ~/steamcc && cd ~/steamcc
```
Clone the SteamLink SDK Git repository.
```
git clone https://github.com/ValveSoftware/steamlink-sdk.git
```
Navigate to https://kernel.org/ and determine which Linux kernel you want to compile. If you need help, https://itsfoss.com/compile-linux-kernel/ has a good description of what the different "versions" mean.

Download the kernel and PGP signature file. The example below is downloading the 6.6.8 version of the kernel, but you can replace the URLs in the `wget` commands with the URLs of the corresponding files for the version you chose.

An easy way to get those URLs is to right click the `tarball` and `pgp` links on https://kernel.org/ and then select `Copy Link` to copy the URLs to your clipboard.
```
mkdir ~/steamcc/kernel-dl && cd ~/steamcc/kernel-dl
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.8.tar.xz 
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.8.tar.sign
```

#### Verify the tarball file is not corrupted. ####
Note: More detailed instructions and information about this process can be found here - https://itsfoss.com/compile-linux-kernel/

Decompress the tarball. You should still be in the `~/steamcc/kernel-dl/` directory.
```
unxz --keep linux-*.tar.xz
```
Install gnupg2 if you don't already have it installed.
```
sudo apt install gnupg2
```
Fetch public GPG keys used to sign the tarball
```
gpg2 --locate-keys torvalds@kernel.org gregkh@kernel.org
```
Verify the integrity of the tarball
```
gpg2 --verify linux-*.tar.sign
```
You should receive a message that says something along these lines - `gpg: Good signature from "Greg Kroah-Hartman <gregkh@kernel.org>"` If you do, then you can proceed with extracting the tarball. Do not proceed if the tarball does not validate. Re-download the files and try again.

Extract the tarball
```
tar -xf linux-*.tar
```
Clean up the downloaded files, leaving the extracted files in place. 
```
rm linux-*.tar*
```
Move the extracted kernel files to the `steamlink-sdk` folder 
```
mv ~/steamcc/kernel-dl/linux-* ~/steamcc/steamlink-sdk/
```
Navigate to the `~/steamcc/steamlink-sdk/` directory and clean up the `~/steamcc/kernel-dl` directory. 
```
cd ~/steamcc/steamlink-sdk/ && rm -r ~/steamcc/kernel-dl
```
#### Install Dependencies ####
We are almost ready to begin cross compiling the kernel, but first we must install package dependencies. I'm honestly not sure all of these are necessary, but I built this list of dependencies from from Ubuntu's wiki (https://wiki.ubuntu.com/KernelTeam/ARMKernelCrossCompile) and based on my own experiences.
```
sudo apt-get install build-essential kexec-tools kernel-wedge gcc-arm-linux-gnueabihf
sudo apt-get install gcc-arm-linux-gnueabihf libncurses5 libncurses5-dev libelf-dev || sudo apt-get install gcc-arm-linux-gnueabihf libncurses-dev libelf-dev 
sudo apt-get install asciidoc binutils-dev 
sudo apt-get install libgmp3-dev libmpc-dev
```
Before we can install the last dependencies we must enable the `deb-src` repositories. Note: I retried these cross compile instructions on Pop!OS 22.04 LTS and did not need to update the sources.list file. You may want to try installing the final dependencies before editing your source files.
```
sudo nano /etc/apt/sources.list
```
Uncomment all lines starting with `deb-src` (delete the #). For example, `# deb-src http://us.archive.ubuntu.com/ubuntu/ mantic main restricted` becomes `deb-src http://us.archive.ubuntu.com/ubuntu/ mantic main restricted`

Save and exit the file by pressing `Control-o` then `Enter` and then `Control-x`.

Install the final dependencies.
```
sudo apt update
sudo apt-get build-dep linux
```
#### Configure Your Environment and Kernel ####
Navigate to your Linux kernel folder inside the `steamlink-sdk` directory
```
cd ~/steamcc/steamlink-sdk/linux*
```
Download a kernel config file based on Valve's config file
```
wget https://raw.githubusercontent.com/craw0967/steamlink-archlinux/refs/heads/main/config
```
Rename the downloaded config file to `.config`.  This will replace the default `.config` file.
```
mv config .config
```
Set up your environment.
```
source ~/steamcc/steamlink-sdk/setenv.sh export ARCH=arm; export LOCALVERSION="-mrvl"; export CROSS_COMPILE=arm-linux-gnueabihf-
```
Update the config file to set the kernel's Local Version suffix using the config script provided by Valve
```
./scripts/config --file .config --set-str LOCALVERSION "-mrvl"
```
Prepare the make configuration to match the kernel being compiled and set any additional options you wish to include.
```
make ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- menuconfig
```
Save and exit the menuconfig application.

Build the kernel.

Note: You can attempt to build the kernel without using sudo, but if it fails run `make clean` and then retry using sudo.
```
sudo make ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- -k
```
Grab the resulting `zImage` file and store it in a known location.
```
mkdir ~/steamcc/arch_boot && cp ~/steamcc/steamlink-sdk/linux*/arch/arm/boot/zImage ~/steamcc/arch_boot/
```
Grab the `berlin2cd-valve-steamlink.dtb` file and store it in a known location.
```
cp ~/steamcc/steamlink-sdk/linux*/arch/arm/boot/dts/synaptics/berlin2cd-valve-steamlink.dtb ~/steamcc/arch_boot/
```
Make the kernel modules.
```
sudo make ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- modules
```
Install kernel modules to a known location
```
make ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- INSTALL_MOD_PATH=~/steamcc/arch_boot modules_install
```
Clean up the modules and keep just the necessary files.
```
cd ~/steamcc/arch_boot && mv ~/steamcc/arch_boot/lib/modules/*-mrvl ~/steamcc/arch_boot/ && rm -r ~/steamcc/arch_boot/lib && rm -r ~/steamcc/arch_boot/*-mrvl/build
```
**TODO** - Add instructions on generating initramfs image. The image included in the repository works, however instructions would be good for historical purposes or for anyone wanting to generate their own.
#### Create a USB Drive Boot Drive Using the New Kernel ####
Clone install script Git repository
```
cd ~/steamcc
git clone https://github.com/craw0967/steamlink-archlinux.git
```
Navigate to repository directory
```
cd ~/steamcc/steamlink-archlinux
```
Clean up the old files in the repository.
```
rm berlin2cd-valve-steamlink.dtb && rm -r *-mrvl && rm zImage*
```
Copy new kernel files to the repository directory
```
cp -r ~/steamcc/arch_boot/* ~/steamcc/steamlink-archlinux/
```
Plug in a USB flash drive and follow instructions for the install script - https://github.com/craw0967/steamlink-archlinux#installation-steps

## References ##

- https://github.com/ValveSoftware/steamlink-sdk
- https://github.com/regmibijay/steamlink-archlinux
- https://github.com/mill1000/steamlink-kexec
- https://github.com/lukas2511/steamlink-sdk
- https://github.com/chaosmaster/ford_kexec
- https://heap.ovh/getting-linux-on-valve-steam-link.html
- https://www.reddit.com/r/Steam_Link/comments/fgew5x/running_archlinux_on_steam_link_revisited/
- https://web.archive.org/web/20190925025431/http://www.livxtrm.com/steamlink/
- https://forum.doozan.com/read.php?8,46664,page=1
- https://www.kernel.org/
- http://os.archlinuxarm.org/os/
- https://wiki.ubuntu.com/KernelTeam/ARMKernelCrossCompile
- https://itsfoss.com/compile-linux-kernel/