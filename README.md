# Jump shell for Docker

Used as user shell to allow developers jump into their containers using ssh

# Features

* simple and effective ACL, just run the container with `-l owner=myuser`
* opens all owned containers in `tmux` windows
* interactive picker `ssh -t myuser@remote picker`
* scriptable non-interactive mode `ssh myuser@remote mycontainer cat /etc/hosts | wc -l`

# Requirements

* docker with label support
* tmux
* whiptail

# Install scripts

Just place them in a place like `/usr/local/bin/`

```
curl -sSLO https://github.com/muayyad-alsadi/docker-jumpshell/archive/v1.0/docker-jumpshell-1.0.tar.gz
tar -xzf docker-jumpshell-1.0
cd docker-jumpshell-1.0
cp *.sh /usr/local/bin/
```

create a group to be allowed to jump into their owned docker containers

```
groupadd jumpshell
```

add the following to `/etc/sudoers.d/docker-jumpshell`

```
Defaults    !requiretty
%jumpshell	ALL=(ALL)	NOPASSWD: /usr/local/bin/docker-jumpshell-helper.sh
```

add the user, make his shell be the script, run a container of your choice named after the user

```
useradd myuser
usermod -a -G jumpshell myuser
chsh -s /usr/local/bin/docker-jumpshell.sh myuser
docker run -d -t --restart=always --name=my-fedora -l owner=myuser fedora/systemd-systemd
docker run -d -t --restart=always --name=my-ubuntu -l owner=myuser ubuntu-upstart:trusty
```

add public keys to `/home/myuser/.ssh/authorized_keys` and make sure they have right permissions

```
sudo -u myuser /bin/bash -l
mkdir -p /home/myuser/.ssh/
vim /home/myuser/.ssh/authorized_keys
chmod 700 /home/myuser/.ssh/authorized_keys
chmod 644 /home/myuser/.ssh/authorized_keys
```

now you can execute commands in the container or have interactive shells on it

```
ssh -t myuser@remotebox picker
ssh -t myuser@remotebox my-fedora
ssh myuser@remotebox my-fedora cat /etc/hosts
ssh myuser@remotebox
```

use `CTRL+B n` to move to next window, and `CTRL+B c` to create a new window

