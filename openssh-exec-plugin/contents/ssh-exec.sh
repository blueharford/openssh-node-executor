#!/bin/bash

#####
# ssh-exec.sh
# This script executes the system "ssh" command to execute a command
# on a remote node.
# usage: ssh-exec.sh [username] [hostname] [command...]
#
# It uses some environment variables set by Rundeck if they exist:
# RD_NODE_SSH_PORT:  the "ssh-port" attribute value for the node to specify
#   the target port, if it exists
# RD_NODE_SSH_KEYFILE: the "ssh-keyfile" attribute set for the node to
#   specify the identity keyfile, if it exists
# RD_CONFIG_SSH_KEY_STORAGE_PATH: the "ssh-key-storage-path" attribute set for the node to
#   specify the identity keyfile
# RD_NODE_SSH_OPTS: the "ssh-opts" attribute, to specify custom options
#   to pass directly to ssh.  Eg. "-o ConnectTimeout=30"
# RD_NODE_SSH_TEST: if "ssh-test" attribute is set to "true" then do
#   a dry run of the ssh command
#####

USER=$1
shift
HOST=$1
shift
CMD="$@"

# use RD env variable from node attributes for ssh-port value, default to 22:
PORT=${RD_NODE_SSH_PORT:-22}

# extract any :port from hostname
XHOST=$(expr "$HOST" : '\(.*\):')
if [ ! -z $XHOST ] ; then
    PORT=${HOST#"$XHOST:"}
    #    echo "extracted port $PORT and host $XHOST from $HOST"
    HOST=$XHOST
fi

SSHOPTS="-p $PORT -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o LogLevel=quiet"

#use ssh-keyfile node attribute from env vars
if [[ -n "${RD_NODE_SSH_KEYFILE:-}" ]]
then
    SSHOPTS="$SSHOPTS -i $RD_NODE_SSH_KEYFILE"
elif [[ -n "${RD_CONFIG_SSH_KEY_STORAGE_PATH:-}" ]]
then
    mkdir -p "/tmp/.ssh-exec"
    SSH_KEY_STORAGE_PATH=$(mktemp "/tmp/.ssh-exec/ssh-keyfile.$USER@$HOST.XXXXX")
    # Write the key data to a file
    echo "$RD_CONFIG_SSH_KEY_STORAGE_PATH" > $SSH_KEY_STORAGE_PATH
    SSHOPTS="$SSHOPTS -i $SSH_KEY_STORAGE_PATH"
fi

#use any node-specified ssh options
if [[ ! -z "$RD_NODE_SSH_OPTS" ]] ; then
    SSHOPTS="$SSHOPTS $RD_NODE_SSH_OPTS"
fi

RUNSSH="ssh $SSHOPTS $USER@$HOST source $RD_CONFIG_ENVFILE && $CMD"

#if ssh-test is set to "true", do a dry run
if [[ "true" == "$RD_NODE_SSH_TEST" ]] ; then
    echo "[ssh-exec]" $RUNSSH
    exit 0
fi


#finally, use exec to pass along exit code of the SSH command
exec $RUNSSH

