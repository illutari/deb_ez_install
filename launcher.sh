#!/bin/bash

# Define color codes for error messages
GR='\033[1;32m' # Green
ORA='\033[1;33m' # Orange
YL='\033[1;33m' # Yellow
RED='\033[1;31m' # Red
NC='\033[0m'  # No Color

# Set a default question
default_question="Do you want to proceed?"
question=$default_question
invalid_response="${RED}Invalid response. Please enter Y/y or N/n.${NC}"

# Function to trim leading and trailing whitespace
trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"   # Remove leading whitespace
    var="${var%"${var##*[![:space:]]}"}"   # Remove trailing whitespace
    echo "$var" | tr '[:upper:]' '[:lower:]'
}

parse_flags() {
    # Perform actions for command-line flags
    while getopts ":i:u" opt; do
        case $opt in
            i)
                advanced_installer
                exit 0;
                ;;
            u)
                download_updates
                list_updates
                exit 0;
                ;;
            \?)
                echo -e "${RED}Invalid option: -$opt${NC}" >&2
                exit 1
                ;;
            :)
                echo -e "${RED}Option -$OPTARG requires an argument.${NC}" >&2
                exit 1
                ;;
        esac
    done

    # Shift past the processed options
    shift $((OPTIND - 1))

    # Check for unexpected arguments
    if [ $# -gt 0 ]; then
        echo "Error: Unexpected arguments: $*" >&2
        exit 1
    fi
}

download_updates() {
    echo -e "${ORA}Checking for updates...${NC}"
    if sudo apt update >/dev/null 2>&1; then
        echo -e "${GR}Checking for updates: Complete.${NC}"
    else
        echo -e "${RED}Error checking for updates.{$NC}" >&2
    fi
}

list_updates() {
    # List package upgrades and store the output
    output=$(apt list --upgradable 2>/dev/null)
    status=$?

    # If no packages to upgrade, exit
    if [ $status -ne 0 ]; then
        echo -e "${RED}Error running apt list --upgradable:${NC}"
        echo "$output"
        exit 1
    # If there are packages to be upgraded
    elif [ "$output" != "Listing..." ]; then
        echo -e "${ORA}Listing available package upgrades:${NC}"
        echo "${output}"
        echo -e "${ORA}Upgrade these packages?${NC}"
        while true; do
            read -p "(y/n): " response
            if [[ "$response" =~ ^[Yy](es)?$ ]]; then
                sudo apt upgrade -y
                break
            elif [[ "$response" =~ ^[Nn](o)?$ ]]; then
                echo -e "${RED}Cancelling upgrades.${NC}"
                break
            else
                echo -e "$invalid_response"
            fi
        done
    else
        echo -e "${GR}No packages to upgrade.${NC}"
    fi
}

backup_selection() {
    echo -e "${YL}Select an option:\n"
    echo -e "1: List Backups"
    echo -e "2: Perform a Backup"
    echo -e "3: Remove a Backup"
    echo -e "4: Exit${NC}"
    read -p "Input: " input_selection

    # Check to see if package is installed
    if dpkg-query -W timeshift >/dev/null 2>&1; then
        case "$input_selection" in
            # List Backups
            1)
                echo -e "${YL}Listing backups:${NC}"
                sudo timeshift --list-snapshots
                ;;
            # Perform a Backup
            2)
                ;;
            # Remove a Backup
            3)
                echo -e "${RED}Backup is not yet available.${NC}"
                ;;
            4)
                exit
                ;;
            exit)
                exit
                ;;
            quit)
                exit
                ;;
            # Error
            *)
                echo -e "${RED}Unknown option: $input_selection${NC}"
                backup_selection
                ;;
        esac
    else
        echo -e "${RED}ERROR: Failed dependencies. Use the installer to install timeshift first.${NC}"
    fi




    
}

# Install packages using the apt package manager
install_apt_pkg() {
    local install_pack=$1
    local pack_name=$2

    if [ -z "$pack_name" ]; then
        pack_name=$install_pack
    fi
    # Check to see if package is installed
    if dpkg-query -W $install_pack >/dev/null 2>&1; then
        echo -e "${GR}${pack_name} is already installed!${NC}"
    else # Install package
        echo -e "${ORA}Installing ${pack_name}...${NC}"
        if sudo apt install -y $install_pack >/dev/null 2>&1; then
            echo -e "${GR}Successfully installed ${pack_name}.${NC}"
        else
            echo -e "${RED}An error occurred trying to install ${pack_name}...${NC}" >&2
        fi
    fi
}

