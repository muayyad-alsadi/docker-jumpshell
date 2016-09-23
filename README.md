# Jump shell for Docker

Used as user shell to allow developers jump into their containers using ssh

## Features

* simple and effective ACL, just run the container with `-l owner=myuser` or `-l group=mygroup`
* opens all owned containers in `tmux` windows
* interactive picker `ssh -t myuser@remote picker`
* scriptable non-interactive mode `ssh myuser@remote mycontainer cat /etc/hosts | wc -l`
* tail container logs `ssh myuser@remote docker_logs mycontainer | grep ERROR`
* and with log picker `ssh -t myuser@remote docker_logs`

![Container Picker](/picker.png)

## Security

* developers are NOT granted access to host
* developers are NOT granted access to docker socket
* developers can NOT execute random docker commands
* only listing owned containers and exec inside owned containers is allowed
* only containers having special labels are allowed
* `sudo` is only to a simple helper script that do the above checks

## FAQ

* Can I use it with [mosh](https://mosh.org/)?
..* yes, it just work
* Can I use it to create tunnels to a container port?
..* yes `ssh -L 8080:<CONTAINER_IP>:8080 -t myuser@remote picker` (don't forget `-t`)
* How can I receive a file from the container?
..* simply `cat` it, like this `ssh myuser@remote mycontainer cat /path/to/myfile > ./myfile`
* How can I send a file to the container?
..* simply `cat` it, like this `ssh myuser@remote mycontainer bash -c "cat > /path/to/myfile" < ./myfile`
* How can I receive a directory from the container?
..* simply `tar` it, like this `ssh myuser@remote mycontainer tar -czf - /path/to/mydir | tar -xzf - -C .`
* How can I send a directory to the container?
..* simply `tar` it, like this `tar -czf - . | ssh myuser@remote mycontainer tar -xzf - -C /path/to/mydir`
* Is it possible to `scp`?
..* no, use `tar` trick above
* Is it possible to `rsync` over `ssh`?
..* no, use `tar` trick above
* How to remove access from a user? I can't remove docker label!
..* remove the public key from `authorized_keys`
..* or remove the UNIX user from `jumpshell` group
* Can I define custom shell?
..* yes, pass `-l shell=/full/path/to/shell`
..* no need to define it for `bash` and `sh`

## Requirements

* docker with label support
* tmux
* whiptail

## Setup

Just place them in a place like `/usr/local/bin/`

```
curl -sSLO https://github.com/muayyad-alsadi/docker-jumpshell/archive/v1.3/docker-jumpshell-1.3.tar.gz
tar -xzf docker-jumpshell-1.3
cd docker-jumpshell-1.3
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

in `tmux` use

* `CTRL+B n` to move to next window,
* `CTRL+B c` to create a new window
* `CTRL+B d` to detach

## How it works

members of group `jumpshell` are allowed to `sudo` the helper script.

the helper script is a simple secure script that

* sudo itself if not root
* accept only two commands `ls` and `exec` 
* `ls` would list all containers having label `owner=<USER>` or `group=<GROUP>`
* `exec` is followed by container id
* `exec` validates that the given container have the suitable label (authorize)
* `exec <ID>` would run interactive bash inside the given container
* `exec <ID> <COMMAND>` would run `bash -c "COMMAND"` inside the given container
* `logs <ID>` tail and follow logs of given container

the shell of the desired user is set to `docker-jumpshell.sh`
which has more complex logic but it's safe because the user can't `sudo` it
the shell is executed when users access it remotely via `ssh`

## Group Access

If a container is to be accessed by more than one user,
create a UNIX group for that by typing `groupadd jumpshell-mygroup`
then add users to that group, then run your docker containers with label `group=mygroup`

NOTE: we have added `jumpshell-` prefix to UNIX group name
that is omitted from docker label. The reason behind this 
is to allow you so that UNIX `admin` is not `jumpshell-admin`

