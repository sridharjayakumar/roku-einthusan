#!/bin/bash
# Generate placeholder images for Roku channel
# Requires ImageMagick (brew install imagemagick)

# Channel icon (focus) - HD 336x210
convert -size 336x210 xc:"#1a1a2e" -fill "#FF6600" -font Helvetica-Bold \
    -pointsize 36 -gravity center -annotate 0 "Einthusan" \
    icon_focus_hd.png

# Channel icon (focus) - SD 248x140
convert -size 248x140 xc:"#1a1a2e" -fill "#FF6600" -font Helvetica-Bold \
    -pointsize 28 -gravity center -annotate 0 "Einthusan" \
    icon_focus_sd.png

# Splash screen - HD 1920x1080
convert -size 1920x1080 xc:"#000000" -fill "#FF6600" -font Helvetica-Bold \
    -pointsize 72 -gravity center -annotate 0 "Einthusan" \
    splash_hd.png

# Splash screen - SD 720x480
convert -size 720x480 xc:"#000000" -fill "#FF6600" -font Helvetica-Bold \
    -pointsize 48 -gravity center -annotate 0 "Einthusan" \
    splash_sd.png

echo "Placeholder images generated!"
