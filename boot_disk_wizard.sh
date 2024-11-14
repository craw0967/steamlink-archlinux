#!/bin/bash

# Define the script's name and usage
SCRIPT_NAME="boot_disk_wizard"
USAGE="Usage: $SCRIPT_NAME [-p <directory_path>]"

# Define the install path variable
INSTALL_PATH=""

# Parse the command-line arguments
while getopts ":p:" opt; do
  case $opt in
    p) INSTALL_PATH="$OPTARG" ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
  esac
done

# Source the cross_compile_functions.sh script
source boot_disk_functions.sh

# Check if the install path is set
if [ -z $INSTALL_PATH ]; then
  # Call the cross_compile_kernel function without passing in an install path
  create_boot_disk
else
  # Call the cross_compile_kernel function with the INSTALL_PATH variable as the install path
  create_boot_disk $INSTALL_PATH
fi