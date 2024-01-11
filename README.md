# SteamLink-Archlinux #
This repository hosts a modified version of the script found in this GitHub repository - https://github.com/regmibijay/steamlink-archlinux

From regmibijay's repo - Create Archlinux boot medium for steamlink with one script! (According to regmibijay, the kernel can supposedly be updated inside Archlinux once you flash it, however I have not determined an easy method of doing that without compiling a new kernel.)

This repository will install a newer linux kernel (6.1.66) than the GitHub repository linked above (which install kernel 5.4.24). You can compile a newer Linux kernel yourself, but that is beyond the scope of this README. You can find instructions in the Wiki here (TODO). Additionally, if you do compile a newer Linux kernel, the script will need to be modified to accomodate the different files.

You can also manually perform the steps that the script automates. The script is relatively straightforward, as far as scripts go, but you can also find a basic outline of steps on Reddit here - https://www.reddit.com/r/Steam_Link/comments/fgew5x/running_archlinux_on_steam_link_revisited/

You can also find more details on how to compile the kernel for the Steam Link and how to install the necessary files here - https://heap.ovh/getting-linux-on-valve-steam-link.html and here - https://web.archive.org/web/20190925025431/http://www.livxtrm.com/steamlink/. 

The kernel used in this repository was compiled by myself. The author of the post at heap.ovh has two earlier kernel versions compiled if you prefer, including the kernel used in the repository this one is based off of.

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
git clone https://git.arcnet.pw/acrawford/SteamLink-ArchLinux.git
```

Plug in the USB drive you wish to install Archlinux onto. If you are using a Virtual Machine, ensure the USB drive is correctly passed through to the VM.

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

Follow the prompts and enter in the drive you wish to format and install Archlinux to. Be very careful at this point as the script will format whatever drive you select.
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

You can find more information about the pacman keyring and updating the system via the Archlinux wiki - https://wiki.archlinux.org/title/Pacman/Package_signing

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

At this point, your SSH session will terminate. Your are now finished with the intial setup of Archlinux and you can log in via SSH as the new sudo user you just created.

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
###### This is really only necessary if you have more than one Steam Link on the same network at the same time. Every steam link I've tested (only 2) seems to have the same MAC address for the wireless interface `mlan0`. To help prevent IP address conflicts, we can change/spoof the wireless interface's MAC address to something unique.  ######

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
