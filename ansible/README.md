Ansible Playbooks
=================

### usermgt.yml

__Description__:
This playbook hires user package to add and remove users.

__Lists__:
* (user_addnew) users: standard users to be added
* (user_addnewsudo) users: sudo users to be added
* (user_remove) users: users to be removed, their home folder will also be cleaned from server.


### deploypkg.yml

__Description__:
This playbook installs and uninstalls packages

__Lists__:
Since the Debian-based and RHEL-based distros have different naming conventions, we need to specify the installation.
* apt_packages: packages to be installed on Debian-based distros.
* yum_packages: packages to be installed on RHEL-based distros.
