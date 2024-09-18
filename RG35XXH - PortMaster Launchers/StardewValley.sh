#!/bin/bash
# PORTMASTER: stardewvalley.zip, StardewValley.sh

export HOME=/root
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

echo $controlfolder

SHDIR=$(dirname "$(readlink -f "$0")")

source $controlfolder/control.txt
source $controlfolder/device_info.txt
source $controlfolder/tasksetter

get_controls

#gamedir="$directory/ports/stardewvalley"
gamedir="$SHDIR/stardewvalley"

echo "$gamedir"

cd "$gamedir/"

echo "--directory=$directory---,HOTKEY=$HOTKEY--"

# Grab text output...
$ESUDO chmod 666 /dev/tty0
printf "\033c" > /dev/tty0
echo "Loading... Please Wait." > /dev/tty0

# Setup mono
monodir="$HOME/mono"
monofile="$controlfolder/libs/mono-6.12.0.122-aarch64.squashfs"
$ESUDO mkdir -p "$monodir"
$ESUDO umount "$monofile" || true
$ESUDO mount "$monofile" "$monodir"

# Setup savedir
$ESUDO mkdir -p $HOME/.config
$ESUDO rm -rf $HOME/.config/StardewValley
ln -sfv "$gamedir/savedata" $HOME/.config/StardewValley

# Remove all the dependencies in favour of system libs - e.g. the included 
# newer version of MonoGame with fixes for SDL2
rm -f System*.dll MonoGame*.dll mscorlib.dll

# Copy the fixed monogame config
cp dlls/MonoGame.Framework.dll.config .

# Setup path and other environment variables
export MONOGAME_PATCH="$gamedir/dlls/StardewPatches.dll"
export MONO_PATH="$gamedir/dlls":"$gamedir"
export PATH="$monodir/bin":"$PATH"
export LD_LIBRARY_PATH="$gamedir/libs:$LD_LIBRARY_PATH"
#export LIBGL_ES=2
#export LIBGL_GL=21
#export LIBGL_FB=4
#export SDL_VIDEO_GL_DRIVER="$gamedir/libs/libGL.so.1"
#export SDL_VIDEO_EGL_DRIVER="$gamedir/libs/libEGL.so.1"

# Delete older GL4ES installs...
rm -f $gamedir/libs/libGL.so.1 $gamedir/libs/libEGL.so.1

# Request libGL from Portmaster
if [ -f "${controlfolder}/libgl_${CFW_NAME}.txt" ]; then
  source "${controlfolder}/libgl_${CFW_NAME}.txt"
else
  source "${controlfolder}/libgl_default.txt"
fi

if [[ "$LIBGL_ES" != "" ]]; then
	export SDL_VIDEO_GL_DRIVER="${gamedir}/gl4es/libGL.so.1"
	export SDL_VIDEO_EGL_DRIVER="${gamedir}/gl4es/libEGL.so.1"
fi

# Jump into the gamedata dir now
cd "$gamedir/gamedata"

# Fix for the Linux builds, use mono-provided libraries instead.
# Exception for the System.Data.* assemblies, since Stardew needs
# xxHash types we would otherwise not provide.
mv System.Data*.dll "$gamedir/dlls"
rm -f MonoGame.Framework.* System*.dll

# Check if it's the Windows or Linux version
if [[ -f "Stardew Valley.exe" ]]; then
	gameassembly="Stardew Valley.exe"

	# Copy the Windows Stardew Valley WinAPI workarounds
	cp "${gamedir}/dlls/Stardew Valley.exe.config" "${gamedir}/gamedata/Stardew Valley.exe.config"
else
	gameassembly="StardewValley.exe"
fi

$GPTOKEYB "mono" &
$TASKSET mono ../SVLoader.exe "${gameassembly}" 2>&1 | tee "${gamedir}/log.txt"
$ESUDO kill -9 $(pidof gptokeyb)
$ESUDO systemctl restart oga_events &
$ESUDO umount "$monodir"

# Disable console
printf "\033c" >> /dev/tty1
