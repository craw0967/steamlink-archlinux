#!/bin/bash

#set up users before boot?
#ask to set username and password?

# ----- Variables -----
install_choice=0
kernel_choice=0
dev_address=""
partitions=0

# ----- Functions -----
source utilities.sh
source cross_compile_functions.sh

create_boot_disk() {
	if ! is_sudo; then
		exit 1
	fi

	echo "Welcome to the Steam Link Arch Linux Boot Disk Creator!"
	echo ""
	echo "This script will guide you through the process of creating a boot disk for your Steam Link device."
	echo ""

	prompt_installation_type
	prompt_kernel
	select_disk_device

	# -- Handle possible outcomes for user choices
	# The disk must have at least one partition
	# If the disk has no partitions - The user cannot update an existing installation. Alert the user that the disk has no partitions and advise the user that the disk must be reformatted, ask for confirmation, and if approved, create a new partition and format. update the install_choice to 1 and set the device address to the new partition.
	# If the disk has multiple partitions - alert the user, ask if the other partitions should be deleted, and if approved, delete the all partitions except the first partition and move on to the next step. if the user does not approve, move on to the next step
	# If the disk has one partition - move on to the next step

	# Unmount the device if it is mounted
	# TODO: Check if the device is mounted before unmounting
	# TODO: Check if device actually needs formatting before unmounting and formatting
		# Device must be ext3
		# Device must have at least one partition
		# If device is ext3 and has at least one partition, user must have selected a clean installation
		# If device has multiple partitions, check if the other partitions should be deleted
	echo "Unmounting $dev_address to prepare for possible formatting and partitioning"
	sudo umount -l $dev_address

	# Check if the device has any partitions
	partitions=$(get_number_of_partitions "$dev_address")

	# TODO: If the user selects a parent device, the script isn't making sure to use the 1st partition.
	
	# If the device has no partitions, ask the user if they want to format the device
	if [ $partitions -eq 0 ]; then
		format_disk_no_partitions
	fi

	# If the device has multiple partitions, ask the user if they want to delete the other partitions or not
	if [ $partitions -gt 1 ]; then
		format_disk_multiple_partitions
	fi

	# If the user has selected a clean installation, ask the user if they would like to do a fast format or a full format of the first partition.
	# If the answer is fast format, then format the partition using the fast format option.
	# If the answer is full format, then format the partition using the full format option.
	if [ $install_choice -eq 1 ]; then
		format_disk_device
	fi

	# If the user has selected to replace the existing kernel, warn the user of the potential consequences and ask for confirmation
	if [ $install_choice -eq 2 ]; then
		echo "WARNING: Replacing the existing kernel may render your system incompatible."
		echo "Proceeding with this action will overwrite the current kernel with a new one."
		echo "This may cause system instability or prevent your system from booting properly."
		echo "Please ensure you have a backup of your important files and a means to recover your system before proceeding."
		echo ""

		get_yes_no_confirmation_or_exit "Are you sure you want to continue?"
	fi

	# If the user has selected to compile a new kernel, call the functions to cross compile a new kernel
	if [ $kernel_choice -eq 1 ]; then
		echo "You have selected to compile and install a new kernel. Proceeding with a new kernel..."

		# Call the functions to cross compile a new kernel
		cross_compile_kernel

	# If the user has selected to use the provided kernel, do nothing
	elif [ $kernel_choice -eq 2 ]; then
		echo "You have selected to install the provided kernel. Proceeding with the provided kernel..."
	fi

	# Remount the device so that it is ready for installation
	if [ ! -d "/media/steamlink_boot" ]; then
		sudo mkdir -p /media/steamlink_boot/
	fi
	sudo mount $dev_address /media/steamlink_boot

	# If the user has selected to perform a clean installation
	if [ $install_choice -eq 1 ]; then
		echo "Performing clean install..."

		install_boot_files
		install_kernel

		# If the user has selected to update the kernel only
	elif [ $install_choice -eq 2 ]; then
		echo "Performing update of the kernel..."

		install_kernel
	fi

	install_cleanup
}

prompt_installation_type() {
	local install_prompt="Select an installation option:"
	local install_options=(1 2)
	local install_descriptions=("Create a new clean installation" "Update the kernel on an existing installation")

	# -- Select install option
	install_choice=$(select_option install_prompt install_options install_descriptions)
}

