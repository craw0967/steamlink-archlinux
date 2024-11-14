#!/bin/bash

# ----- Variables -----
linux_version=""

# ----- Functions -----
source utilities.sh

# cross_compile_kernel: Compile the SteamLink kernel and copy the files to
#   the install script directory.
#
# This function will install the necessary dependencies, download and configure
#   the kernel, build and install the kernel, clean up any remaining kernel
#   modules, and move the kernel files to the install script directory.
#
# The intention of this function is to be called from the another install script
#   as part of a larger installation process.
#
# If you wish to just compile and install the kernel, it is better to call the
#   cross_compile_kernel.sh script directly.
cross_compile_kernel() {
	local install_path="${1:-/home/$SUDO_USER/steamcc/steamlink-archlinux}"

	install_packages "wget curl"

	# Prompt user for kernel version
	select_kernel_version

	# Install dependencies if not already installed
	install_dependencies

	# Download the kernel and configure it for compilation
	download_kernel
	configure_kernel

	# Build and install the kernel
	build_kernel
	copy_kernel_files

	# Clean up any remaining kernel modules
	clean_kernel_modules

	# Move the kernel files to the install script directory
	move_kernel_files ${install_path}
}

select_kernel_version() {
	local linux_version_valid=1
	local option_selected=0

	local url="https://www.kernel.org/releases.json"
	local json_data=$(curl -s "$url")
	local i=1

	local version_prompt="Select the Linux version you wish to compile (Note: the 'mainline' and 'linux-next' versions are not currently supported):"
	local kernel_versions=()
	local version_options=()

	# Parse the JSON data into the kernel_options and kernel_descriptions arrays
	while IFS= read -r line; do
		kernel_versions+=("$line")
		version_options+=($i)
		((i++))
	done < <(jq -r '.releases[] | select(.source != null and .moniker != "mainline") | .moniker + ": " + .version + " " + .released.isodate' <<<"$json_data")

	kernel_versions+=("Enter version manually")
	version_options+=("e")

	while [ ! $linux_version_valid -eq 0 ]; do
		# Prompt user for Linux version
		if [ "$option_selected" == "0" ]; then
			option_selected=$(select_option version_prompt version_options kernel_versions "%-11s %-10s %-10s")
		fi

		if [ ! "$option_selected" == "0" ]; then
			if [ "$option_selected" == "e" ]; then
				read -p "Enter the Linux version you wish to compile (e.g. 6.6.8): " linux_version
				echo "You selected: ${linux_version}"
			else
				linux_version="${kernel_versions[$option_selected - 1]}"
				linux_version=$(echo "$linux_version" | cut -d' ' -f2)
				echo "You selected: ${linux_version}"
			fi

			# Check if Linux version is valid
			echo "Checking if ${linux_version} exists..."
			verify_linux_version_exists ${linux_version} https://cdn.kernel.org/pub/linux/kernel/v${linux_version:0:1}.x/linux-${linux_version}.tar.xz
			linux_version_valid=$?
			option_selected=0
		fi
	done
	# -- Select kernel version
	echo "Selected kernel version: ${linux_version}"

}

install_dependencies() {
	dependencies=(
		build-essential
		kexec-tools
		kernel-wedge
		gcc-arm-linux-gnueabihf
		libncurses5
		libncurses5-dev
		libncurses-dev
		libelf-dev
		asciidoc
		binutils-dev
		libgmp3-dev
		libmpc-dev
		wget
		curl
		gnupg2
		git
	)

	# Check for updates before running
	echo "Updating package list"
	sudo apt-get update

	# Only upgrade if there are available upgrades
	if sudo apt-get -s upgrade | grep -q "packages will be upgraded"; then
		echo "Upgrading packages"
		sudo apt-get upgrade -y
	else
		echo "No upgrades available"
	fi

	install_packages "${dependencies[@]}"

	echo "Checking if Linux build dependencies need to be installed"
	if sudo apt-get -s build-dep linux | grep -q "Inst"; then
		echo "Linux build dependencies need to be installed. Installing..."
		sudo apt-get build-dep linux
	else
		echo "Linux build dependencies are already installed"
	fi

}

