echo "[General]\nEnableNetworkConfiguration=true" >> /etc/iwd/main.conf
systemctl enable --now iwd
systemctl enable --now dhcpcd
dhcpcd wlan0

echo "Manually setup internet connection and run install3.sh"