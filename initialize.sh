#!/bin/bash

# Note: This script should run by root user himself, or with sudo permission.
# This is only used for setting up server at the very beginning.

# ==============================================================================
# PRESET VARIABLES
# ==============================================================================

web_base="http://192.168.32.210"
ansible_public_key=
default_dns="202.104.245.186 202.192.159.2"
default_domain=stu.edu.cn
default_workgroup=stunic

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# arguments: description, default value
# example: confirm_variable "IP address" $current_ip
confirm_variable()
{
  while true; do
    read -p "Please specify your $1 [$2]: " return_confirmed
    if [[ -z $return_confirmed ]]; then
      return_confirmed=$2
    fi
    if [[ ! -z $return_confirmed ]]; then
      break
    fi
    echo "Please specify a non-empty falue for $1."
  done
}

# arguments: case, string (0 for lowercase, 1 for uppercase)
# example: convert_case 0 $string
convert_case()
{
  if [ $1 = 1 ] || [ $1 = "lo" ]; then
    echo $(echo $2 | tr '[A-Z]' '[a-z]')
  else
    echo $(echo $2 | tr '[a-z]' '[A-Z]')
  fi
}

# ---------------------------------------------------------
# STEP 0:
# Understand the OS 

echo "Welcome to Steve\'s VM Setup Script."
echo "We are detecting your operating system."

. /etc/os-release

os_distro=$ID
os_distro_like=$ID_LIKE
os_version=$VERSION_ID
os_arch=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
os_pretty_name=$PRETTY_NAME

case $os_distro in
  amzn ) 
    echo "You are using $os_pretty_name. Sorry we don't support this OS."
    ;;
  centos ) 
    echo "You are using CentOS."
    if [ $os_version > 6 ]; then
      echo "Welcome to the modern world"
    fi
    ;;
  ubuntu )
    echo "You are using $os_pretty_name. Sorry we don't support this OS."
    ;;
  rhel )
    echo "You are using $os_pretty_name. Sorry we don't support this OS."
    ;;
  debian )
    echo "You are using $os_pretty_name. Sorry we don't support this OS at the moment."
    ;;
  * )
    echo "Sorry your OS is not recognized nor supported."
    echo "OS Pretty Name: $os_pretty_name"
    echo "Please contact git@iyyang.com for more information."
    ;;
esac

# ---------------------------------------------------------
# STEP 1:
# Set up IP address and hostname

read -p "This script requires accessing machine via hard interfaces, e.g. 
keyboard or VM console. Please make sure you are not using SSH." yn
case $yn in
    #[Yy]* ) make install; break;;
    [Nn]* ) exit;;
    * ) ;; #echo "Please answer yes or no.";;
esac

net_conn_name=stunic
net_dns4=$default_dns
net_network_device=
net_ip4=
net_gw4=
net_workgroup=$default_workgroup
net_feature=server
net_domain=$default_domain
net_hostname=
net_confirmed=False

if [ $os_distro == 'centos' ] && [ $os_version == 7 ]; then
  net_network_device=$(nmcli dev status | grep ethernet | awk '{ print $1}')
  if [ -z $net_network_device ]; then
    echo "Ethernet device not found. Please check your system and run the script again."
    exit
  fi
  net_ip4=$(ip addr | grep $net_network_device | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
fi

while true; do
  # net_ip4
  echo
  rx='([1-9]?[0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])'
  while true; do
    confirm_variable "IP address" $net_ip4
    target_ip4=$return_confirmed

    if [[ $target_ip4 =~ ^$rx\.$rx\.$rx\.$rx$ ]]; then
      net_ip4=$target_ip4
      break
    else
      echo "Please enter a valid IP address."
    fi
  done

  # net_gw4
  echo
  net_gw4=$(echo $net_ip4 | sed -r 's/([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)([0-9]{1,3})/\1254/')
  confirm_variable "Gateway" $net_gw4
  net_gw4=$return_confirmed

  # net_workgroup
  echo
  confirm_variable "Workgroup" $net_workgroup
  net_workgroup=$return_confirmed

  # net_feature
  echo
  confirm_variable "feature of the machine" $net_feature
  net_feature=$return_confirmed

  # net_hostname
  echo
  net_hostname=$(convert_case lo $net_workgroup)-$(convert_case lo $net_feature)
  net_hostname=$net_hostname-$(echo $net_ip4 | sed -r 's/(\.)/-/g')

  # network configuration list
  echo
  echo "Your network configuration is listed below:"
  echo "Ethernet Device: $net_network_device"
  echo "IP Address:      $net_ip4"
  echo "Gateway:         $net_gw4"
  echo "DNS:             $net_dns4"
  echo "Workgroup:       $net_workgroup"
  echo "Feature:         $net_feature"
  echo "Domain:          $net_domain"
  echo "Hostmane (generated): $net_hostname"

  # confirm information
  net_options[0]="Yes, please set up my network connection."
  net_options[1]="No, I will need to revise."
  echo "Are those information correct?"
  select net_selection in "${net_options[@]}" "Quit setup." ; do
    case "$REPLY" in
      1 ) break 2;;
      2 ) break;;
      3 ) echo "Goodbye!"; exit;;
      * ) echo "Invalid option. Try another one."; continue;;
    esac
  done
