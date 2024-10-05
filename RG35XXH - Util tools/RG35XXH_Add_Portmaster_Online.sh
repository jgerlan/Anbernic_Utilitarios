#!/bin/bash

# Jopseh1Hwk 30-09-2024
# Script to add PortMaster on Anbernic RG35XXH-V1.1.4 or higher - Online Version

# Directory where the script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

#SUDO
#ESUDO = sudo

# Log file
LOG_FILE="$SCRIPT_DIR/log_$(date '+%Y-%m-%d_%H-%M-%S').txt"
echo "Execution log - $(date)" > "$LOG_FILE"

# Redirect stdout and stderr to the log file
exec > "$LOG_FILE" 2>&1

## PART 1: Check and Install Requirements

# Declare an array of applications to check
applications=("unzip" "curl")

# Flag to determine if at least one application is missing
missing_app=false

# First, check if any application is missing
for app in "${applications[@]}"; do
    if ! command -v "$app" &> /dev/null 2>&1; then
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
	$ESUDO apt-get update
fi

## PART 2: Download PortMaster

# Define the URL of the PortMaster-GUI repository on GitHub
REPO_GUI="PortsMaster/PortMaster-GUI"

# Get all releases and their descriptions
RELEASES=$(curl --silent "https://api.github.com/repos/$REPO_GUI/releases")

# Use variables to temporarily store the tag_name and check the body
TAG_NAME=""
LATEST_STABLE_RELEASE=""

# Loop through the release lines
while read -r line; do
    if [[ "$line" == *'"tag_name":'* ]]; then
        # Capture the current tag_name
        TAG_NAME=$(echo "$line" | sed 's/.*"tag_name": "//;s/".*//')
    fi

    if [[ "$line" == *'"body":'* ]]; then
        # Check if the body contains "stable"
        if [[ "$line" == *"stable"* ]]; then
            LATEST_STABLE_RELEASE=$TAG_NAME
            break
        fi
    fi
done <<< "$RELEASES"

# Check if the stable version was obtained correctly
if [ -z "$LATEST_STABLE_RELEASE" ]; then
    echo "Could not find a stable version with 'stable' in the description."
    exit 1
fi

# Fetch the download link for PortMaster.zip in the latest stable version
ASSET_URL_GUI=$(curl --silent "https://api.github.com/repos/$REPO_GUI/releases/tags/$LATEST_STABLE_RELEASE" \
  | grep 'browser_download_url' \
  | grep 'PortMaster.zip' \
  | head -n 1 \
  | cut -d '"' -f 4)

# Check if the asset URL was obtained correctly
if [ -z "$ASSET_URL_GUI" ]; then
    echo "Could not find the 'PortMaster.zip' file for download."
    exit 1
fi

# Download the PortMaster.zip file
echo "Downloading PortMaster.zip from the latest stable release ($LATEST_STABLE_RELEASE)..."
curl -L -o "$SCRIPT_DIR/PortMaster.zip" "$ASSET_URL_GUI"

echo "PortMaster.zip download completed."

# Now let's extract PortMaster.zip
echo "Extracting PortMaster.zip..."

unzip -d "$SCRIPT_DIR/" "$SCRIPT_DIR/PortMaster.zip"

rm -rf "$SCRIPT_DIR/PortMaster.zip"

echo "Extraction complete."

# Now let's download mono-6.12.0.122-aarch64.squashfs

# Define the URL of the PortMaster-Hosting repository on GitHub
REPO_HOSTING="PortsMaster/PortMaster-Hosting"

# Check the latest release in the hosting repository
LATEST_RELEASE_HOSTING=$(curl --silent "https://api.github.com/repos/$REPO_HOSTING/releases/latest" | grep '"tag_name":' | sed 's/.*"tag_name": "//;s/".*//')

# Check if the version was obtained correctly
if [ -z "$LATEST_RELEASE_HOSTING" ]; then
    echo "Could not find the latest version."
    exit 1
