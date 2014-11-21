#!/bin/bash

# Note: This script should run by root user himself, or with sudo permission.
# This is only used for setting up server at the very beginning.

# ==============================================================================
# PRESET VARIABLES
# ==============================================================================

web_base="http://172.18.99.87:8000"
ansible_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCtUCNsZ6fJckR6Qzvj3QDOMefauIv6+0UjgmoaflvJJC/pCOWm5jkVtb7CIQ32FIbZcnOREzPSilgJipW1czbaCZtZoKb3Nsam3l/1DhYGKU4tNK2CVHstooDgeg4ph2w7Gi6WYEwdVmEOk5HLa9OtWX+FmPe4/Gs96J2lgkh1xaCmkD5IiaM1dv9dKv7LveJC4rpzhUWj/xYnqIbFPpCQoDUdwuhJ/zbAjaCMBDvzbnRyQpgRzjC9XS/Whcwkt04rSgwGjkdRMdS/L07jFXJBb7Ms74pOgmBwwW6ju04OD80NBgpOwFvK/W5BNJ1Ku7nxm4m6gmKSnuTOi4WV3cz5 ansible@stu.edu.cn"
default_dns="202.104.245.186 202.192.159.2"
default_domain=stu.edu.cn
default_workgroup=stunic
vmwaretools_filename="VMwareTools-9.4.5-1618308.tar.gz"

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

# arguments: log_string
# example: note "Success!"
note()
{
  echo $1 >> /root/server_setup.log
}

# arguments: log_string
# example: log "Success!"
log()
{
  echo "[$(date +"%r")]: $1" >> /root/server_setup.log
}

# arguments: log_string
# example: echolog "Success!"
echolog()
{
  log $1
  echo $1
}


# ---------------------------------------------------------
# STEP 0:
# Understand OS and configuration

echo "Welcome to Steve's VM Setup Script."
echo "We are detecting your operating system."

note
note "Server Setup Initiated."
note "Time: $(date), [$(date +%s)]"

# detects OS information
. /etc/os-release

os_distro=$ID
os_distro_like=$ID_LIKE
os_version=$VERSION_ID
os_arch=$(uname -m | sed 's/x86_//;s/i[3-6]86/32/')
os_pretty_name=$PRETTY_NAME
os_supported=0

log "Operating System: $os_pretty_name"
log "Linux Distro:     $os_distro, like $os_distro_like"
log "Linux Version:    $os_version, $os_arch"

case $os_distro in
  amzn ) ;;
  centos ) 
    case $os_version in
      [12345] ) echolog "We strongly recommend to upgrade the OS."
      6) os_supported=1;;
      7) os_supported=1;;
      *) echolog "Unrecognized CentOS version.";;
    esac
    ;;
  ubuntu ) ;;
  rhel ) ;;
  debian ) ;;
  * ) ;;
esac

if [[ $os_supported = 1 ]]; then
  log "OS Supported:     Yes"
  echo "Your $os_pretty_name is supported. Welcome."
  echo
else
  log "OS Supported:     No"
  echolog "Terminated due to unsupported OS, please contact git@iyyang.com for futher support."
  exit
fi

while true; do
  read -p "This script requires hard interfaces, e.g. keyboard or VM console, to further modify network settings. Are you using hard interfaces? " $hardinterface_yn
  case $hardinterface_yn in
    [Yy]* ) log "Hard Interface:   Yes"; break;;
    [Nn]* ) echolog "Terminated due to using SSH connection."; exit;;
    * ) echo "Please answer Yes or No.";;
  esac
done

net_conn_name=$default_workgroup
net_dns4=$default_dns
net_network_device=
net_ip4=
net_gw4=
net_workgroup=$default_workgroup
net_feature=server
net_domain=$default_domain
net_hostname=
net_confirmed=False

if [[ $os_distro = 'centos' ]]; then
  if [[ $os_version = 7 ]]; then
    net_network_device=$(nmcli dev status | grep ethernet | awk '{ print $1}')
    if [ -z $net_network_device ]; then
      echolog "Ethernet device not found. Please check your system and run the script again."
      echolog "Terminated due to ethernet device not found."
      exit
    fi
    net_ip4=$(ip addr | grep $net_network_device | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
  elif [[ $os_version = 6 ]]; then
    #warning TODO: Implement code for CentOS 6 here
  fi
elif [[ $os_distro = 'ubuntu' ]]; then
  #warning TODO: Implement code for Ubuntu here
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
  while true; do
    confirm_variable "Gateway" $net_gw4
    target_gw4=$return_confirmed

    if [[ $target_gw4 =~ ^$rx\.$rx\.$rx\.$rx$ ]]; then
      net_gw4=$target_gw4
      break
    else
      echo "Please enter a valid IP address."
    fi
  done

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
  echo "Ethernet Device:  $net_network_device"
  echo "IP Address:       $net_ip4"
  echo "Gateway:          $net_gw4"
  echo "DNS:              $net_dns4"
  echo "Workgroup:        $net_workgroup"
  echo "Feature:          $net_feature"
  echo "Domain:           $net_domain"
  echo "Hostmane (generated): $net_hostname"

  # confirm information
  net_options[0]="Yes, please set up my network connection."
  net_options[1]="No, I will need to revise."
  echo "Are those information correct?"
  select net_selection in "${net_options[@]}" "Quit setup." ; do
    case "$REPLY" in
      1 ) break 2;;
      2 ) break;;
      3 ) echo "Goodbye!"; log "User Terminated"; exit;;
      * ) echo "Invalid option. Try another one."; continue;;
    esac
  done
done

