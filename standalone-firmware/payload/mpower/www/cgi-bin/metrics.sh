#!/bin/sh
printf 'Content-Type: text/plain; version=0.0.4\r\nCache-Control: no-store\r\n\r\n'
printf '# HELP mpower_outlet_power_watts Active power measured at outlet.\n# TYPE mpower_outlet_power_watts gauge\n'
printf '# HELP mpower_outlet_energy_wh Total delivered energy since device counter reset.\n# TYPE mpower_outlet_energy_wh counter\n'
printf '# HELP mpower_outlet_relay Relay state, 1 for on and 0 for off.\n# TYPE mpower_outlet_relay gauge\n'
for port in 1 2 3; do
  power=0; [ -r /proc/power/active_pwr$port ] && read power < /proc/power/active_pwr$port
  energy=0; [ -r /proc/power/energy_sum$port ] && read energy < /proc/power/energy_sum$port
  relay=0; [ -r /proc/power/relay$port ] && read relay < /proc/power/relay$port
  printf 'mpower_outlet_power_watts{outlet="%s"} %s\n' "$port" "$power"
  printf 'mpower_outlet_energy_wh{outlet="%s"} %s\n' "$port" "$energy"
  printf 'mpower_outlet_relay{outlet="%s"} %s\n' "$port" "$relay"
done
