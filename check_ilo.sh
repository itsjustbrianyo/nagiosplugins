#!/bin/bash
#
# check_ilo - Display information about iLOs
#            The iLO is the Integrated Lights-Out management processor
#            used on HP ProLiant and BladeSystem servers
# 
# This script is based upon findilos and adapted for use with nagios
# Original changes by Karsten Mueller <kmu@me.com>
# Updated to 1.2 by Brian Mathis
# Added support for ILO 3,4,5
#
scriptversion="1.2"
#
# Based upon findilos
# Author: iggy@nachotech.com
# Website: http://blog.nachotech.com
# Requires: tr sed expr curl
#
# Note: If the iLO XML Reply Data Return has been Disabled by
#       the iLO administrator, this script will not be able to
#       gather any information about the server.
#

# GLOBAL VARIABLES
scriptname="check_ilo"
iloxml=$(mktemp)
ilohwvers=$(mktemp)

# FUNCTIONS
function parseiloxml {
  fgrep "$1" $iloxml > /dev/null 2>&1
  if [ $? -ne 0 ]
  then
    # tag not found in xml output, return empty string
    parsedstring="N/A"
  else
    # tag was found - now we parse it from the output
    tempstring=$( cat $iloxml | tr -d -c '[:print:]' | sed "s/^.*<$1>//" | sed "s/<.$1.*//")
    # trim off leading and trailing whitespace
    parsedstring=`expr match "$tempstring" '[ \t]*\(.*[^ \t]\)[ \t]*$'`
  fi
}

function is_installed {
  which $1 > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    printf "UNNKNOWN - ERROR: %s not installed.\n\n" $1
    cleanexit 3
  fi
}

function cleanexit {
  rm -f $iloxml $ilohwvers
  exit $1
}

# MAIN
# check for tools that we depend upon
is_installed tr
is_installed sed
is_installed expr
is_installed curl

# check syntax - should have 1 and only 1 parameter on cmdline
if [ $# -ne 1 ]; then
  printf "Usage: %s {hostname|ip address}\n" $scriptname
  cleanexit 3
fi
iloip=$1

# prepare lookup file for iLO hardware versions
cat > $ilohwvers << EOF
iLO-1 shows hw version ASIC:  2
iLO-2 shows hw version ASIC:  7
iLO-3 shows hw version ASIC: 8
iLO-3 shows hw version ASIC: 9
iLO-4 shows hw version ASIC: 12
iLO-4 shows hw version ASIC: 16
iLO-5 shows hw version ASIC: 19
iLO-5 shows hw version ASIC: 21
i-iLO shows hw version T0
EOF

# attempt to read the xmldata from iLO, no password required
curl --proxy "" --fail --max-time 10 http://$iloip/xmldata?item=All > $iloxml 2>&1

if [ $? -gt 0 ]; then
  echo "WARNING - $(cat $iloxml | tr -d '\n')"
  cleanexit 1
fi

# parse out the Server model (server product name) from the XML output
parseiloxml SPN;  servermodel=$parsedstring
parseiloxml SBSN; sernum=$parsedstring
parseiloxml PN;   ilotype=$parsedstring
parseiloxml FWRI; ilofirmware=$parsedstring
parseiloxml HWRI; ilohardware=$parsedstring

ilohwver=$(grep "$ilohardware" $ilohwvers|awk '{print $1}')

if [ "$ilohwver" == "" -o "$sernum" == "" ]; then
  echo "CRITICAL - Can't get no iLO information from $iloip"
  cleanexit 2
fi

printf "OK - type: %s firmware: %s serial: %s Server: %s\n" "$ilohwver" "$ilofirmware" "$sernum" "$servermodel"
cleanexit 0