download_kernel() {
	# Create directories to store SteamLink SDK and Linux kernel files
	create_and_chown_dir /home/$SUDO_USER/steamcc
	create_and_chown_dir /home/$SUDO_USER/steamcc/kernel-dl

	# Clone SteamLink SDK Git repository
	clone_git_repo https://github.com/ValveSoftware/steamlink-sdk.git /home/$SUDO_USER/steamcc

	# Download Linux kernel and PGP signature file
	download_file https://cdn.kernel.org/pub/linux/kernel/v${linux_version:0:1}.x/linux-${linux_version}.tar.xz /home/$SUDO_USER/steamcc/kernel-dl/linux-${linux_version}.tar.xz
	download_file https://cdn.kernel.org/pub/linux/kernel/v${linux_version:0:1}.x/linux-${linux_version}.tar.sign /home/$SUDO_USER/steamcc/kernel-dl/linux-${linux_version}.tar.sign

	# Decompress tarball
	decompress_tarball /home/$SUDO_USER/steamcc/kernel-dl/linux-${linux_version}.tar.xz

	# Fetch public GPG keys
	install_gpg_keys torvalds@kernel.org gregkh@kernel.org

	# Verify tarball integrity
	if verify_tarball /home/$SUDO_USER/steamcc/kernel-dl/linux-${linux_version}.tar /home/$SUDO_USER/steamcc/kernel-dl/linux-${linux_version}.tar.sign; then
		# Extract tarball
		extract_tarball /home/$SUDO_USER/steamcc/kernel-dl/linux-${linux_version}.tar /home/$SUDO_USER/steamcc/steamlink-sdk/
		# Change ownership to SUDO_USER
		chown_to_sudo_user /home/$SUDO_USER/steamcc/kernel-dl/linux-${linux_version}
		# Clean up downloaded files and directories
		clean_up_dir /home/$SUDO_USER/steamcc/kernel-dl
	else
		echo "Tarball integrity check failed. Exiting..."
		exit 1
	fi
}

configure_kernel() {
	# Download kernel config file
	download_file https://raw.githubusercontent.com/craw0967/steamlink-archlinux/refs/heads/main/config /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version}/config

	# Rename config file
	move_and_chown /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version}/config /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version}/.config

	# Set up environment
	source /home/$SUDO_USER/steamcc/steamlink-sdk/setenv.sh
	export ARCH=arm
	export LOCALVERSION="-mrvl"
	export CROSS_COMPILE=arm-linux-gnueabihf-

	# Update config file
	bash /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version}/scripts/config --file /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version}/.config --set-str LOCALVERSION "-mrvl"

	# Prepare make configuration using the old config file and default configuration for anything not defined in the old config file.
	#make -C /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version} ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- olddefconfig

	# Use menuconfig to configure kernel instead. Allows user to select menu items to enable/disable.
	# Example: Can enable GPU drivers in theory, by enabled Etnaviv/Vivante graphics driver, however it does not work with chroot and kexec
	# Unsure if this is an issue with the drivers, the kernel, or with the host OS not releasing the GPU
	make -C /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version} ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- menuconfig
}

build_kernel() {
	# Create directory for kernel files
	create_and_chown_dir /home/$SUDO_USER/steamcc/arch_boot

	# Build kernel
	sudo make -C /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version} ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- -k
	# Make kernel modules
	sudo make -C /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version} ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- modules
	# Install kernel modules
	make -C /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version} ARCH=arm CROSS_COMPILE=/usr/bin/arm-linux-gnueabihf- INSTALL_MOD_PATH=/home/$SUDO_USER/steamcc/arch_boot modules_install
}

copy_kernel_files() {
	# Copy zImage file
	cp /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version}/arch/arm/boot/zImage /home/$SUDO_USER/steamcc/arch_boot/
	# Copy berlin2cd-valve-steamlink.dtb file
	cp /home/$SUDO_USER/steamcc/steamlink-sdk/linux-${linux_version}/arch/arm/boot/dts/synaptics/berlin2cd-valve-steamlink.dtb /home/$SUDO_USER/steamcc/arch_boot/

	sudo chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/steamcc/arch_boot
}

clean_kernel_modules() {
	# Clean up kernel modules
	move_and_chown /home/$SUDO_USER/steamcc/arch_boot/lib/modules/${linux_version}-mrvl /home/$SUDO_USER/steamcc/arch_boot/
	rm -r /home/$SUDO_USER/steamcc/arch_boot/lib
	rm -r /home/$SUDO_USER/steamcc/arch_boot/*-mrvl/build
}

move_kernel_files() {
	local install_path="${1:-/home/$SUDO_USER/steamcc/steamlink-archlinux}"
	install_path="${install_path%/}/"

	create_and_chown_dir $install_path

	# Clone install script Git repository if it doesn't exist
	clone_git_repo https://github.com/craw0967/steamlink-archlinux.git /home/$SUDO_USER/steamcc

	# Clean up old files
	clean_up_file ${install_path}berlin2cd-valve-steamlink.dtb
	clean_up_dir ${install_path}*-mrvl
	clean_up_file ${install_path}zImage*

	sleep 0.5

	# Move new kernel files
	move_and_chown_dir /home/$SUDO_USER/steamcc/arch_boot ${install_path}
}
