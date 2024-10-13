#!/bin/bash

# Directory where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Log file
LOG_FILE="$SCRIPT_DIR/libopenal1_log_$(date '+%Y-%m-%d_%H-%M-%S').txt"
echo "Execution log - $(date)" > "$LOG_FILE"

# Redirect stdout and stderr to the log file
exec > "$LOG_FILE" 2>&1

## PART 1: Check and Install Requirements

# Declare an array of applications to check
applications=("libopenal1" "libopenal1:armhf")

# Flag to determine if at least one application is missing
missing_app=false

# First, check if any application is missing
for app in "${applications[@]}"; do
	if ! dpkg -l | grep -q "$app"; then
		missing_app=true
		break
	fi
done

# Execute the procedure if at least one application is missing
if [ "$missing_app" = true ]; then
    echo "Running pre-installation procedure..."
	
	# Synchronize system clock with NTP
	echo "Synchronizing system clock with NTP..."
	$ESUDO timedatectl set-ntp true
	
	# Print current system time
	echo "Current system time: $(date)"
	
	# Path
	SOURCES_LIST="/etc/apt/sources.list"
	
	# Get the current Ubuntu version codename (e.g., jammy, focal)
	UBUNTU_VERSION=$(lsb_release -cs)
	
	# Backup original sources.list
	echo "Backing up original sources.list..."
	BACKUP_SOURCES="/etc/apt/sources.list.bak"
	$ESUDO cp "$SOURCES_LIST" "$BACKUP_SOURCES"
	
	# Update sources.list to use the default Ubuntu mirrors with detected version
	echo "Updating sources.list to use default Ubuntu mirrors for version $UBUNTU_VERSION..."
	$ESUDO bash -c "cat > $SOURCES_LIST" <<EOL
	# The source mirror is commented by default to improve the speed of apt update. You can uncomment it if necessary.

	# Main repositories
	deb http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION main restricted universe multiverse
	# deb-src http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION main restricted universe multiverse

	# Major bug fix updates # Universe repositories # Multiverse repositories
	deb http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-updates main restricted universe multiverse
	# deb-src http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-updates main restricted universe multiverse

	# Backports repositories
	deb http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-backports main restricted universe multiverse
	# deb-src http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-backports main restricted universe multiverse

	# Security updates
	deb http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-security main restricted universe multiverse
	# deb-src http://ports.ubuntu.com/ubuntu-ports/ $UBUNTU_VERSION-security main restricted universe multiverse
EOL

	# Update apt cache
	echo "Updating apt cache..."
	$ESUDO apt-get clean
	#$ESUDO apt-get update --allow-releaseinfo-change
	sudo dpkg --add-architecture armhf
	if $ESUDO apt-get update; then
    echo "Apt update successful."
	else
		echo "Apt update failed. Check your network or DNS settings."
		# Restore original files and exit
		echo "Restoring original files..."
		$ESUDO cp "$BACKUP_SOURCES" "$SOURCES_LIST"
		$ESUDO apt-get clean
		exit 1
	fi
	
	for app in "${applications[@]}"; do
		if ! command -v "$app" &> /dev/null 2>&1; then
			echo "$app could not be found, installing..."
			$ESUDO apt-get update && $ESUDO apt-get install -y "$app"
		fi
	done
	
	# Restore original sources.list
	echo "Restoring original sources.list..."
	$ESUDO cp "$BACKUP_SOURCES" "$SOURCES_LIST"

	# Disable NTP synchronization
	echo "Disabling NTP synchronization..."
	$ESUDO timedatectl set-ntp false

	$ESUDO apt-get clean
	#$ESUDO apt-get update --allow-releaseinfo-change
	sudo dpkg --remove-architecture armhf
	$ESUDO apt-get update
fi