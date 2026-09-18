#!/usr/bin/env bash
#
# Clover2 first boot (runs once from clover2-firstboot.service).
#
# Scope: clover2-specific setup only — Wi-Fi AP + hostname and preloading
# docker images. Everything else is handled by armbian itself:
# rootfs growth (armbian-resize-filesystem.service), ssh host keys and
# image uuid (armbian-firstrun.service), user/locale wizard
# (armbian-firstlogin via /root/.not_logged_in_yet).
#
# The docker-compose.yaml is pre-generated at image build time by the
# clover2-docker extension — do not regenerate it here.

set -u

# Wi-Fi access point + matching hostname; only when a wireless card exists
# (development/VM images have none)
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

# One-shot: remove ourselves and reboot into the configured system
systemctl disable clover2-firstboot.service
rm -f /etc/systemd/system/clover2-firstboot.service
systemctl daemon-reload
rm -f /root/clover2_firstboot.sh
sync
reboot
