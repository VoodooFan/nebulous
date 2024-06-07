#!/bin/bash
# Author: VoodooFan (kfi@kyberraum-festung-iserlohn.de)
# Date:   2024-06-06

# variables
USER_STEAM="steam"
BASE_DIR="/srv"

# checking for root and display info
if [ $(whoami) = 'root' ]; then
  echo "Note: This script will create user '$USER_STEAM' in $BASE_DIR/$USER_STEAM and will also install Nebulous Dedicated Server for that user."
else
  echo "Error: This script must be run as root."
  exit 1
fi

# checking for distribution
DIST_ID=$(lsb_release --short --id)
if [ "$DIST_ID" = 'Debian' ]; then
  echo "Note: Found distribution Debian."
elif [ "$DIST_ID" = 'Ubuntu' ]; then
  echo "Note: Found distribution Ubuntu."
else
  echo "Error: No compatible distribution found. This script can only be run on the Debian or Ubuntu distribution.."
  exit 2
fi

# asking for okay
while true; do
  read -p "Do you want to install Steam and Nebulous Dedicated Server? (y/n) " yn
  case $yn in
    [yY] ) echo "Note: Starting..."; break;;
    [nN] ) echo "Note: The installation was aborted."; exit 0;;
  esac
done

# creating user $USER_STEAM
echo "Note: Creating user '$USER_STEAM'." &&\
useradd --create-home --base-dir "$BASE_DIR" --shell /bin/bash "$USER_STEAM" &&\
echo "Note: Please enter a new password for user '$USER_STEAM'." &&\
passwd "$USER_STEAM" &&\
{ echo "Note: User '$USER_STEAM' has been created."; } ||\
{ echo "Error: Unable to create user '$USER_STEAM'."; exit 3; }

# installing steamcmd
if [ "$DIST_ID" = 'Debian' ]; then
  echo "Note: apt-get update" &&\
  apt-get update &&\
  echo "Note: apt-get --yes install software-properties-common" &&\
  apt-get --yes install software-properties-common &&\
  echo "Note: dpkg --add-architecture i386" &&\
  dpkg --add-architecture i386 &&\
  echo "Note: apt-get update" &&\
  apt-get update &&\
  echo "Note: apt-get --yes install steamcmd sudo" &&\
  apt-get --yes install steamcmd sudo &&\
  { echo "Note: 'steamcmd' has been installed."; } ||\
  { echo "Error: Unable to install 'steamcmd'. Have you added 'non-free' components in '/etc/apt/sources.list'?"; exit 4; }
elif [ "$DIST_ID" = 'Ubuntu' ]; then
  echo "Note: add-apt-repository multiverse" &&\
  add-apt-repository multiverse &&\
  echo "Note: dpkg --add-architecture i386" &&\
  dpkg --add-architecture i386 &&\
  echo "Note: apt-get update" &&\
  apt-get update &&\
  echo "Note: apt-get --yes install steamcmd" &&\
  apt-get --yes install steamcmd &&\
  { echo "Note: 'steamcmd' has been installed."; } ||\
  { echo "Error: Unable to install 'steamcmd'."; exit 5; }
else
  echo "Error: Fatal script error, aborting..."
  exit 6
fi

# creating user files for user $USER_STEAM
cd "$BASE_DIR/$USER_STEAM" &&\
mkdir --parents bin &&\
chown "$USER_STEAM": bin &&\
cd bin &&\
echo "#!/bin/sh" > update-nds &&\
echo "systemctl --quiet is-active nds.service && echo \"Error: nds.service must not be active.\" || steamcmd +login anonymous +app_update 2353090 validate +quit" >> update-nds &&\
chmod +x update-nds &&\
chown "$USER_STEAM": update-nds &&\
echo "#!/bin/sh" > delete-nds-mods &&\
echo "systemctl --quiet is-active nds.service && echo \"Error: nds.service must not be active.\" || { echo \"Do you want to delete all mods for Nebulous Dedicated Server? (y/n)\"; rm -Irv $BASE_DIR/$USER_STEAM/nds/steamapps/workshop/content/887570 $BASE_DIR/$USER_STEAM/nds/steamapps/workshop/appworkshop_887570.acf; }" >> delete-nds-mods &&\
chmod +x delete-nds-mods &&\
chown "$USER_STEAM": delete-nds-mods &&\
{ echo "Note: User files for user '$USER_STEAM' have been created."; } ||\
{ echo "Error: Unable to create user files for user '$USER_STEAM'."; exit 7; }

