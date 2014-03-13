#!/bin/bash

strings /tmp/wrapper.log  | grep -E '(SENT GET)|(Host)'  | sed -e :a -e '$!N;s/\nHost:/ /;ta' -e 'P;D' | sed 's|.*[0-9]\{4\}: SENT GET \(.*\) HTTP/.* \(.*\)|http://\2\1|'

