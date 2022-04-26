#!/bin/bash

search() {
 for i in "$1"/*;do
    if [ -d "$i" ];then
        if [ -f "$i/manifest.yaml" ]; then
          corral package publish "ghcr.io/rancherlabs/corral-packages/$(echo $i | cut -d'/' -f2-)"
        else
          search "$i"
        fi
    fi
 done
}

search dist