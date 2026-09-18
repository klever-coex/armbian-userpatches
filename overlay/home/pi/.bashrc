[ -z "$PS1" ] && return

alias ll='ls -la'
alias la='ls -A'
alias l='ls -lCF'

source /opt/ros/jazzy/setup.bash
source /opt/clover2/ws/install/setup.bash
. /etc/ros2/dds/env

# non-DDS env that used to live in the builder's ros2.env
export RCUTILS_COLORIZED_OUTPUT=1
export CLOVER2_CONFIG_FILE=/opt/clover2/.config.yaml

clover2-settings() {
    ros2 run clover2_ui settings \
        "$(ros2 pkg prefix clover2_bringup --share)/schemas/klever5.yaml" \
        "$CLOVER2_CONFIG_FILE"
}