# Install packages using the snap package manager
install_snap_pkg() {
    local install_pack=$1
    local pack_name=$2

    if [ -z "$pack_name" ]; then
        pack_name=$install_pack
    fi
    # Check to see if package is installed
    if snap list $install_pack >/dev/null 2>&1; then
        echo -e "${GR}${pack_name} is already installed!${NC}"
    else # Install package
        echo -e "${ORA}Installing ${pack_name}...${NC}"
        if sudo snap install $install_pack >/dev/null 2>&1; then
            echo -e "${GR}Successfully installed ${pack_name}.${NC}"
        else
            echo -e "${RED}An error occurred trying to install ${pack_name}...${NC}" >&2
        fi
    fi
}

start_selection() {
    echo -e "${YL}Select an option:\n\n"
    echo -e "1: Install"
    echo -e "2: Update"
    echo -e "3: Backup"
    echo -e "4: Remove"
    echo -e "5: Exit${NC}"
    read -p "Input: " input_selection

    case "$input_selection" in
        # Install
        1)
            echo -e "${YL}Would you like to use the advanced installer?${NC}"
            # Loop until a valid response is received
            while true; do
                read -p " (y/n): " response
                if [[ "$response" =~ ^[Yy](es)?$ ]]; then
                    advanced_installer
                    break
                elif [[ "$response" =~ ^[Nn](o)?$ ]]; then
                    echo "The basic installer is not yet ready."
                    break
                elif [[ "$response" =~ ^[Ee](xit)?$ ]]; then
                    start_selection
                    break
                else
                    echo -e "$invalid_response"
                fi
            done
            ;;
        # Update
        2)
            download_updates
            list_updates
            start_selection
            ;;
        # Backup
        3)
            backup_selection
            ;;
        4)
        # Remove
            echo -e "${RED}Remover is not yet available.${NC}"
            ;;
        # Exit
        5) 
            exit
            ;;
        exit)
            exit
            ;;
        quit)
            exit
            ;;
        # Error
        *)
            echo -e "${RED}Unknown option: $input_selection${NC}"
            ;;
    esac

}

