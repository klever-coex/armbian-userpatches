#! /usr/bin/env bash

. /etc/ros2/dds/env

source /opt/ros/jazzy/setup.bash

if [ -f /opt/clover2/ws/install/setup.bash ]; then
    source /opt/clover2/ws/install/setup.bash

    klever5_launcher.py --config /opt/clover2/.config.yaml
else
    echo "The clover2 workspace not exists"
    exit 255
fi