# installing Nebulous Dedicated Server for user $USER_STEAM
echo "Note: Installing Nebulous Dedicated Server for user '$USER_STEAM'."
sudo -iu "$USER_STEAM" "$BASE_DIR/$USER_STEAM/bin/update-nds" &&\
cd "$BASE_DIR/$USER_STEAM" &&\
ln --force --symbolic ".steam/root/steamapps/common/NEBULOUS Dedicated Server" nds &&\
chown --no-dereference "$USER_STEAM": nds &&\
cp nds/DedicatedServerConfig.xml nds.conf &&\
chmod -x nds.conf &&\
chown "$USER_STEAM": nds.conf &&\
mkdir --parents .steam/sdk64 &&\
chown "$USER_STEAM": .steam/sdk64 &&\
cd .steam/sdk64 &&\
ln --force --symbolic ../root/steamcmd/linux64/steamclient.so &&\
chown --no-dereference "$USER_STEAM": steamclient.so &&\
{ echo "Note: Nebulous Dedicated Server has been installed for user '$USER_STEAM'."; } ||\
{ echo "Error: Unable to install Nebulous Dedicated Server for user '$USER_STEAM'."; exit 8; }

# creating daemon nds.service for Nebulous Dedicated Server
mkdir --parents /usr/local/lib/systemd/system &&\
cd /usr/local/lib/systemd/system &&\
echo "[Unit]" > nds.service &&\
echo "Description=Nebulous Dedicated Server" >> nds.service &&\
echo "After=network.target" >> nds.service &&\
echo "" >> nds.service &&\
echo "[Install]" >> nds.service &&\
echo "WantedBy=multi-user.target" >> nds.service &&\
echo "" >> nds.service &&\
echo "[Service]" >> nds.service &&\
echo "Type=simple" >> nds.service &&\
echo "ExecStart=$BASE_DIR/$USER_STEAM/nds/NebulousDedicatedServer -nographics -batchmode -logFile $BASE_DIR/$USER_STEAM/nds.log -serverConfig $BASE_DIR/$USER_STEAM/nds.conf" >> nds.service &&\
echo "WorkingDirectory=$BASE_DIR/$USER_STEAM/nds/" >> nds.service &&\
echo "User=$USER_STEAM" >> nds.service &&\
echo "Group=$USER_STEAM" >> nds.service &&\
echo "Restart=always" >> nds.service &&\
echo "RestartSec=30" >> nds.service &&\
{ echo "Note: Daemon nds.service has been created."; } ||\
{ echo "Error: Unable to create daemon nds.service."; exit 9; }

# editing the server config file nds.conf
while true; do
  read -p "Do you want to edit the server config file $BASE_DIR/$USER_STEAM/nds.conf now? (y/n) " yn
  case $yn in
    [yY] ) echo "Note: editor $BASE_DIR/$USER_STEAM/nds.conf"; editor "$BASE_DIR/$USER_STEAM/nds.conf"; break;;
    [nN] ) echo "Note: Using default settings."; break;;
  esac
done

# enabling nds.service
while true; do
  read -p "Do you want to set Nebulous Dedicated Server to autostart? (y/n) " yn
  case $yn in
    [yY] ) echo "Enabling Nebulous Dedicated Server for autostart. Note: systemctl enable nds.service"; systemctl enable nds.service; break;;
    [nN] ) echo "Note: You may use command 'systemctl enable nds.service' to set Nebulous Dedicated Server to autostart."; break;;
  esac
done

# starting nds.service
while true; do
  read -p "Do you want to start Nebulous Dedicated Server now? (y/n) " yn
  case $yn in
    [yY] ) echo "Starting Nebulous Dedicated Server now. Note: systemctl start nds.service"; systemctl start nds; break;;
    [nN] ) echo "Note: You may use command 'systemctl start nds.service' to start Nebulous Dedicated Server."; break;;
  esac
done

# last words
echo "Info: If you use a firewall, you need to open TCP port 7777 (default for <GamePort> in nds.conf) for inbound and outbound traffic and also open UDP port 27016 (default for <QueryPort> in nds.conf) for inbound traffic."
echo "Note: It seems that Nebulous Dedicated Server has been succesfully installed. Thank you for setting up a dedicated server and fly safe!"
exit 0
