#!/bin/bash

# Colors
GREEN='\e[1;32m'
RED='\e[1;31m'
BLUE='\e[1;34m'
PURPLE='\e[1;35m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
GRAY='\e[1;37m'
DARK_GRAY='\e[1;30m'
WHITE='\e[1;37m'
COLOR_OFF='\e[0m'

VERBOSE=0
ANSIBLE_VERSION="2.4.0.0"
ORIGINAL_PWD=$PWD
OPTS="vhi:r:c:"

function output_running {
  printf "${PURPLE}--> ${COLOR_OFF}$1\n" 1>&2
}

function output_success {
  printf "${GREEN}++ OK: ${COLOR_OFF}$1\n" 1>&2
}

function output_skip {
  printf "${GREEN}-- SKIPPED: ${COLOR_OFF}$1\n" 1>&2
}

function output_header {
  printf "\n${WHITE}[[ ${COLOR_OFF}$1${WHITE} ]]${COLOR_OFF}\n\n" 1>&2
}

function output_debug {
  if [ "$VERBOSE" = 1 ] ; then
    printf "${DARK_GRAY}| DEBUG: ${COLOR_OFF}$1\n" 1>&2
  fi
}

function output_warning {
  printf "${YELLOW}! WARNING: ${COLOR_OFF}$1\n" 1>&2
}

function error {
  printf "\n${RED}!! ERROR: ${COLOR_OFF}$1\n\nExiting.\n" 1>&2
  exit 1
}

function banner {
printf "${GREEN}                       ____   _____   _                 _       _                   ${COLOR_OFF}\n"
printf "${GREEN}                      / __ \ / ____| | |               | |     | |                  ${COLOR_OFF}\n"
printf "${GREEN} _ __ ___   __ _  ___| |  | | (___   | |__   ___   ___ | |_ ___| |_ _ __ __ _ _ __  ${COLOR_OFF}\n"
printf "${GREEN}| \'_ \` _ \ / _\` |/ __| |  | |\___ \  | '_ \ / _ \ / _ \| __/ __| __| '__/ _\` | \'_ \ ${COLOR_OFF}\n"
printf "${GREEN}| | | | | | (_| | (__| |__| |____) | | |_) | (_) | (_) | |_\__ \ |_| | | (_| | |_) |${COLOR_OFF}\n"
printf "${GREEN}|_| |_| |_|\__,_|\___|\____/|_____/  |_.__/ \___/ \___/ \__|___/\__|_|  \__,_| .__/ ${COLOR_OFF}\n"
printf "${GREEN}                                                                             | |    ${COLOR_OFF}\n"
printf "${GREEN}                                           https://feffi.org/macos-bootstrap |_|    ${COLOR_OFF}\n\n"
printf "${DARK_GRAY}Thanks:                                                                         ${COLOR_OFF}\n"
printf "${BLUE}http://superlumic.com                           https://github.com/boxcutter/osx     ${COLOR_OFF}\n"
printf "${BLUE}https://github.com/jeremyltn                    http://patorjk.com/software/taag     ${COLOR_OFF}\n"
printf "${BLUE}https://gist.github.com/pkuczynski/8665367      https://github.com/geerlingguy       ${COLOR_OFF}\n\n"
}

# Check whether a command exists - returns 0 if it does, 1 if it does not
function exists {
  output_debug "Checking if the '$1' command is present."
  if command -v $1 >/dev/null 2>&1
  then
  output_debug "Command '$1' is present."
  return 0
  else
  output_debug "Command '$1' is not present."
  return 1
  fi
}

function fail_on_error {
  if ! $1
  then error "Command '$1' returned a non zero exit code."
  fi
}

function warn_on_error {
  if ! $1
  then output_warning "Command '$1' returned a non zero exit code."
  fi
}

usage()
{
cat << EOF

usage: $0 options

OPTIONS:
   -h      Show this message.
   -v      Enable verbose output.
EOF
}

###################################################################################
# Install: Installing Command Line Tools                                          #
#                                                                                 #
# credits: https://github.com/boxcutter/osx/blob/master/script/xcode-cli-tools.sh #
###################################################################################

