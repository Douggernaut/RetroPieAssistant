#!/bin/bash

EXT_CONFIG_FILE="/etc/emulationstation/es_systems.cfg"
EMU_CONFIG_FILE="/opt/retropie/configs/amiga/emulators.cfg"

# make backup before changes, don't overwrite existing backup
if [[ ! -f $EXT_CONFIG_FILE.bak ]]; then
  sudo cp -n $EXT_CONFIG_FILE $EXT_CONFIG_FILE.bak
fi
# add .uae to accepted amiga extensions if not present
sudo sed -i '/[A|a]miga/{n;/<extension>/{/.uae/!{s/<\/extension>/ .uae<\/extension>/}}}' $EXT_CONFIG_FILE

# make backup before changes, don't overwrite existing backup
if [[ ! -f $EMU_CONFIG_FILE.bak ]]; then
  cp -n $EMU_CONFIG_FILE $EMU_CONFIG_FILE.bak
fi
# replace uae4arm line with the following line
new_line='uae4arm="pushd /opt/retropie/emulators/uae4arm/; ./uae4arm -f %ROM%"'
sed -i '/^uae4arm/!b;c'"${new_line}"'' $EMU_CONFIG_FILE
