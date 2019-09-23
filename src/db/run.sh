#!/bin/sh

if [ "X$1" = "X-r" ]
then
    #rm -f $HOME/develop/data/raspirec/db/epg.db
    rm -f /data/shiiya/rrtest/db/epg.db
    shift
fi

if cd $HOME/develop/raspirec
then
    if [ "X$1" = "X-g" ]
    then
        ruby db/rec.rb
    fi

    ruby db/epgData.rb
fi


