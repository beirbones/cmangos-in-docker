#!/bin/bash
# cmangos-in-docker health check
if [ ! -f "/home/mangos/cmangos-*/run/bin/.SETUPCOMPLETE" ]
then
    exit 0
elif [ "$(screen -list | grep -o -w mangosd)" = mangosd ] && [ "$(screen -list | grep -o -w realmd)" = realmd ]
then
    exit 0
else
    exit 1
fi