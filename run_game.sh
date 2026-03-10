#!/bin/bash
cd "$(dirname "$0")"
/Applications/Godot.app/Contents/MacOS/Godot -v --path . &
GODOT_PID=$!
sleep 8
screencapture -x ~/Desktop/godot_running_game.png
kill $GODOT_PID 2>/dev/null
