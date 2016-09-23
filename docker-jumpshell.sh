#! /bin/bash
set -e

function pick_logs() {
    DIR=`dirname $0`
    MSG="Follow logs of which container?"
    CONTAINER=$( "$DIR/docker-jumpshell-helper.sh" ls | xargs whiptail --title "$MSG" --menu "$MSG" 20 70 13 3>&1 1>&2 2>&3 )
    [ $? -ne 0 ] && {
        echo "canceled"
    } || {
        exec "$DIR/docker-jumpshell-helper.sh" logs "$CONTAINER"
    }
}

function pick_container() {
    DIR=`dirname $0`
    MSG="Choose a container"
    CONTAINER=$( ( echo _ logs; "$DIR/docker-jumpshell-helper.sh" ls ) | xargs whiptail --title "$MSG" --menu "$MSG" 20 70 13 3>&1 1>&2 2>&3 )
    [ $? -ne 0 ] && {
        echo "canceled"
    } || {
        if [ "x$CONTAINER" == "x_" ]
        then
            pick_logs
        else
            exec "$DIR/docker-jumpshell-helper.sh" exec "$CONTAINER"
        fi
    }
}



function get_containers() {
    DIR=`dirname $0`
    "$DIR/docker-jumpshell-helper.sh" ls
}

function error() {
    echo "ERROR: $@" >&2
    exit -1
}

DIR=`dirname $0`
if [ $# -ne 0 ]
then
    [ $# -ne 2 ] && error "expecting -c COMMAND"
    [ "x$1" != "x-c" ] && error "expecting leading -c got $@"
    # remove leading -c
    shift
    ARG="$1"
    CONTAINER=$( echo "$ARG" | cut -d ' ' -f 1 )
    REST=$( echo "$ARG" | cut -s -d ' ' -f 2- )
    if [ "x$CONTAINER" == "xpicker" ]
    then
        pick_container
    elif [ "x$CONTAINER" == "xdocker_logs" ]
    then
        if [ "x$REST" == "x" ]
        then
            pick_logs
        else
            exec "$DIR/docker-jumpshell-helper.sh" logs "$REST"
        fi
    elif [ "x$CONTAINER" == "xls" ]
    then
        get_containers
        exit 0
    fi
    if [ "x$REST" == "x" ]
    then
        exec "$DIR/docker-jumpshell-helper.sh" exec "$CONTAINER"
    else
        exec "$DIR/docker-jumpshell-helper.sh" exec "$CONTAINER" -c "$REST"
    fi
fi

if tmux ls
then
    # we have tmux sessions
    [ "x$TMUX" == "x" ] && {
        # not inside an already exising tmux, then attach to one
        exec tmux attach
    } || {
        # already inside tmux (ex. new window)
        pick_container
    }
else
    # no tmux sessions, create a new one with a window for each container
    DIR=`dirname $0`
    TMUX_CMD=new-session
    get_containers | while read CONTAINER NAME
    do
        tmux $TMUX_CMD -d -n "$NAME" "$CONTAINER"
        TMUX_CMD=new-window
    done
    exec tmux attach
fi