fi

# Fetch the download link for mono-6.12.0.122-aarch64.squashfs
ASSET_URL_HOSTING=$(curl --silent "https://api.github.com/repos/$REPO_HOSTING/releases/tags/$LATEST_RELEASE_HOSTING" \
  | grep 'browser_download_url' \
  | grep 'mono-6.12.0.122-aarch64.squashfs' \
  | head -n 1 \
  | cut -d '"' -f 4)

# Check if the asset URL was obtained correctly
if [ -z "$ASSET_URL_HOSTING" ]; then
    echo "Could not find the 'mono-6.12.0.122-aarch64.squashfs' file for download."
    exit 1
fi

# Download the mono-6.12.0.122-aarch64.squashfs file
echo "Downloading mono-6.12.0.122-aarch64.squashfs from the latest release ($LATEST_RELEASE_HOSTING)..."
curl -L -o "$SCRIPT_DIR/mono-6.12.0.122-aarch64.squashfs" "$ASSET_URL_HOSTING"

echo "mono-6.12.0.122-aarch64.squashfs download completed."

## PART 3: Add PortMaster to the system

# Expected PortMaster directory in the script's location
PORTMASTER_DIR="$SCRIPT_DIR/PortMaster"

# Destination directory
DEST_DIR="/roms/ports"

# Name of the mono file
MONO_FILE="mono-6.12.0.122-aarch64.squashfs"

# Boolean to decide whether to backup the existing PortMaster directory
BACKUP_BEFORE_MODIFICATIONS=false

# Paths to specific files that need to be overwritten with new content
CONTROL_FILE="$PORTMASTER_DIR/control.txt"
GAMECONTROLLERDB_FILE="$PORTMASTER_DIR/gamecontrollerdb.txt"
DONOTTOUCH_FILE="$PORTMASTER_DIR/.Backup/donottouch.txt"