function install_clt {
  output_header "Installing Command Line Tools"

  if [[ -f "/Library/Developer/CommandLineTools/usr/bin/clang" ]]; then
    output_skip "Command Line Tools already installed."
    return 0
  fi

  # Get and install Xcode CLI tools
  OSX_VERS=$(sw_vers -productVersion | awk -F "." '{print $2}')
  output_running "Detected macOS $(sw_vers -productVersion)"

  # on 10.9+, we can leverage SUS to get the latest CLI tools
  if [ "$OSX_VERS" -ge 9 ]; then
    # create the placeholder file that's checked by CLI updates' .dist code
    # in Apple's SUS catalog
    touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
    # find the CLI Tools update
    PROD=$(softwareupdate -l | grep "\*.*Command Line" | head -n 1 | awk -F"*" '{print $2}' | sed -e 's/^ *//' | tr -d '\n')
    output_running "Installing '$PROD'"

    # install it
    softwareupdate -i "$PROD" --verbose
    rm /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress

  # on 10.7/10.8, we instead download from public download URLs, which can be found in
  # the dvtdownloadableindex:
  # https://devimages.apple.com.edgekey.net/downloads/xcode/simulators/index-3905972D-B609-49CE-8D06-51ADC78E07BC.dvtdownloadableindex
  else
    [ "$OSX_VERS" -eq 7 ] && DMGURL=http://devimages.apple.com.edgekey.net/downloads/xcode/command_line_tools_for_xcode_os_x_lion_april_2013.dmg
    [ "$OSX_VERS" -eq 7 ] && ALLOW_UNTRUSTED=-allowUntrusted
    [ "$OSX_VERS" -eq 8 ] && DMGURL=http://devimages.apple.com.edgekey.net/downloads/xcode/command_line_tools_for_osx_mountain_lion_april_2014.dmg

    TOOLS=clitools.dmg
    output_running "Downloading '$DMGURL'"
    curl "$DMGURL" -o "$TOOLS"
    output_running "Installing '$TOOLS'"
    TMPMOUNT=`/usr/bin/mktemp -d /tmp/clitools.XXXX`
    hdiutil attach "$TOOLS" -mountpoint "$TMPMOUNT"
    installer $ALLOW_UNTRUSTED -pkg "$(find $TMPMOUNT -name '*.mpkg')" -target /
    hdiutil detach "$TMPMOUNT"
    rm -rf "$TMPMOUNT"
    rm "$TOOLS"
  fi

  if [[ ! -f "/Library/Developer/CommandLineTools/usr/bin/clang" ]]; then
    error "Command Line Tools installation failed. Exiting."
  else
    output_success "Command Line Tools successfully installed."
  fi
}

###################################################################################
# Install: pip (via easy_install)                                                 #
###################################################################################

function install_pip {
  output_header "Installing pip"
  if ! exists pip; then
    fail_on_error "sudo easy_install --quiet pip"
    if ! exists pip; then
      error "Error installing pip."
    else
      output_success "pip successfully installed."
    fi
  else
    output_skip "pip already installed."
  fi
}

###################################################################################
# Install: ansible (via pip)                                                      #
###################################################################################

function install_ansible {
  output_header "Installing Ansible"
  if ! exists ansible; then
    fail_on_error "sudo pip install -I ansible==$ANSIBLE_VERSION"
    if ! exists ansible; then
      error "Error installing Ansible."
    else
      output_success "Ansible successfully installed."
    fi
  else
    output_skip "Ansible already installed."
  fi
}

###################################################################################
# Show banner                                                                     #
###################################################################################

banner

###################################################################################
# Check cli options (not yet implemented)                                         #
###################################################################################

while getopts "$OPTS" OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    v)
      VERBOSE=1
      ;;
    ?)
      usage
      exit
      ;;
  esac
done

shell="$1"
if [ -z "$shell" ]; then
  shell="$(basename "$SHELL")"
fi

if [ "$VERBOSE" = 1 ] ; then
  output_debug "Detected verbose (-v) flag."
fi

###################################################################################
# Check privilege escalation                                                      #
###################################################################################

#output_debug "Checking if we need to ask for a sudo password"
#sudo -v
#output_debug "Keep-alive: update existing sudo time stamp until we are finished"
#while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

###################################################################################
# Install neccessary toolchain                                                    #
###################################################################################

install_clt
install_pip
install_ansible

###################################################################################
# Bootstrap                                                                       #
###################################################################################

#sudo -k

output_header "Bootstrapping via ansible"
output_running "Installing requirements..."
$(which ansible-galaxy) install -r requirements.yml -p roles
#$(which ansible-galaxy) install -r requirements.yml -p roles --ignore-errors
output_running "Bootstrapping..."
output_running "Using config from: '$1'"
$(which ansible-playbook) -i "inventory" bootstrap.yml -K --connection=local --extra-vars cli_path=$1

###################################################################################
# Kill all affected applications                                                  #
###################################################################################

output_header "Kill all affected applications..."
for app in "Activity Monitor" "Address Book" "Calendar" "Contacts" "cfprefsd" \
  "Dock" "Finder" "Mail" "Messages" "Safari" "SizeUp" "SystemUIServer" \
  "Transmission" "Twitter" "iCal"; do
  output_running "$app"
  killall "${app}" > /dev/null 2>&1
done

###################################################################################

output_success "Done. Note that some of these changes require a logout/restart to take effect."
