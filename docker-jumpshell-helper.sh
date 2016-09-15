#! /bin/bash
# USAGE: 
#    <BASENAME> ls               - list containers having a label owner=<USER> with "ID NAME" format
#    <BASENAME> exec <ID>        - run interactive bash shell inside container <ID>
#    <BASENAME> exec <ID> <ARGS> - run ARGS using bash shell inside container <ID>
set -e

function error() {
    echo "ERROR: $@" >&2
    exit -1
}

# make sure it's running as root
[ $UID -ne 0 ] && {
    # if no root sudo itself
    exec sudo -- "$0" "$@"
} || {
    user="$SUDO_USER"
    [ "x$user" == "x" ] && error "can't run without sudo"
    # remove command from args
    CMD="$1"
    shift
    if [ "x$CMD" == "xls" ]
    then
        docker ps --format="{{.ID}} {{.Names}}" --filter=label=owner="$user"
    elif [ "x$CMD" == "xexec" ]
    then
        [ $# -eq 0 ] && error "No container id passed"
        # remove container from args
        CONTAINER="$1"
        shift
        owner=`docker inspect --type=container -f '{{.Config.Labels.owner}}' "$CONTAINER"`
        if [ "x$owner" == "x$user" ]
        then
           if [ $# -eq 0 ]
           then
                exec docker exec -ti "$CONTAINER" /bin/bash -l
           else
                OPT='-i'
                [ -t 1 ] && OPT="-ti"
                exec docker exec "$OPT" "$CONTAINER" /bin/bash "$@"
           fi
        else
           error "you are not allowed to access this container"
        fi
    else
        error "unsupported command $@"
    fi
}