advanced_installer() {
    # Prompt user for a comma-separated list of options
    echo -e "${YL}Enter a list of programs you'd like to install from the following options... (CTRL + Click links to open in default browser)"
    echo -e "-------------------------------------------"
    echo -e "| brave            | https://brave.com/"
    echo -e "| btop             | https://github.com/aristocratos/btop"
    echo -e "| code             | https://code.visualstudio.com/"
    echo -e "| curl             | https://curl.se/"
    echo -e "| fastfetch        | https://github.com/fastfetch-cli/fastfetch"
    echo -e "| mullvad          | https://mullvad.net/"
    echo -e "| plex             | https://www.plex.tv/media-server-downloads/?cat=plex+desktop&plat=linux#plex-app"
    echo -e "| proton           | https://protonvpn.com/"
    echo -e "| qbittorrent      | https://www.qbittorrent.org/"
    echo -e "| spotify          | https://spotify.com/"
    echo -e "| timeshift        | https://teejee2008.github.io/timeshift/"
    echo -e "| veracrypt        | https://www.veracrypt.fr/"
    echo -e "| vlc              | https://www.videolan.org/vlc/"
    echo -e "-------------------------------------------"
    echo -e "Use comma, space, or comma-space separation"
    echo -e "(ex: brave,spotify,mullvad)"
    echo -e "(ex: brave spotify mullvad)"
    echo -e "(ex: brave, spotify, mullvad)${NC}"
    read -p "Input: " input_string

    # Replace commas with spaces and split the string into an array
    IFS=' ' read -a options <<< $(echo "$input_string" | tr ',' ' ')

    # Track whether or not we need to run package updates for new keys
    local key_used=false

    # Download keys for software that like to feel special
    for option in "${options[@]}"; do
        # Trim whitespace and convert to lowercase for consistent matching
        option=$(trim "$option")
        option=$(echo "$option" | tr '[:upper:]' '[:lower:]')

        # Case statement to handle specific options
        case "$option" in
            brave)
                if [ ! -e "/etc/apt/sources.list.d/brave-browser-release.list" ]; then
                    echo -e "${ORA}Downloading key: Brave.${NC}"
                    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
                    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
                    key_used=true
                fi
                ;;
            mullvad)
                if [ ! -e "/etc/apt/sources.list.d/mullvad.list" ]; then
                    echo -e "${ORA}Downloading key: Mullvad${NC}"
                    sudo curl -fsSLo /usr/share/keyrings/mullvad-keyring.asc https://repository.mullvad.net/deb/mullvad-keyring.asc
                    echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/mullvad.list
                    key_used=true
                fi
                ;;
            proton)
                if [ ! -e "/etc/apt/sources.list.d/protonvpn-stable.list.distUpgrade" ]; then
                    echo -e "${ORA}Downloading key: Proton${NC}"
                    wget https://repo.protonvpn.com/debian/dists/stable/main/binary-all/protonvpn-stable-release_1.0.8_all.deb
                    sudo dpkg -i ./protonvpn-stable-release_1.0.8_all.deb
                    key_used=true
                fi
                ;;
            spotify)
                if [ ! -e "/etc/apt/sources.list.d/spotify.list" ]; then
                    echo -e "${ORA}Downloading key: Spotify${NC}"
                    curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
                    echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
                    key_used=true
                fi
                ;;
            *)
                ;;
        esac
    done

    # Download package updates if we added a new key
    if [ "$key_used" = true ]; then
        download_updates
    fi

    # Perform installs/checks
    for option in "${options[@]}"; do
        # Trim whitespace and convert to lowercase for consistent matching
        option=$(trim "$option")

        # Case statement to handle specific options
        case "$option" in
            brave)
                install_apt_pkg "brave-browser" "brave"
                ;;
            btop)
                install_apt_pkg "btop"
                ;;
            code)
                install_apk_pkg "code"

                # Associate VS Code with folders (for right click open-with VS Code functionality)
                if [ -f "$HOME/.config/mimeapps.list" ]; then
                    # Append "code.desktop" to the line containing "inode/directory=" in ~/.config/mimeapps.list
                    sed -i '/inode\/directory=/ s/$/code.desktop/' "$HOME/.config/mimeapps.list"
                fi
                ;;
            curl)
                install_apt_pkg "curl"
                ;;
            fastfetch)
                install_apt_pkg "fastfetch"
                ;;
            mullvad)
                install_apt_pkg "mullvad-vpn" "mullvad"
                ;;
            plex)
                install_snap_pkg "plex-desktop" "plex"
                ;;
            proton)
                install_apt_pkg "proton-vpn-gnome-desktop" "proton"

                # Ask for support tray package installs
                echo -e "${YL}Would you like to install the packages required for support tray functionality?${NC}"
                while true; do
                    read -p " (y/n): " response
                    if [[ "$response" =~ ^[Yy](es)?$ ]]; then
                        # Package requirements for desktop support tray functionality
                        pre_req_pkgs=("libayatana-appindicator3-1" "gir1.2-ayatanaappindicator3-0.1" "gnome-shell-extension-appindicator")
                        echo -e "${ORA}Checking for proton desktop tray package requirements...${NC}"
                        for pkg in "${pre_req_pkgs[@]}"; do
                            install_apt_pkg "$pkg"
                            done
                        break
                    elif [[ "$response" =~ ^[Nn](o)?$ ]]; then
                        break
                    elif [[ "$response" =~ ^[Ee](xit)?$ ]]; then
                        start_selection
                        break
                    else
                        echo -e "$invalid_response"
                    fi
                done
                ;;
            qbittorrent)
                install_apt_pkg "qbittorrent"
                ;;
            spotify)
                install_apt_pkg "spotify-client" "spotify"
                ;;
            steam)
                install_apt_pkg "steam"
                ;;
            timeshift)
                install_apt_pkg "timeshift"
                ;;
            veracrypt)
                install_apt_pkg "veracrypt"
                ;;
            vlc)
                install_apt_pkg "vlc"
                ;;
            *)
                echo -e "${RED}Unknown option: $option${NC}"
                ;;
        esac
    done
}

###########################
### BEGINNING OF SCRIPT ###
###########################

# Clear screen
clear

# Call the function to parse flags
parse_flags "$@"

start_selection
