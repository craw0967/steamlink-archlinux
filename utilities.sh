#!/bin/bash

# chown_to_sudo_user: Changes the ownership of a given file or directory
#   to the user running the script.
#
# Parameters:
#   path (string) - The path to the file or directory to change the
#     ownership of
#
# Returns:
#   0 if the ownership is successfully changed, 1 otherwise
chown_to_sudo_user() {
	local path=$1
	local owner
	local group

	# Get the primary group name of the user running the script
	local sudo_group=$(id -gn "$SUDO_USER")

	# Check that the path input is not empty
	if [ -z "$path" ]; then
		echo "Error: Input for path is empty" >&2
		return 1
	fi

	# Check that the path exists
	if [ ! -e "$path" ]; then
		echo "Error: Path $path does not exist" >&2
		return 1
	fi

	# Get the owner of the given path
	owner=$(stat -c "%U" "$path")
	if [ $? -ne 0 ]; then
		echo "Error: Unable to get owner of $path" >&2
		return 1
	fi

	# Get the group of the given path
	group=$(stat -c "%G" "$path")
	if [ $? -ne 0 ]; then
		echo "Error: Unable to get group of $path" >&2
		return 1
	fi

	# Check if the owner or group of the path are not the user running the script's
	# UID or GID (user identifier and group identifier)
	if [ "$owner" != "$SUDO_USER" ] || [ "$group" != "$sudo_group" ]; then
		# Change the ownership of the path to the user running the script
		echo "Changing ownership of $path to $SUDO_USER..."
		if ! sudo chown -R "$SUDO_USER:$sudo_group" "$path"; then
			# If there was an error, print an error message with the path name
			echo "Error changing ownership of $path" >&2
			return 1
		fi
		# If the ownership was changed successfully, print a success message
		echo "Ownership of $path changed successfully"
	else
		# If the ownership is already correct, print a message indicating that it is
		echo "Ownership of $path is already $SUDO_USER:$sudo_group"
	fi
	# Return 0 to indicate success
	return 0
}

# create_and_chown_dir: Create a directory and change its ownership
#
# Synopsis:
#   create_and_chown_dir dir
#
# Parameters:
#   dir (string) - The directory to create
#
# Returns:
#   0 if the directory is created and its ownership is changed, 1 otherwise
create_and_chown_dir() {
	local dir=$1

	# Check that the directory input is not empty
	if [ -z $dir ]; then
		echo "Error: Input for the directory to create is empty" >&2
		return 1
	fi

	# Create the directory if it doesn't already exist
	echo "Creating directory $dir..."
	if ! sudo mkdir -p $dir; then
		# If there was an error, print an error message with the directory name
		echo "Error creating directory: $dir" >&2
		return 1
	fi

	# Change the ownership of the directory to the user running the script
	chown_to_sudo_user $dir
	return $?
}

# move_and_chown: Move a file and change its ownership
#
# Synopsis:
#   move_and_chown src dst
#
# Parameters:
#   src (string) - The source file to move
#   dst (string) - The destination file
#
# Returns:
#   0 if the file is moved and its ownership is changed, 1 otherwise
move_and_chown() {
	local src=$1
	local dst=$2

	# Check that the source and destination inputs are not empty
	if [ -z $src ]; then
		echo "Error: Input for source file is empty" >&2
		return 1
	fi
	if [ -z $dst ]; then
		echo "Error: Input for destination file is empty" >&2
		return 1
	fi

	# Move the file or directory from the source path to the destination path
	if [ -d $dst ]; then
		echo "Moving file or directory from $src to $dst$(basename $src)..."
		dst=$dst$(basename $src)
	else
		echo "Moving file or directory from $src to $dst..."
	fi

	if ! mv $src $dst; then
		# If there was an error, print an error message with the source file or directory name
		echo "Error moving file: $src" >&2
		return 1
	fi

	# Change the ownership of the file or directory to the user running the script
	chown_to_sudo_user $dst
	return $?
}

