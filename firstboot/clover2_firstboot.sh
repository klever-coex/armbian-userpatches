#!/usr/bin/env bash
set -u

# Wi-Fi access point + matching hostname; only when a wireless card exists
if ip link show wlan0 &>/dev/null; then
	hostname="clover2-$(openssl rand -hex 3)"
	nmcli con add type wifi ifname wlan0 mode ap con-name clover2 ssid "$hostname" autoconnect yes &&
		nmcli con modify clover2 802-11-wireless.band bg &&
		nmcli con modify clover2 ipv4.method shared ipv4.address 192.168.11.1/24 &&
		nmcli con modify clover2 ipv6.method disabled &&
		nmcli con modify clover2 wifi-sec.key-mgmt wpa-psk &&
		nmcli con modify clover2 wifi-sec.psk "cloverwifi" &&
		hostnamectl set-hostname "$hostname" || echo "WARN: Wi-Fi AP setup failed"
fi

# Preload docker images dropped into /root by the clover2-docker extension
for tar in /root/*.tar; do
	[[ -f "${tar}" ]] || continue
	echo "docker load: ${tar}"
	docker load -i "${tar}"
	rm -f "${tar}"
done

cat >> "/boot/firmware/config.txt" <<'EOF'

[pi5]
camera_auto_detect=1
dtparam=fan_temp0=40000,fan_temp0_hyst=5000,fan_temp0_speed=125
dtparam=fan_temp1=55000,fan_temp1_hyst=4000,fan_temp1_speed=200
dtparam=fan_temp2=80000,fan_temp2_hyst=3000,fan_temp2_speed=255
dtoverlay=uart0-pi5

[cm5]
camera_auto_detect=0
dtparam=fan_temp0=40000,fan_temp0_hyst=5000,fan_temp0_speed=125
dtparam=fan_temp1=55000,fan_temp1_hyst=4000,fan_temp1_speed=200
dtparam=fan_temp2=80000,fan_temp2_hyst=3000,fan_temp2_speed=255
dtoverlay=uart0-pi5
dtoverlay=imx219,cam0
dtoverlay=ov5647,cam0
EOF

# One-shot: remove ourselves and reboot into the configured system
systemctl disable clover2-firstboot.service
rm -f /etc/systemd/system/clover2-firstboot.service
systemctl daemon-reload
rm -f /root/clover2_firstboot.sh
sync
reboot
