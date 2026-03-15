#!/bin/bash
# Load X resources
xrdb -merge ~/.Xresources

# HiDPI: set before anything else
xrandr --dpi 192   # adjust for target display (96 = 1x, 192 = 2x)
exec i3