prompt_kernel() {
	local kernel_prompt="Would you like to compile a new kernel or use the provided kernel?"
	local kernel_options=(1 2)
	local kernel_descriptions=("Compile a new kernel" "Use the provided kernel")

	# -- Select wheher to compile a new kernel or use the provided
	kernel_choice=$(select_option kernel_prompt kernel_options kernel_descriptions)
}

select_disk_device() {
	echo "Select a disk to use for the installation:"
	echo ""

	get_disks

	echo ""
	echo "The boot disk must have at least one partition and the Steam Link will only boot from the first partition."
	echo "The list above has been filtered to only show disks and first partitions."
	echo "If you select a device that does not have any partitions, a new partition will be created."
	echo "If a device has multiple partitions, you will be warned and asked to confirm if the other partitions should be deleted."
	echo ""
	echo "Please enter the /dev/ address of the drive you wish to install to from above."
	echo "Example: /dev/sdb1"
	echo ""

	while [ ! -b "$dev_address" ]; do
		read -p "Enter the device address: " dev_address
		echo ""

		if [ -b "$dev_address" ] && echo "$(get_disks)" | grep -q "$dev_address"; then
			echo "You have selected the device address $dev_address"
		else
			echo "Device address $dev_address is not a valid device or partition."
			echo "Please enter a valid device address..."
		fi
		echo ""
	done
}

format_disk_no_partitions() {
	local prompt_text="Enter your choice: "
	local option_choices=("1" "2")
	local descriptions_text=("Format the device" "Cancel")

	echo "The device $dev_address does not have any partitions. It must have at least one partition."
	echo "Please confirm that you want to format the device. All data on the device will be lost!"
	echo ""

	local format_device=$(select_option prompt_text option_choices descriptions_text)

	case "$format_device" in
	1)
		echo "WARNING: The selected device, $dev_address, will have a new partition table created and all data will be lost!"
		echo "Please ensure you have a backup of your important files before proceeding."
		echo ""

		get_yes_no_confirmation_or_exit "Are you sure you want to continue?"

		install_choice=1
		dev_address=$(get_parent_device "$dev_address")

		echo "Creating new partition table and partition on $dev_address..."

		sudo parted -s "$dev_address" mklabel msdos mkpart primary ext3 0% 100%
		dev_address=$(get_first_partition "$dev_address")

		echo "The new partition is $dev_address"
		;;
	*)
		echo "Operation cancelled. Please select a different device."
		exit 1
		;;
	esac
}

format_disk_multiple_partitions() {
	local prompt_text="What do you want to do with the partitions? "
	local option_choices=("1" "2" "3")
	local descriptions_text=("Delete all partitions except the first partition" "Keep all partitions as they are and use the first partition for the installation" "Cancel")

	echo "The device $dev_address has $partitions partitions. The first partition must be used for the installation."
	echo ""

	local delete_partitions=$(select_option prompt_text option_choices descriptions_text)

	case "$delete_partitions" in
	1)
		echo "WARNING: You have selected to delete all partitions except the first partition on device, $(get_parent_device $dev_address). All data on those partitionswill be lost!"
		echo "Please ensure you have a backup of your important files before proceeding."
		echo ""

		get_yes_no_confirmation_or_exit "Are you sure you want to continue?"

		echo "Deleting all partitions except the first partition on $dev_address..."

		delete_all_but_first_partition "$dev_address"
		dev_address=$(get_first_partition "$dev_address")

		echo "The partition $dev_address will be used for the installation."
		;;
	2)
		dev_address=$(get_first_partition "$dev_address")

		echo "Keeping all partitions as they are. The partition $dev_address will be used for the installation."
		;;
	*)
		echo "Operation cancelled. Please select a different device."
		exit 1
		;;
	esac
}

format_disk_device() {
	local prompt_text="What do you want to do with the partition?"
	local option_choices=("1" "2" "3")
	local descriptions_text=("Fast format" "Full format" "Cancel")

	# -- Ask the user if they want to do a fast format or a full format of the first partition
	echo "The partition $dev_address will be used for the installation."
	echo "All data on this partition will be deleted."
	echo ""

	local format_choice=$(select_option prompt_text option_choices descriptions_text)

	if [[ ! "$format_choice" == "3" ]]; then
		echo "WARNING: The selected device, $dev_address, will be formatted and all data will be lost!"
		echo "Please ensure you have a backup of your important files before proceeding."
		echo ""

		get_yes_no_confirmation_or_exit "Are you sure you want to continue?"
	fi

	if [[ "$format_choice" == "1" ]]; then
		# Check if the partition is already ext3
		if is_ext3 "$dev_address"; then
			echo "Erasing all files on $dev_address."
			mount_device $dev_address
			erase_mounted_device_files
		else
			echo "The partition $dev_address is not ext3 format, the fast format option is not available."
			echo "The full format option will reformat the device in ext3 format."
			format_choice="2"
		fi
	fi
	if [[ "$format_choice" == "2" ]]; then
		echo "Formatting partition $dev_address with the full format option..."
		format_ext3 "$dev_address"
		mount_device $dev_address
	fi
	if [[ "$format_choice" == "3" ]]; then
		echo "Operation cancelled. Please select a different device."
		exit 1
	fi
}

