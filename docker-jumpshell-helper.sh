#! /bin/bash
# USAGE: 
#    <BASENAME> ls               - list containers having a label owner=<USER> with "ID NAME" format
#    <BASENAME> exec <ID>        - run interactive bash shell inside container <ID>
#    <BASENAME> exec <ID> <ARGS> - run ARGS using bash shell inside container <ID>
set -e

GROUP_PREFIX='jumpshell-'
LOG='/var/log/jumpshell.log'

function error() {
    echo "`date '+%F %T'` ERROR $@" >> $LOG
    echo "ERROR: $@" >&2
    exit -1
}

function docker_ls() {
    user="$1"
    docker ps --format="{{.ID}} {{.Names}}" --filter=label=owner="$user"
    for group in `groups "$user" | cut -d ':' -f 2- `
    do
        if [[ "$group" == ${GROUP_PREFIX}* ]]
        then
            g=`echo "$group" | sed -re "s#^${GROUP_PREFIX}##;"`
            docker ps --format="{{.ID}} {{.Names}}" --filter=label=group="$g"
        fi
    done

}

function docker_authorize() {
    user="$1"
    container="$2"
    owner=`docker inspect --type=container -f '{{.Config.Labels.owner}}' "$container"`
    [ "x$owner" == "x$user" ] && return 0
    valid_group=`docker inspect --type=container -f '{{.Config.Labels.group}}' "$container"`
    for group in `groups "$user" | cut -d ':' -f 2- `
    do
        if [[ "$group" == ${GROUP_PREFIX}* ]]
        then
            g=`echo "$group" | sed -re "s#^${GROUP_PREFIX}##;"`
            [ "x$g" == "x${valid_group}" ] && return 0
        fi
    done
    return -1
}


# make sure it's running as root
[ $UID -ne 0 ] && {
    # if no root sudo itself
    exec sudo -- "$0" "$@"
} || {
    user="$SUDO_USER"
    # TODO pass SSH_CONNECTION="${SSH_CONNECTION}" to sudo or any way to log it
    # echo "got connection ${user} ${LOG_SSH_CONNECTION}" >> $LOG
    [ "x$user" == "x" ] && error "can't run without sudo"
    # remove command from args
    CMD="$1"
    shift
    if [ "x$CMD" == "xls" ]
    then
        docker_ls "$user"
    elif [ "x$CMD" == "xexec" ]
    then
        [ $# -eq 0 ] && error "No container id passed"
        # remove container from args
        CONTAINER="$1"
        shift
        if docker_authorize "$user" "$CONTAINER"
        then
            shell=`docker inspect --type=container -f '{{.Config.Labels.shell}}' "$CONTAINER" | grep '^/' || :`
            if [ "x$shell" == "x" ]
            then
                if docker exec -i "$CONTAINER" /bin/bash -c ":"
                then
                    shell="/bin/bash"
                else
                    shell="/bin/sh"
                fi
            fi
            echo "`date '+%F %T'` INFO user=${user} container=${CONTAINER} shell=${shell} passed=$@" >> $LOG
            if [ $# -eq 0 ]
            then
                exec docker exec -ti "$CONTAINER" "$shell"
            else
                OPT='-i'
                [ -t 0 ] && [ -t 1 ] && OPT="-ti"
                exec docker exec "$OPT" "$CONTAINER" "$shell" "$@"
            fi
        else
           error "you are not allowed to access this container"
        fi
    else
        error "unsupported command $@"
    fi
}
