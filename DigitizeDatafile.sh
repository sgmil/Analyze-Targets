#!/bin/bash
# Program to start engauge digitizer with specified file.

Datapath=~/Targets
echo "Enter file in $Datapath: (omit.jpg)"
read Targetfile

engauge -import $Datapath/$Targetfile.jpg &