install_boot_files() {
	echo "Downloading the latest ArchLinux ARMV7 userspace"
    download_file http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz /home/$SUDO_USER/steamcc/steamlink-archlinux/ArchLinuxARM-armv7-latest.tar.gz
    download_file http://os.archlinuxarm.org/os/ArchLinuxARM-armv7-latest.tar.gz.sig /home/$SUDO_USER/steamcc/steamlink-archlinux/ArchLinuxARM-armv7-latest.tar.gz.sig

	# Fetch public GPG keys
	install_gpg_keys builder@archlinuxarm.org
    install_package pv
    echo "Unpacking the latest ArchLinux ARMV7 userspace and installing it to $dev_address"
    if verify_tarball /home/$SUDO_USER/steamcc/steamlink-archlinux/ArchLinuxARM-armv7-latest.tar.gz /home/$SUDO_USER/steamcc/steamlink-archlinux/ArchLinuxARM-armv7-latest.tar.gz.sig; then
		# Decompress tarball
        echo "Decompressing the tarball..."
	    decompress_tarball /home/$SUDO_USER/steamcc/steamlink-archlinux/ArchLinuxARM-armv7-latest.tar.gz
        # Extract tarball
        echo "Extracting the tarball..."
        echo "Depending on the speed of the selected disk, this may take a while."
		extract_tarball /home/$SUDO_USER/steamcc/steamlink-archlinux/ArchLinuxARM-armv7-latest.tar /media/steamlink_boot
    fi

	echo "Copying kexec_load.ko"
	sudo cp kexec_load.ko /media/steamlink_boot/boot/

	echo "Copying kexec and 755 on kexec"
	sudo cp kexec /media/steamlink_boot/usr/bin
	sudo chmod 755 /media/steamlink_boot/usr/bin/kexec

	echo "Copying run.sh and 755 on it"
	sudo mkdir -p /media/steamlink_boot/steamlink/factory_test/
	sudo cp run.sh /media/steamlink_boot/steamlink/factory_test/
	sudo chmod 755 /media/steamlink_boot/steamlink/factory_test/run.sh

	echo "Creating ssh folder and enabling SSH"
	sudo mkdir -p /media/steamlink_boot/steamlink/config/system/
	sudo echo "True" >/media/steamlink_boot/steamlink/config/system/enable_ssh.txt

    echo "Update pacman.conf to ignore linux-api-headers, linux-armv7, linux-armv7-headers and kexec-tools packages."
    sudo bash -c 'mv /media/steamlink_boot/etc/pacman.conf /media/steamlink_boot/etc/pacman.conf.original && awk "/#IgnorePkg/ { print; print \"IgnorePkg = linux-api-headers linux-armv7 linux-armv7-headers kexec-tools\"; next }1" /media/steamlink_boot/etc/pacman.conf.original > /media/steamlink_boot/etc/pacman.conf'
}

install_kernel() {
	echo "Copying zImage"
	sudo cp zImage* /media/steamlink_boot/boot/zImage

	echo "Copying initramfs"
	sudo cp initramfs-linux-steam*.img /media/steamlink_boot/boot/initramfs-linux-steam.img

	echo "Copying berlin2cd-valve-steamlink.dtb"
	sudo cp berlin2cd-valve-steamlink.dtb /media/steamlink_boot/boot/

	echo "Copying kernel modules"
	sudo cp -r *-mrvl/ /media/steamlink_boot/lib/modules/
}

install_cleanup() {
	echo "Completed, unmounting disk. This may take a while."
	sudo umount -l $dev_address

	echo "Cleaning up ... "
	sudo rm -rf /media/steamlink_boot

	echo "Completed. Please remove the USB disk and insert it into steamlink."
}