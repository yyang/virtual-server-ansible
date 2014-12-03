Examles for ansible tutorial
============================

### Example 1.

__Files__:
* `configuration/ansible.cfg --> /etc/ansible/ansible.cfg`
* `configuration/hosts --> /etc/ansible/hosts`

__Command__:
```
$ ./ansible -m ping –u {{remote_user}}
```

__Feature__: Ping all servers


### Example 2.

__Files__:
* `add-steve.yml`

__Command__:
```
$ ./ansible-playbok add-steve.yml
```

__Feature__: Add user `steve` to the server


### Example 3.

__Files__: N/A

__Command__:
```
$ ./ansible {{server_group}} -a "/sbin/reboot"
$ ./ansible {{server_group}} -a "/usr/bin/foo" -u {{remote_user}} --sudo [--ask-sudo-pass]
```

__Feature__: Ad hoc commands


### Example 4.

__Files__:
* `usermgt.yml`

__Command__:
```
$ ./ansible-playbok usermgt.yml
```

__Feature__: Batch user management



### Example 5.

__Files__:
* `deploypkg.yml`

__Command__:
```
$ ./ansible-playbok deploypkg.yml
```

__Feature__: Batch deploy packages
