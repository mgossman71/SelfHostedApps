for i in /sys/class/net/*; do
  iface=$(basename "$i")
  [ -e "$i/device" ] || continue
  printf "%-12s " "$iface"
  ethtool "$iface" 2>/dev/null | awk -F': ' '/Speed:|Duplex:|Link detected:/ {printf "%s=%s ", $1, $2} END {print ""}'
done
