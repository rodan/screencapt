#!/bin/bash

find / -type f \( -perm -4000 -o -perm -2000 \) 2> /dev/null | while read file; do echo "${file} $(stat --format='%a %A' ${file}) "; chmod 711 ${file}; done

