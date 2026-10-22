#!/bin/bash
set -e

# ROS Environment
source /opt/ros/melodic/setup.bash

workspace=/home/jetbot/catkin_ws
mkdir -p "$workspace/src" "$workspace/build_isolated" "$workspace/devel_isolated"
if [ ! -f "$workspace/devel_isolated/setup.bash" ]; then
    cd "$workspace"
    catkin_make_isolated
fi

if [ -f "$workspace/devel_isolated/setup.bash" ]; then
    source "$workspace/devel_isolated/setup.bash"
fi

exec "$@"