# move_and_chown_dir: Move a directory and change its ownership
#
# Synopsis:
#   move_and_chown_dir src_dir dst_dir
#
# Parameters:
#   src_dir (string) - The source directory to move
#   dst_dir (string) - The destination directory
#
# Returns:
#   0 if the directory and its contents are moved and its ownership is changed, 1 otherwise
move_and_chown_dir() {
	local src_dir=$1
	local dst_dir=$2

	# Check that the source and destination inputs are not empty
	if [ -z $src_dir ]; then
		echo "Error: Input for source directory is empty" >&2
		return 1
	fi
	if [ -z $dst_dir ]; then
		echo "Error: Input for destination directory is empty" >&2
		return 1
	fi

	# Check that the source directory exists
	if [ ! -d $src_dir ]; then
		echo "Error: Source directory $src_dir does not exist" >&2
		return 1
	fi

	# Move all files and directories in the source directory to the destination directory,
	# changing their ownership to the user running the script.
	echo "Moving contents of directory $src_dir to $dst_dir..."
	for item in $src_dir/*; do
		if [ -e $item ]; then
			# Move the file or directory
			move_and_chown $item $dst_dir
			if [ $? -ne 0 ]; then
				# If there was an error, exit with an error message
				echo "Error moving $item to $dst_dir. Exiting..." >&2
				return 1
			fi
		fi
	done
}

# clone_git_repo: Clone a Git repository and change its ownership
#
# Synopsis:
#   clone_git_repo repo_url repo_dir
#
# Parameters:
#   repo_url (string) - The URL of the Git repository to clone
#   repo_dir (string) - The directory to clone the repository into
#
# Returns:
#   0 if the repository is cloned, 1 otherwise
clone_git_repo() {
	local repo_url=$1
	local repo_dir=$2

	# Check that the repository URL and directory inputs are not empty
	if [ -z $repo_url ]; then
		echo "Error: Input for repository URL is empty" >&2
		return 1
	fi
	if [ -z $repo_dir ]; then
		echo "Error: Input for directory to clone repository into is empty" >&2
		return 1
	fi

	# Get the name of the repository without the .git extension
	local repo_name=$(basename $repo_url .git)

	# Check if the repository is already cloned
	if [ -d $repo_dir/$repo_name ]; then
		# If the repository is already cloned, skip it
		echo "Skipping $repo_url, repository is already cloned."
		return 0
	fi

	# Clone the repository
	echo "Cloning $repo_url..."
	if ! git clone $repo_url $repo_dir/$repo_name; then
		# If there was an error, print an error message with the repository name
		echo "Error cloning repository: $repo_name" >&2
		return 1
	fi

	# Change the ownership of the cloned repository to the user running the script
	chown_to_sudo_user $repo_dir/$repo_name
	return $?
}

# verify_linux_version_exists: Check if a Linux version exists
#
# Synopsis:
#   verify_linux_version_exists version url
#
# Parameters:
#   version (string) - The Linux version to check
#   url (string) - The URL of the Linux kernel with the given version
#
# Returns:
#   0 if the Linux version exists, 1 otherwise
verify_linux_version_exists() {
	local version=$1
	local url=$2

	# Check that the Linux version and URL inputs are not empty
	if [ -z $version ]; then
		echo "Error: Input for Linux version is empty." >&2
		return 1
	fi
	if [ -z $url ]; then
		echo "Error: Input for Linux kernel URL is empty." >&2
		return 1
	fi

	# Use wget to check if the URL is valid. We use the --spider option to
	# avoid downloading the file, and the &> /dev/null to suppress the output.
	# If the URL is valid, wget will return 0, and the if statement will be true.
	# If the URL is invalid, wget will return 1, and the if statement will be false.
	if wget --spider $url &>/dev/null; then
		# If the Linux version exists, print a message indicating that it's available
		# and return 0 to indicate success.
		echo "Linux version $version is available. Proceeding with download..." >&2
		return 0
	else
		# If the Linux version does not exist, print an error message and return 1
		# to indicate failure.
		echo "Linux version $version is not available. Please enter a valid Linux version." >&2
		return 1
	fi
}

# download_file: Download a file from a URL and save it to a specified file path
#
# Synopsis:
#   download_file url file_path
#
# Parameters:
#   url (string) - The URL to download from
#   file_path (string) - The file path to save the downloaded file to
#
# Returns:
#   0 if the file is downloaded successfully, 1 otherwise
download_file() {
	local url=$1
	local file_path=$2

	# Check that the URL and file_path inputs are not empty
	if [ -z $url ]; then
		# If the URL is empty, print an error message and return 1 to indicate failure
		echo "Error: Input for URL is empty." >&2
		return 1
	fi
	if [ -z $file_path ]; then
		# If the file_path is empty, print an error message and return 1 to indicate failure
		echo "Error: Input for file path is empty." >&2
		return 1
	fi

	# Check if the file already exists
	if [ -f $file_path ]; then
		# If the file already exists, print a message indicating that it will not be downloaded
		# and return 0 to indicate success
		echo "Skipping download, $file_path already exists."
		return 0
	fi

	# Check if the URL is valid
	if ! wget --spider $url &>/dev/null; then
		# If the URL is invalid, print an error message and return 1 to indicate failure
		echo "Error: Unable to download $url. URL is invalid or not accessible." >&2
		return 1
	fi

	# Download the file
	echo "Downloading $url to $file_path..."
	# Use wget to download the file from the URL to the specified file path
	wget $url -O $file_path
	if [ $? -eq 0 ]; then
		# If the download is successful, print a message indicating that the file was downloaded
		# and return 0 to indicate success
		echo "File $file_path downloaded successfully."
	else
		# If the download fails, print an error message and return 1 to indicate failure
		echo "Error downloading file $file_path." >&2
		return 1
	fi

	# Return 0 to indicate success
	return 0
}

# verify_tarball: Verify the integrity of a tarball
#
# Parameters:
#   tarball (string) - The path to the tarball to verify
#   signature (string) - The path to the GPG signature for the tarball
#
# Returns:
#   0 if the verification is successful, 1 otherwise
verify_tarball() {
	local tarball=$1
	local signature=$2

	# Check if the tarball and signature inputs are not empty
	if [ -z $tarball ]; then
		echo "Error: Input for tarball is empty." >&2
		return 1
	fi

	if [ -z $signature ]; then
		echo "Error: Input for signature is empty." >&2
		return 1
	fi

	# Check if the tarball and signature files exist
	if [ ! -f $tarball ]; then
		echo "Error: Tarball file does not exist." >&2
		return 1
	fi

	if [ ! -f $signature ]; then
		echo "Error: Signature file does not exist." >&2
		return 1
	fi

	# Use GPG to verify the tarball
	echo "Verifying tarball..."
	gpg2 --verify $signature $tarball
	if [ $? -ne 0 ]; then
		# If the verification fails, print an error message and exit with a 1 to indicate failure
		echo "Error: Tarball verification failed." >&2
		return 1
	fi
	# If the verification is successful, print a message indicating success
	echo "Tarball verified successfully"
	# Return 0 to indicate success
	return 0
}

# Function to decompress a tarball
# decompress_tarball: Decompress a tarball using xz
#
# Synopsis:
#   decompress_tarball tarball
#
# Parameters:
#   tarball (string) - The path to the tarball to decompress
#
# Returns:
#   0 if the tarball is decompressed successfully, 1 otherwise
decompress_tarball() {
	local tarball=$1

	# Check that the tarball input is not empty
	if [ -z $tarball ]; then
		echo "Error: Input for tarball is empty." >&2
		return 1
	fi

	# Check that the tarball exists
	if [ ! -f $tarball ]; then
		echo "Error: Tarball $tarball does not exist." >&2
		return 1
	fi

	# Check if the decompressed file already exists
	if [ -f "${tarball%.*}" ]; then
		echo "Skipping decompression, decompressed file already exists."
		return 0
	fi

	# Decompress the tarball
	echo "Decompressing $tarball..."
	if [[ $tarball =~ \.tar\.gz$ ]]; then
		if ! pv -s $(stat -c%s $tarball) <$tarball | gunzip >${tarball%.gz}; then
			# If the decompression fails, print an error message and return 1 to indicate failure
			echo "Error: Unable to decompress tarball $tarball." >&2
			return 1
		fi
	elif [[ $tarball =~ \.tar\.xz$ ]]; then
		if ! pv -s $(stat -c%s $tarball) <$tarball | unxz >${tarball%.xz}; then
			# If the decompression fails, print an error message and return 1 to indicate failure
			echo "Error: Unable to decompress tarball $tarball." >&2
			return 1
		fi
	else
		echo "Error: Unknown tarball format." >&2
		return 1
	fi

	# If the decompression is successful, print a success message and return 0 to indicate success
	echo "Tarball $tarball decompressed successfully."
	return 0
}

# extract_tarball: Extract a tarball using tar
#
# Synopsis:
#   extract_tarball tarball extract_dir
#
# Parameters:
#   tarball (string) - The path to the tarball to extract
#   extract_dir (string) - The directory to extract the tarball into
#
# Returns:
#   0 if the tarball is extracted successfully, 1 otherwise
extract_tarball() {
	local tarball=$1
	local extract_dir=$2

	# Check that the tarball and extract_dir inputs are not empty
	if [ -z $tarball ]; then
		echo "Error: Input for tarball is empty." >&2
		return 1
	fi
	if [ -z $extract_dir ]; then
		echo "Error: Input for directory to extract into is empty." >&2
		return 1
	fi

	# Check that the tarball exists
	if [ ! -f $tarball ]; then
		# If the tarball does not exist, print an error message and return 1 to indicate failure
		echo "Error: Tarball $tarball does not exist." >&2
		return 1
	fi

	# Check that the extract directory is a directory
	if [ ! -d $extract_dir ]; then
		# If the extract directory does not exist, print an error message and return 1 to indicate failure
		echo "Warning: Directory $extract_dir does not exist. Creating..." >&2
		create_and_chown_dir $extract_dir
	fi

	# Use tar to extract the tarball into the specified directory
	echo "Extracting $tarball..."

	if ! pv $tarball | tar -xf - -C $extract_dir 2> >(grep -v "Ignoring unknown extended header keyword 'LIBARCHIVE.xattr.security.SMACK64'" >&2); then
		# If the extraction fails, print an error message and return 1 to indicate failure
		echo "Error: Unable to extract tarball $tarball." >&2
		return 1
	fi
	# If the extraction is successful, print a success message and return 0 to indicate success
	echo "Directory $extract_dir extracted successfully."
	return 0
}

# install_gpg_keys: Install a GPG key if it is not already installed
#
# Synopsis:
#   install_gpg_keys key_email1 key_email2 ...
#
# Parameters:
#   key_email* (strings) - The email addresses of the GPG keys to install
#
# Returns:
#   0 if all the keys are installed successfully, 1 otherwise
install_gpg_keys() {
	local key_emails=("$@")
	local success=0

	# Check that the key_emails array is not empty
	if [ -z $key_emails ]; then
		echo "Error: At least one email address is required" >&2
		return 1
	fi

	# Initialize an array to keep track of the keys that need to be installed
	local keys_to_install=()
	local keys_already_installed=()

	echo "Installing GPG keys..."
	# Iterate over the key_emails and check if the key is already installed
	for key_email in "${key_emails[@]}"; do
		# If the key is not installed, add it to the keys_to_install array
		if ! gpg2 --list-keys $key_email &>/dev/null; then
			keys_to_install+=($key_email)
		else
			# If the key is already installed, print a message indicating that it's
			# already installed
			keys_already_installed+=($key_email)
			echo "Skipping $key_email, key is already installed."
		fi
	done

	# Check if there are any keys that need to be installed
	if [ ${#keys_to_install[@]} -gt 0 ]; then
		# Print a message indicating that the keys will be installed
		echo "Installing keys for ${keys_to_install[@]}..."

		# Attempt to install the keys
		for email in "${keys_to_install[@]}"; do
			gpg2 --locate-keys $email
			success=$?

			# If the installation fails, try again with the ubuntu keyserver
			if [ $success -ne 0 ]; then
				gpg2 --auto-key-locate clear,cert,pka,dane,keyserver,wkd -vvv --keyserver hkp://keyserver.ubuntu.com --locate-external-key $email
				success=$?
			fi

			# Check if the installation was successful
			if [ ! $success -eq 0 ]; then
				# If there was an error, print an error message with the keys that need
				# to be installed
				echo "Error: Unable to install keys for ${email}" >&2
			else
				# If the keys were installed successfully, print a message indicating that
				# they were installed successfully
				echo "Key for ${email} installed successfully."
			fi
		done
	fi

	if [ ${#keys_already_installed[@]} -gt 0 ]; then
		# Pringt a message indicating that they were already installed and will be refreshed
		echo "Refreshing keys for ${keys_already_installed[@]}..."
		if ! gpg2 --refresh-keys ${keys_already_installed[@]}; then
			# If there was an error, print an error message with the keys that need
			# to be installed
			echo "Error: Unable to refresh keys for ${keys_already_installed[@]}" >&2
			# Return 1 to indicate failure
			return 1
		else
			# If the keys were refreshed successfully, print a message indicating that
			# they were refreshed successfully
			echo "Keys for ${keys_already_installed[@]} refreshed successfully."
		fi
	fi

	return 0
}

# Implement the code for the TODO comment
# install_package: Install a package
#
# Synopsis:
#   install_package package
#
# Parameters:
#   package (string) - The package to install
#
# Returns:
#   0 if the package is installed successfully, 1 otherwise
install_package() {
	local package=$1

	# Check if the package name is not empty
	if [[ -z $package ]]; then
		echo "Error: Input for package is empty." >&2
		return 1
	fi

	# Call install_packages with the package
	install_packages $package
}

# install_packages: Install a list of packages
#
# Synopsis:
#   install_packages package1 package2 ...
#
# Parameters:
#   package1, package2, ... (strings) - The packages to install
#
# Returns:
#   0 if all of the packages are installed successfully, 1 otherwise
install_packages() {
	local packages=("$@")

	# Check if the input for the packages is not empty
	if [[ ${#packages[@]} -eq 0 ]]; then
		echo "Error: Input for packages is empty." >&2
		return 1
	fi

	# Check which packages are not installed
	local missing_packages=()
	echo "Checking for missing packages: ${packages[@]}"
	for package in "${packages[@]}"; do
		if ! dpkg -s $package &>/dev/null; then
			# If the package is not installed, add it to the missing_packages array
			missing_packages+=($package)
		fi
	done

	# If there are any missing packages, install them
	if [[ ${#missing_packages[@]} -gt 0 ]]; then
		# Print a message indicating which packages are missing
		echo "Installing missing packages: ${missing_packages[@]}"

		# Attempt to install the missing packages using apt-get
		if ! sudo apt-get install -y "${missing_packages[@]}"; then
			# If the installation fails, print an error message and return 1
			echo "Error installing packages: ${missing_packages[@]}" >&2
			return 1
		else
			# If the installation is successful, print a success message
			echo "Packages installed successfully."
			# If the installation is successful, return 0
			return 0
		fi
	else
		# If all packages are already installed, print a message indicating that
		echo "All packages are already installed."
		# If all packages are already installed, return 0
		return 0
	fi
}

# clean_up_dir: Clean up a directory by removing it
#
# Parameters:
#   dir (string) - The directory to clean up
#
# Returns:
#   0 if the directory is cleaned up successfully, 1 otherwise
clean_up_dir() {
	local dir=$1

	# Check that the directory input is not empty
	if [[ -z $dir ]]; then
		echo "Error: Input for directory is empty." >&2
		return 1
	fi

	# Check if the directory exists
	if [ -d $dir ]; then
		# If the directory exists, try to remove it
		if ! sudo rm -rf $dir; then
			# If there was an error, print an error message with the directory name
			echo "Error removing directory: $dir" >&2
			return 1
		else
			# If the directory is removed successfully, print a success message
			echo "Directory $dir cleaned up successfully."
			return 0
		fi
	else
		# If the directory does not exist, print a message indicating that it's not
		# necessary to clean it up
		echo "Directory $dir does not exist, skipping cleanup."
		return 0
	fi
}

# clean_up_file: Clean up a file by removing it
#
# Parameters:
#   file (string) - The file to clean up
#
# Returns:
#   0 if the file is cleaned up successfully, 1 otherwise
clean_up_file() {
	local file=$1

	# Check if the file input is empty
	if [[ -z $file ]]; then
		# If the file input is empty, print an error message and return 1 to indicate failure
		echo "Error: Input for file is empty." >&2
		return 1
	fi

	# Check if the file exists
	if [ -f $file ]; then
		# If the file exists, remove it
		if ! sudo rm -f $file; then
			# If there was an error removing the file, print an error message and return 1 to indicate failure
			echo "Error removing file: $file" >&2
			return 1
		else
			# If the file was removed successfully, print a success message
			echo "File $file cleaned up successfully."
			# Return 0 to indicate success
			return 0
		fi
	else
		# If the file does not exist, print an informational message indicating that the file
		# does not exist, so there is nothing to clean up
		echo "File $file does not exist, skipping cleanup."
		# Return 0 to indicate success
		return 0
	fi
}

# is_sudo: Check if the script is being run with sudo or as root
#
# Parameters:
#   None
#
# Returns:
#   0 if the script is run with sudo or as root, 1 otherwise
is_sudo() {
	# Check if EUID is set and valid
	if [ -z "$EUID" ]; then
		echo "Error: EUID is not set." >&2
		return 1
	fi

	# Check if the script is run as root
	if [ "$EUID" -eq 0 ]; then
		return 0
	else
		echo "This script must be run with sudo or as root." >&2
		return 1
	fi
}

# mount_device: Mount a device to the /media/steamlink_boot/ directory
#
# Parameters:
#   dev_address (string) - The device address to mount
#
# Returns:
#   0 if the device was mounted successfully, 1 otherwise
mount_device() {
	local dev_address=$1

	# Check if the device address was provided
	if [[ -z $dev_address ]]; then
		echo "Error: Device address was not provided, cannot mount." >&2
		return 1
	fi

	# Create the mount point directory if it doesn't exist
	if ! sudo mkdir -p /media/steamlink_boot/; then
		echo "Error: Failed to create mount point directory." >&2
		return 1
	fi

	# Mount the device to the mount point
	if ! sudo mount $dev_address /media/steamlink_boot; then
		echo "Error: Failed to mount device." >&2
		return 1
	fi
}

# erase_mounted_device_files: Erase all files on the mounted device
#
# Parameters:
#   None
#
# Returns:
#   0 if the files were erased successfully, 1 otherwise
erase_mounted_device_files() {
	# Check if the mount point exists
	if [ ! -d /media/steamlink_boot ]; then
		echo "Error: Mount point /media/steamlink_boot does not exist." >&2
		return 1
	fi

	# Remove all files on the device, but do not remove the mount point itself
	if ! sudo rm -rf /media/steamlink_boot/*; then
		echo "Error: Failed to erase files on mounted device." >&2
		return 1
	fi
	return 0
}

# format_ext3: Format a drive as ext3
#
# Parameters:
#   dev_address (string) - The address of the device to format
#
# Returns:
#   0 if the device was formatted successfully, 1 otherwise
format_ext3() {
	local dev_address="$1"

	# Check if the device address was provided
	if [ -z "$dev_address" ]; then
		echo "Error: Device address was not provided, cannot format." >&2
		return 1
	fi

	# Check if the device exists
	if [ ! -b "$dev_address" ]; then
		echo "Error: Device $dev_address does not exist." >&2
		return 1
	fi

	# Format the device as ext3. The -F option forces the format, so be careful
	# when using this.
	if ! sudo mkfs.ext3 -F "$dev_address"; then
		echo "Error: Failed to format device as ext3." >&2
		return 1
	fi
	return 0
}

# get_disks: List all disks and the first partition on each disk
#
# Parameters:
#   None
#
# Returns:
#   None
get_disks() {
	# List block devices with details using lsblk and filter the output with awk
	# Exclude zram devices and devices with size 0B
	# Include only disks, TYPE headers, and partitions ending with "1" (e.g., /dev/sda1)
	lsblk -po NAME,SIZE,TYPE,TRAN,MOUNTPOINT | awk '
		$1 !~ /zram/ && $2 != "0B" && 
		($3 ~ /^disk$/ || $3 ~ /^TYPE$/ || ($3 ~ /^part$/ && $1 ~ /1$/)) {
			printf "%s\n", $0
		}'
	#lsblk -po NAME,SIZE,TYPE,TRAN,MOUNTPOINT | awk '$1 !~ /zram/ && $2 != "0B" && ($3 ~ /^disk$/ || $3 ~ /^TYPE$/ || ($3 ~ /^part$/ && $1 ~ /1$/)){printf "%s\n", $0}'
}

# is_ext3: Check if a device is an ext3 partition
#
# Parameters:
#   dev_address (string) - The device to check
#
# Returns:
#   0 if the device is an ext3 partition, 1 otherwise
is_ext3() {
	#lsblk -d -o FSTYPE "$1" | grep -q "ext3"
	#return $?

	local dev_address="$1"
	
	# Check if the device address was provided
	if [ -z "$dev_address" ]; then
		echo "Error: Device address was not provided, cannot verify file system type." >&2
		return 1
	fi

	local file_system
	# Get the file system type
	file_system=$(lsblk -d -o FSTYPE "$1" | grep -v "^FSTYPE$")

	# Check if the file system type is ext3
	if [ "$file_system" != "ext3" ]; then
		echo "Error: Device $1 is not an ext3 partition." >&2
		return 1
	fi

	# If the file system type is ext3, return success
	return 0
}

# is_partition: Check if a device is a partition
#
# Parameters:
#   dev_address (string) - The device to check
#
# Returns:
#   0 if the device is a partition, 1 otherwise
is_partition() {
	#lsblk -d -o NAME,TYPE "$1" | grep -q "part"
	#return $?

	local dev_address="$1"

	# Check that the device address was provided
	if [ -z "$dev_address" ]; then
		echo "Error: Device address was not provided, cannot verify if it is a partition." >&2
		return 1
	fi

	# Check that the device exists
	if [ ! -b "$dev_address" ]; then
		echo "Error: Device $dev_address does not exist." >&2
		return 1
	fi

	# Check if the device is a partition
	# Get the file system type
	local file_system
	file_system=$(lsblk -d -o TYPE "$dev_address" | grep -v "^TYPE$")

	# Check if the file system type is "part"
	if [ "$file_system" != "part" ]; then
		#echo "Warning: Device $dev_address is not a partition." >&2
		return 1
	fi

	# If the device is a partition, return success
	return 0
}

# get_parent_device: Get the parent device of a partition
#
# Parameters:
#   dev_address (string) - The device to get the parent of
#
# Returns:
#   The parent device name if the device is a partition, the device name if not a partition, 1 if the device does not exist
get_parent_device() {
	local dev_address="$1"

	# Check if the device address is provided
	if [ -z "$dev_address" ]; then
		echo "Error: Device address is not provided." >&2
		return 1
	fi

	# Check if the device exists
	if [ ! -b "$dev_address" ]; then
		echo "Error: Device $dev_address does not exist." >&2
		return 1
	fi

	# If the device is a partition, get the parent device
	if is_partition "$dev_address"; then
		local parent_device
		# Get the parent device name by using lsblk with the -p option to
		#   get the full path of the device and the PKNAME column to get the
		#   parent device name
		parent_device=$(lsblk -n -p -o NAME,PKNAME "$dev_address" | awk -v dev="$dev_address" 'tolower($1) == tolower(dev) {print $2}')
		if [ -n "$parent_device" ]; then
			echo "$parent_device"
			return 0
		else
			echo "Error: Unable to determine parent device." >&2
			return 1
		fi
	fi

	# If the device is not a partition, return the device
	echo "$dev_address"
	return 0
}

# delete_all_but_first_partition: Delete all partitions on a disk except the first partition
#
# Parameters:
#   disk (string) - The disk to delete partitions from
#
# Returns:
#   0 if the partitions are deleted successfully, 1 otherwise
delete_all_but_first_partition() {
	local disk="$1"
	local partitions

	# Check that the disk input is not empty
	if [ -z "$disk" ]; then
		echo "Error: Input for disk is empty." >&2
		return 1
	fi

	# Check that the disk is a valid disk
	if [ ! -b "$disk" ]; then
		echo "Error: $disk is not a valid disk." >&2
		return 1
	fi

	# Get a list of partitions on the disk
	partitions=$(lsblk -nlpo NAME,TYPE "$disk" | grep "part" | awk '{print $1}')

	# Check that there are partitions on the disk
	if [ -z "$partitions" ]; then
		echo "Error: No partitions found on $disk." >&2
		return 1
	fi

	# Loop through each partition and delete it if it's not the first partition
	for part in $partitions; do
		local part_num=${part##$disk}

		# Only delete the partition if it's not the first partition
		if ! [[ "$part_num" == "1" ]]; then
			echo "Deleting $disk$part_num..." >&2

			# Use parted to delete the partition
			if ! sudo parted -s "$disk" rm "$part_num"; then
				echo "Error: Could not delete partition $part." >&2
				return 1
			fi
		fi
	done

	return 0
}

# get_first_partition: Get the first partition of a device
#
# Parameters:
#   dev_address (string) - The device address to get the first partition from
#
# Returns:
#   The first partition address if it exists, 1 otherwise
get_first_partition() {
	local dev_address="$1"

	# Check that the device address was provided
	if [ -z "$dev_address" ]; then
		echo "Error: Device address was not provided." >&2
		return 1
	fi

	# Check if the device exists and is listed by get_disks
	if [ ! -b "$dev_address" ] || ! echo "$(get_disks)" | grep -q "$dev_address"; then
		echo "Error: $dev_address is not a valid device or partition." >&2
		return 1
	fi

	local first_partition="$(get_parent_device $dev_address)1"
	local no_of_partitions=$(get_number_of_partitions "$dev_address")

	# Check for the existence of partitions and if the first partition is valid
	if [ $no_of_partitions -gt 0 ] && is_partition "$first_partition"; then
		# if the first partition exists, return it
		echo "$first_partition"
		return 0
	else
		echo "Error: $dev_address does not have a valid partition." >&2
		return 1
	fi
}


# extend_first_partition: Extend the first partition of a device to use the entire disk
#
# Parameters:
#   disk (string) - The device address to extend the first partition from
#
# Returns:
#   0 if the first partition is successfully extended, 1 otherwise
extend_first_partition() {
	local disk="$1"
	local partition

	# Check that the device address was provided
	if [ -z "$disk" ]; then
		echo "Error: Device address was not provided." >&2
		return 1
	fi

	# Get the first partition of the device
	# We use parted to print the partition table and grep to get the partition number
	# We assume that the first partition is the first line of the partition table
	partition=$(sudo parted -s "$disk" print | grep -oP '^\d+' | head -1)
	if [ -z "$partition" ]; then
		# If the partition number is empty, it means parted failed to print the partition table
		echo "Error: Failed to get the first partition of $disk" >&2
		return 1
	fi

	# Extend the first partition to use the entire disk
	# We use parted to resize the partition to the end of the disk
	# We use 100% to tell parted to resize the partition to the end of the disk
	if ! sudo parted -s "$disk" resizepart "$partition" 100%; then
		# If parted failed to resize the partition, it means there was an error
		echo "Error: Failed to extend the first partition of $disk" >&2
		return 1
	fi
}

# get_number_of_partitions: Get the number of partitions on a device
#
# Parameters:
#   dev_address (string) - The device address to get the number of partitions from
#
# Returns:
#   The number of partitions on the device if it exists, 1 otherwise
get_number_of_partitions() {
	local dev_address="$1"

	# Check if the device address was provided
	if [ -z "$dev_address" ]; then
		echo "Error: Device address was not provided." >&2
		return 1
	fi

	# Get the parent device
	local parent_device
	parent_device=$(get_parent_device "$dev_address")
	if [ $? -ne 0 ]; then
		echo "Error: Failed to get parent device for $dev_address." >&2
		return 1
	fi

	# Get the number of partitions on the parent device
	local num_partitions
	num_partitions=$(lsblk -p "$parent_device" -o NAME,TYPE | grep "part" | wc -l)
	if [ $? -ne 0 ]; then
		echo "Error: Failed to get number of partitions on $parent_device." >&2
		return 1
	fi

	echo "$num_partitions"
	return 0
}

# get_yes_no_confirmation_or_exit: Prompt the user for a yes/no confirmation and exit if they answer no
#
# Parameters:
#   prompt (string) - The prompt to display to the user
#
# Returns:
#   0 if the user answers yes, 1 if the user answers no
get_yes_no_confirmation_or_exit() {
	local prompt="$1"
	local confirmation
	while [ "$confirmation" != "y" ] && [ "$confirmation" != "n" ]; do
		# Prompt the user to enter y or n
		read -p "$prompt (y/n)" -r confirmation

		# If the user answered no, exit
		if [ "$confirmation" = "n" ]; then
			exit 1
		# If the user entered something other than y or n, print an error message
		elif [ "$confirmation" != "y" ]; then
			echo ""
			echo "Invalid choice. Please enter y or n..."
			echo ""
		fi
	done
}

# get_yes_no_confirmation: Prompt a user to enter y or n to confirm a statement
#
# Parameters:
#   prompt (string) - The prompt to display to the user
#
# Returns:
#   The entered choice (y or n)
get_yes_no_confirmation() {
	local prompt="$1"
	local confirmation
	while [ "$confirmation" != "y" ] && [ "$confirmation" != "n" ]; do
		# Prompt the user to enter y or n
		read -p "$prompt (y/n)" -r confirmation

		# If the user entered y or n, return the entered choice
		if [ "$confirmation" = "y" ] || [ "$confirmation" = "n" ]; then
			echo "$confirmation"
			return
		# If the user entered something other than y or n, print an error message
		else
			# Print an error message with a blank line before and after
			echo "" >&2
			echo "Invalid choice. Please enter y or n..." >&2
			echo "" >&2
		fi
	done
}

# select_option: Prompt a user to select a choice from a list of options
#
# Parameters:
#   prompt (string) - The prompt to display to the user
#   options (array) - The options to present to the user
#   descriptions (array) - The descriptions to display for each option
#   format (string) - Optional format string to use when displaying the options.
#                     The format string should have two format specifiers for the
#                     option and the description respectively.
#
# Returns:
#   The selected option
select_option() {
	local -n prompt=$1
	local -n options=$2
	local -n descriptions=$3
	local format=$4

	local option

	# Loop until the user selects a valid option
	while [ -z "$option" ] || ! [[ "$option" =~ ^(${options[@]})$ ]]; do
		# Display the prompt and options to the user
		echo "$prompt" >&2
		for i in "${!options[@]}"; do
			# Display the option and description to the user
			local desc=(${descriptions[i]})

			if [ ! -z "$format" ]; then
				# Use the format string if it was provided
				printf "%-0s: $format\n" "${options[i]}" "${desc[@]}" >&2
			else
				# Otherwise display the option and description in a default format
				echo "${options[i]}: ${desc[@]}" >&2
			fi
		done
		echo "" >&2

		# Prompt the user to enter their choice
		read -p "Enter your choice: " option

		# Check if the selected option is valid
		for i in "${!options[@]}"; do
			if [ "$option" = "${options[i]}" ]; then
				# If the option is valid, return it
				echo $option
				return
			fi
		done

		# Display an error message if the selected option is not valid
		echo "" >&2
		echo "Invalid choice. Please select one of the above options..." >&2
		echo "" >&2
	done
}