# Contents to overwrite the specified files
CONTROL_CONTENT=$(cat <<EOF
# This file can and should be sourced by ports for various parameters to 
# minimize script customizations and allow for easier future updates
# like adding additional supported devices.
# Thanks to JohnnyonFlame, dhwz, romadu, and shantigilbert for the 
# suggestion and assistance with this.
# Source used for gptokeyb available at
# https://github.com/christianhaitian/gptokeyb
# Source used for oga_controls available at
# https://github.com/christianhaitian/oga_controls

if [[ -e "/usr/share/plymouth/themes/text.plymouth" ]]; then
  if [ ! -z \$(cat /etc/fstab | grep roms2 | tr -d '\0') ]; then
    directory="roms2"
  else
    directory="roms"
  fi
else
  directory="roms"
fi

if [ -f "/etc/os-release" ]; then
  source /etc/os-release
fi

if [ -d "/PortMaster/" ]; then
  controlfolder="/PortMaster"
elif [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
else
  controlfolder="/\$directory/ports/PortMaster"
fi

sudo echo "Testing for sudo..."
if [ \$? != 0 ]; then
  echo "No sudo present."
  ESUDO=""
  ESUDOKILL="-1" # for 351Elec and EmuELEC use "-1" (numeric one) or "-k" 
  export SDL_GAMECONTROLLERCONFIG_FILE="\$controlfolder/gamecontrollerdb.txt"
else
  ESUDO="sudo --preserve-env=SDL_GAMECONTROLLERCONFIG_FILE,DEVICE,param_device,HOTKEY,ANALOGSTICKS"
  ESUDOKILL="-sudokill" # for ArkOS, RetroOZ, and TheRA use "-sudokill"
  export SDL_GAMECONTROLLERCONFIG_FILE="\$controlfolder/gamecontrollerdb.txt"
fi

if [[ -e "/dev/input/by-path/platform-soc@03000000:gpio_keys-event-joystick" ]]; then
  echo 1 > /sys/class/power_supply/axp2202-battery/nds_esckey
  dpid=\$(ps -A| grep "portsCtrl.dge"| awk 'NR==1{print \$1}')
  if [ \${dpid} ]; then
    echo "had run portsCtrl.dge"
  else
    /mnt/vendor/bin/portsCtrl.dge &
  fi
fi

if [[ -e "/usr/share/plymouth/themes/text.plymouth" ]]; then
  whichos=\$(grep "title=" "/usr/share/plymouth/themes/text.plymouth")
  if [[ \$whichos == *"TheRA"* ]]; then
    raloc="/opt/retroarch/bin"
    raconf=""
  elif [[ \$whichos == *"RetroOZ"* ]]; then
    raloc="/opt/retroarch/bin"
    raconf="--config /home/odroid/.config/retroarch/retroarch.cfg"
  else
    raloc="/usr/local/bin"
    raconf=""
  fi
elif [ "\${OS_NAME}" == "JELOS" ]; then
  raloc="/usr/bin"
  raconf="--config /storage/.config/retroarch/retroarch.cfg"
  export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib32
elif [[ -e "/storage/.config/.OS_ARCH" ]] || [[ -z \$ESUDO ]]; then
  raloc="/usr/bin"
  raconf="--config /storage/roms/gamedata/retroarch/config/retroarch.cfg"
  export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib32
fi

SDLDBFILE="\${SDL_GAMECONTROLLERCONFIG_FILE}"
[ -z "\${SDLDBFILE}" ] && SDLDBFILE="\${controlfolder}/gamecontrollerdb.txt"
SDLDBUSERFILE="\${HOME}/.config/SDL-GameControllerDB/gamecontrollerdb.txt"

get_controls() {

ANALOGSTICKS="2"
LOWRES="N"

if [[ -e "/dev/input/by-path/platform-ff300000.usb-usb-0:1.2:1.0-event-joystick" ]]; then
      DEVICE="03000000091200000031000011010000"
      param_device="anbernic"
      LOWRES="Y"
      if [ -f "/boot/rk3326-rg351v-linux.dtb" ] || [ \$(cat "/storage/.config/.OS_ARCH") == "RG351V" ]; then
        ANALOGSTICKS="1"
        LOWRES="N"
      fi
elif [[ -e "/dev/input/by-path/platform-soc@03000000:gpio_keys-event-joystick" ]]; then
      DEVICE="19000000010000000100000000010000"
      param_device="rg35xxh"
      LOWRES="N"
elif [[ -e "/dev/input/by-path/platform-odroidgo2-joypad-event-joystick" ]]; then
      if [[ ! -z \$(cat /etc/emulationstation/es_input.cfg | grep "190000004b4800000010000001010000") ]]; then
        DEVICE="190000004b4800000010000001010000"
        param_device="oga"
        export HOTKEY="l3"
      else
        DEVICE="190000004b4800000010000000010000"
        param_device="rk2020"
      fi
      ANALOGSTICKS=1
      LOWRES="Y"
elif [[ -e "/dev/input/by-path/platform-odroidgo3-joypad-event-joystick" ]]; then
      DEVICE="190000004b4800000011000000010000"
      param_device="ogs"
      if [ "\$(cat ~/.config/.OS)" == "ArkOS" ] && [ "\$(cat ~/.config/.DEVICE)" == "RGB10MAX" ]; then
        sed -i 's/back:b12,guide:b16,start:b13/back:b14,guide:b12,start:b15/' \${controlfolder}/gamecontrollerdb.txt
        sed -i 's/leftstick:b14,rightstick:b15/leftstick:b16,rightstick:b17/' \${controlfolder}/gamecontrollerdb.txt
        export HOTKEY="guide"
      fi
elif [[ -e "/dev/input/by-path/platform-gameforce-gamepad-event-joystick" ]]; then
      DEVICE="19000000030000000300000002030000"
      param_device="chi"
      export HOTKEY="l3"
elif [[ -e "/dev/input/by-path/platform-singleadc-joypad-event-joystick" ]]; then
      DEVICE="190000004b4800000111000000010000"
      param_device="rg552"
      LOWRES="N"
else
      DEVICE="\${1}"
      param_device="\${2}"
fi

    CONTROLS=\$(grep "\${SDLDBUSERFILE}" -e "\${DEVICE}")
    [ -z "\${CONTROLS}" ] && CONTROLS=\$(grep "\${SDLDBFILE}" -e "\${DEVICE}")
    sdl_controllerconfig="\${CONTROLS}"
}

GPTOKEYB="\$ESUDO \$controlfolder/gptokeyb \$ESUDOKILL"
EOF
)

GAMERCONTROLLERDB_CONTENT=$(cat <<EOF
// add SDL2 game controller mappings to this file

19000000010000000100000000010000,ANBERNIC-keys,a:b0,b:b1,x:b3,y:b2,back:b8,guide:b6,start:b7,leftstick:b9,rightstick:b12,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpleft:h0.8,dpdown:h0.4,dpright:h0.2,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:b10,righttrigger:b11,platform:Linux,

#Odroid Go Advance 1.0 and RK2020
190000004b4800000010000000010000,GO-Advance Gamepad,a:b1,b:b0,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,dpdown:b7,dpleft:b8,dpright:b9,dpup:b6,leftx:a0,lefty:a1,back:b10,lefttrigger:b12,righttrigger:b13,start:b15,platform:Linux,

#Odroid Go Advance 1.1 and RGB10 
190000004b4800000010000001010000,GO-Advance Gamepad (rev 1.1),a:b1,b:b0,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,dpdown:b9,dpleft:b10,dpright:b11,dpup:b8,leftx:a0,lefty:a1,righttrigger:b15,leftstick:b13,lefttrigger:b14,rightstick:b16,back:b12,start:b17,platform:Linux,

#RG351M, RG351P, and RG351V
03000000091200000031000011010000,OpenSimHardware OSH PB Controller,a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,leftx:a0~,lefty:a1~,guide:b12,leftstick:b8,lefttrigger:b10,rightstick:b9,back:b7,start:b6,rightx:a2,righty:a3,righttrigger:b11,platform:Linux,

#Odroid Go Super, RG351MP, RGB10Max, and RGB10Max2
190000004b4800000011000000010000,GO-Super Gamepad,x:b2,a:b1,b:b0,y:b3,back:b12,guide:b16,start:b13,dpleft:b10,dpdown:b9,dpright:b11,dpup:b8,leftshoulder:b4,lefttrigger:b6,rightshoulder:b5,righttrigger:b7,leftstick:b14,rightstick:b15,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,

#Gameforce Chi
19000000030000000300000002030000,gameforce_gamepad,leftstick:b14,rightx:a3,leftshoulder:b4,start:b9,lefty:a0,dpup:b10,righty:a2,a:b1,b:b0,back:b8,dpdown:b11,rightshoulder:b5,righttrigger:b7,rightstick:b15,dpright:b13,x:b2,guide:b16,leftx:a1,y:b3,dpleft:b12,lefttrigger:b6,platform:Linux,

#RG552
190000004b4800000111000000010000,retrogame_joypad,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,rightstick:b12,leftstick:b11,dpleft:b15,dpdown:b14,dpright:b16,dpup:b13,leftshoulder:b4,lefttrigger:b6,rightshoulder:b5,righttrigger:b7,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,
EOF
)

BACKUP_DONOTTOUCH_CONTENT=$(cat <<EOF
// add SDL2 game controller mappings to this file

19000000010000000100000000010000,ANBERNIC-keys,a:b0,b:b1,x:b3,y:b2,back:b8,guide:b6,start:b7,leftstick:b9,rightstick:b12,leftshoulder:b4,rightshoulder:b5,dpup:h0.1,dpleft:h0.8,dpdown:h0.4,dpright:h0.2,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:b10,righttrigger:b11,platform:Linux,

#Odroid Go Advance 1.0 and RK2020
190000004b4800000010000000010000,GO-Advance Gamepad,a:b1,b:b0,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,dpdown:b7,dpleft:b8,dpright:b9,dpup:b6,leftx:a0,lefty:a1,back:b10,lefttrigger:b12,righttrigger:b13,start:b15,platform:Linux,

#Odroid Go Advance 1.1 and RGB10 
190000004b4800000010000001010000,GO-Advance Gamepad (rev 1.1),a:b1,b:b0,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,dpdown:b9,dpleft:b10,dpright:b11,dpup:b8,leftx:a0,lefty:a1,righttrigger:b15,leftstick:b13,lefttrigger:b14,rightstick:b16,back:b12,start:b17,platform:Linux,

#RG351M, RG351P, and RG351V
03000000091200000031000011010000,OpenSimHardware OSH PB Controller,a:b0,b:b1,x:b2,y:b3,leftshoulder:b4,rightshoulder:b5,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,leftx:a0~,lefty:a1~,guide:b12,leftstick:b8,lefttrigger:b10,rightstick:b9,back:b7,start:b6,rightx:a2,righty:a3,righttrigger:b11,platform:Linux,

#Odroid Go Super, RG351MP, RGB10Max, and RGB10Max2
190000004b4800000011000000010000,GO-Super Gamepad,x:b2,a:b1,b:b0,y:b3,back:b12,guide:b16,start:b13,dpleft:b10,dpdown:b9,dpright:b11,dpup:b8,leftshoulder:b4,lefttrigger:b6,rightshoulder:b5,righttrigger:b7,leftstick:b14,rightstick:b15,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,

#Gameforce Chi
19000000030000000300000002030000,gameforce_gamepad,leftstick:b14,rightx:a3,leftshoulder:b4,start:b9,lefty:a0,dpup:b10,righty:a2,a:b1,b:b0,back:b8,dpdown:b11,rightshoulder:b5,righttrigger:b7,rightstick:b15,dpright:b13,x:b2,guide:b16,leftx:a1,y:b3,dpleft:b12,lefttrigger:b6,platform:Linux,

#RG552
190000004b4800000111000000010000,retrogame_joypad,a:b1,b:b0,x:b2,y:b3,back:b8,start:b9,rightstick:b12,leftstick:b11,dpleft:b15,dpdown:b14,dpright:b16,dpup:b13,leftshoulder:b4,lefttrigger:b6,rightshoulder:b5,righttrigger:b7,leftx:a0,lefty:a1,rightx:a2,righty:a3,platform:Linux,
EOF
)

# Files and directories to be deleted
FILES_TO_DELETE=(
  "$PORTMASTER_DIR/autoinstall"
  "$PORTMASTER_DIR/batocera"
  "$PORTMASTER_DIR/knulli"
  "$PORTMASTER_DIR/muos"
  "$PORTMASTER_DIR/retrodeck"
  "$PORTMASTER_DIR/trimui"
  "$PORTMASTER_DIR/libgl_Batocera.txt"
  "$PORTMASTER_DIR/libgl_EmuELEC.txt"
  "$PORTMASTER_DIR/libgl_JELOS.txt"
  "$PORTMASTER_DIR/libgl_knulli.txt"
  "$PORTMASTER_DIR/libgl_muOS.txt"
  "$PORTMASTER_DIR/libgl_ROCKNIX.txt"
  "$PORTMASTER_DIR/mod_Batocera.txt"
  "$PORTMASTER_DIR/mod_EmuELEC.txt"
  "$PORTMASTER_DIR/mod_JELOS.txt"
  "$PORTMASTER_DIR/mod_knulli.txt"
  "$PORTMASTER_DIR/mod_muOS.txt"
  "$PORTMASTER_DIR/mod_ROCKNIX.txt"
  "$PORTMASTER_DIR/mod_TrimUI.txt"
)

# # Log file
# LOG_FILE="$SCRIPT_DIR/log_$(date '+%Y-%m-%d_%H-%M-%S').txt"
# echo "Execution log - $(date)" > "$LOG_FILE"

# # Redirect stdout and stderr to the log file
# exec > "$LOG_FILE" 2>&1

# Check if the PortMaster directory is in the same directory as the script
if [ ! -d "$PORTMASTER_DIR" ]; then
  echo "The PortMaster directory was not found. Exiting the script."
  exit 1
fi

# Ensure the destination directory exists
if [ ! -d "$DEST_DIR" ]; then
  echo "Destination directory $DEST_DIR does not exist. Creating..."
  mkdir -p "$DEST_DIR"
  if [ $? -ne 0 ]; then
    echo "Error creating the directory $DEST_DIR."
    exit 1
  fi
fi

# Check if backup is needed and if the PortMaster directory exists at the destination
if [ "$BACKUP_BEFORE_MODIFICATIONS" = true ]; then
  if [ -d "$PORTMASTER_DEST_DIR" ]; then
    echo "Creating a backup of the existing PortMaster directory..."
    BACKUP_DIR="$SCRIPT_DIR/PortMaster_Bkp_$(date '+%Y-%m-%d_%H-%M-%S')"
    cp -r "$PORTMASTER_DEST_DIR" "$BACKUP_DIR"
    if [ $? -eq 0 ]; then
      echo "Backup created successfully at $BACKUP_DIR"
    else
      echo "Error creating backup."
      exit 1
    fi
  else
    echo "No existing PortMaster directory to backup."
  fi
fi

# Overwrite control.txt, gamecontrollerdb.txt, and donottouch.txt with new content
echo "$CONTROL_CONTENT" > "$CONTROL_FILE"
echo "control.txt overwritten successfully."

echo "$GAMERCONTROLLERDB_CONTENT" > "$GAMECONTROLLERDB_FILE"
echo "gamecontrollerdb.txt overwritten successfully."

echo "$BACKUP_DONOTTOUCH_CONTENT" > "$DONOTTOUCH_FILE"
echo ".Backup/donottouch.txt overwritten successfully."

# Delete the specified files and directories
for file in "${FILES_TO_DELETE[@]}"; do
  if [ -e "$file" ]; then
    rm -rf "$file"
    echo "Deleted $file"
  fi
done

# Check if destination PortMaster directory already exists and delete it if necessary
if [ -d "$DEST_DIR/PortMaster" ]; then
  echo "Deleting existing /roms/ports/PortMaster directory..."
  rm -rf "$DEST_DIR/PortMaster"
  if [ $? -ne 0 ]; then
    echo "Error deleting existing /roms/ports/PortMaster."
    exit 1
  fi
fi

# Copy the PortMaster directory from the script's location to /roms/ports/ (handles cross-device)
echo "Copying the PortMaster directory to $DEST_DIR..."
cp -r "$PORTMASTER_DIR" "$DEST_DIR/"
if [ $? -eq 0 ]; then
  echo "PortMaster directory copied successfully!"
  # Optionally, delete the original PortMaster directory if it's no longer needed
  rm -rf "$PORTMASTER_DIR"
else
  echo "Error copying the PortMaster directory."
  exit 1
fi

# Handling mono file movement across devices
MONO_PATH="$SCRIPT_DIR/$MONO_FILE"
DEST_MONO_PATH="$DEST_DIR/PortMaster/libs/$MONO_FILE"

if [ -f "$MONO_PATH" ]; then
  echo "Copying mono file from $MONO_PATH to $DEST_MONO_PATH"
  cp "$MONO_PATH" "$DEST_MONO_PATH"
  if [ $? -eq 0 ]; then
    echo "Mono file copied successfully!"
    # Optionally, delete the original mono file after copying
    rm -f "$MONO_PATH"
  else
    echo "Error copying mono file."
    exit 1
  fi
else
  echo "Mono file not found in $SCRIPT_DIR."
fi

echo "Script finished successfully!"