log "[Network Configuration]"
log "Ethernet Device:  $net_network_device"
log "IP Address:       $net_ip4"
log "Gateway:          $net_gw4"
log "DNS:              $net_dns4"
log "Workgroup:        $net_workgroup"
log "Feature:          $net_feature"
log "Domain:           $net_domain"
log "Hostmane (generated): $net_hostname"

echo
echo "We would want to gather more information before continue installation"

read -p "Do you wish to install 163.com repo for yum? (Yes/No) [NO] " repo_yn
if [[ $repo_yn = [Yy]* ]]; then
  repo_yn="Yes"
else
  repo_yn="No"
fi

read -p "Do you wish to upgrade your system packages? (Yes/No) [YES] " upgrade_yn
if [[ $upgrade_yn = [Nn]* ]]; then
  upgrade_yn="No"
else
  upgrade_yn="Yes"
fi

read -p "Do you wish to install ansible management user? (Yes/No) [YES] " ansible_yn
if [[ $ansible_yn = [Nn]* ]]; then
  ansible_yn="No"
else
  ansible_yn="Yes"
fi

read -p "Do you wish to install VMWare Tools? (Yes/No) [YES] " vmwaretools_yn
if [[ $vmwaretools_yn = [Nn]* ]]; then
  vmwaretools_yn="No"
else
  vmwaretools_yn="Yes"
fi

log "[System Settings]"
log "163.com mirror:   $repo_yn"
log "Upgrade packages: $upgrade_yn"
log "Ansible user:     $ansible_yn"
log "VMWare Tools:     $vmwaretools_yn"

log "[Server Setup Started ...]"

# ---------------------------------------------------------
# STEP 1:
# Set up IP address and hostname

# set up IP iddress
if [[ $os_distro = 'centos' ]]; then
  if [[ $os_version = 7 ]]; then
    nmcli con add type ethernet con-name $net_conn_name ifname $net_network_device ip4 $net_ip4/24 gw4 $net_gw4
  elif [[ $os_version = 6 ]]; then
    #warning TODO: Implement code for CentOS 6 here
  fi
elif [[ $os_distro = 'ubuntu' ]]; then
  #warning TODO: Implement code for Ubuntu here
fi

# set up gateway
if [[ $os_distro = 'centos' ]]; then
  if [[ $os_version = 7 ]]; then
    nmcli con mod $net_conn_name ipv4.dns "$net_dns4"
  elif [[ $os_version = 6 ]]; then
    #warning TODO: Implement code for CentOS 6 here
  fi
elif [[ $os_distro = 'ubuntu' ]]; then
  #warning TODO: Implement code for Ubuntu here
fi

# set up hostname
if [[ $os_distro = 'centos' ]]; then
  if [[ $os_version = 7 ]]; then
    hostnamectl set-hostname $net_hostname
  elif [[ $os_version = 6 ]]; then
    #warning TODO: Implement code for CentOS 6 here
  fi
elif [[ $os_distro = 'ubuntu' ]]; then
  #warning TODO: Implement code for Ubuntu here
fi

echolog "Successfully updated network settings..."
echo

# ---------------------------------------------------------
# STEP 2:
# Install and update necessary software packages

dependencies="net-tools perl"

if [[ $repo_yn = "Yes" ]]; then
  # backup original centos repo
  mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup

  echo "Repo inserted"

  # download the new repo file
  curl -o /etc/yum.repos.d/CentOS-Base.repo $web_base/repos/$os_distro-$os_version
  chmod 644 /etc/yum.repos.d/CentOS-Base.repo

  # clean up yum
  yum clean all
  yum makecache
fi

if [[ $upgrade_yn = "Yes" ]]; then
  # installing upgrades
  yum -y upgrade
fi

# installing dependencies
yum -y install $dependencies

echolog "Successfully updated software packages..."
echo

# ---------------------------------------------------------
# STEP 3:
# Set up ansible user and update sshd services

if [[ $ansible_yn = "Yes" ]]; then
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

  echolog "Successfully added ansible user..."
  echo
fi

# SSHD set up is mandatory.
sshd_config_file=/etc/ssh/sshd_config

# attempt to modify in situ first.
sed -i.bak -r -e "s/^\s*#*\s*PermitRootLogin [a-z]*/PermitRootLogin no/" \
              -e "0,/PermitRootLogin no/! s/PermitRootLogin no/#deleted/" \
              -e "s/^\s*#*\s*PasswordAuthentication [a-z]*/PasswordAuthentication no/" \
              -e "0,/PasswordAuthentication no/! s/PasswordAuthentication no/#deleted/" \
              -e "/^#deleted/ D" $sshd_config_file

# reject root login if not set
if ! grep -xq '^PermitRootLogin no' $sshd_config_file; then
  echo >> $sshd_config_file
  echo "# Reject root login" >> $sshd_config_file
  echo "PermitRootLogin no" >> $sshd_config_file
fi

# reject password authentication if not set
if ! grep -xq '^PasswordAuthentication no' $sshd_config_file; then
  echo >> $sshd_config_file
  echo "# Reject password authentication" >> $sshd_config_file
  echo "PasswordAuthentication no" >> $sshd_config_file
fi

echolog "Successfully revised SSHD permissions..."
echo

# # ---------------------------------------------------------
# # STEP 4:
# # Install VMWare Tools.

if [[ $vmwaretools_yn = "Yes" ]]; then
  # download
  cd /root
  curl -O $web_base/packages/$vmwaretools_filename

  tar -xvzf $vmwaretools_filename

  cd vmware*
  ./vmware-install.pl

  echolog "Successfully Installed VMWare Tools..."
fi

echolog "Goodbye."
echo
exit