done

# set up IP iddress
nmcli con add type ethernet con-name $net_conn_name ifname $net_network_device ip4 $net_ip4/24 gw4 $net_gw4
nmcli con mod $net_conn_name ipv4.dns $net_dns4

# set up hostname
hostnamectl set-hostname $net_hostname


# ---------------------------------------------------------
# STEP 2:
# Install and update necessary software packages

dependencies="net-tools perl"

read -p "Do you wish to install 163.com repo for yum? [yes/NO] " repo_yn
if [[ $repo_yn = [Yy]* ]]; then
  # remove backup file if exists
  rm /etc/yum.repos.d/CentOS-Base.repo.backup

  # backup original centos repo
  mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

  # download the new repo file
  curl -o /etc/yum.repos.d/CentOS-Base.repo $web_base/repos/$os_distro-$os_version
  chmod 644 /etc/yum.repos.d/CentOS-Base.repo

  # clean up yum
  yum clean all
  yum makecache
fi

# installing upgrades
yum -y upgrade

# installing dependencies
yum -y install $dependencies


# ---------------------------------------------------------
# STEP 3:
# Set up ansible user

read -p "Do you wish to install ansible management user? [YES/no]" install_ansible

if [[ $install_ansible = [Nn]* ]]; then
  echo "Okay we are not going to install ansible user."
elif [[ ! -z $ansible_public_key ]]; then
  read -p "Sorry the public key for ansible user doesn't exist. Would you like to paste it here? [YES/no]" install_ansible_key
  if [[ $install_ansible_key = [Yy]* ]]; then
    read -p 'Public key for ansible user:' ansible_public_key
  fi
fi

if [[ $install_ansible = [Nn]* ]] && [[ -z $ansible_public_key ]]; then
  # add ansible user
  useradd ansible

  # ad ssh key
  mkdir -p /home/ansible/.ssh
  echo $ansible_public_key > /home/ansible/.ssh/authorized_keys

  # chown
  chown -R ansible /home/ansible

  # sudo
  sed -i.bak -r 's/(^root.*)/&\nansible\tALL=(ALL)\tNOPASSWD:ALL/' /etc/sudoers
  chmod 440 /etc/sudoers
fi

# # ---------------------------------------------------------
# # STEP 4:
# # Update sshd service

sshd_root_remove='s/^\s*#*\s*PermitRootLogin [a-z]*/PermitRootLogin no/'
sshd_root_clean='0,/PermitRootLogin no/! s/PermitRootLogin no/#deleted/'
sshd_passwd_remove='s/^\s*#*\s*PasswordAuthentication [a-z]*/PasswordAuthentication no/'
sshd_passwd_clean='0,/PasswordAuthentication no/! s/PasswordAuthentication no/#deleted/'
sshd_final='/^#deleted/ D'

sshd_config_file=/etc/ssh/sshd_config

sed -i.bak -r -e $sshd_root_remove -e $sshd_root_clean -e $sshd_passwd_remove -e $sshd_passwd_clean -e $sshd_final $sshd_config_file

if ! grep -Fxq '^PermitRootLogin no' $sshd_config_file; then
  echo >> $sshd_config_file
  echo "# Reject root login" >> $sshd_config_file
  echo "PermitRootLogin no" >> $sshd_config_file
fi

if ! grep -Fxq '^PasswordAuthentication no' $sshd_config_file; then
  echo >> $sshd_config_file
  echo "# Reject password authentication" >> $sshd_config_file
  echo "PasswordAuthentication no" >> $sshd_config_file
fi

# # ---------------------------------------------------------
# # STEP 6:
# # Install VMWare Tools.

#TODO install VMWare Tools
