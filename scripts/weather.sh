#!/bin/bash
# Fetch weather data from wttr.in and cache to /tmp/conky-weather.txt
# Called by conky via ${execi 1800 ...} (every 30 minutes)
CACHE="/tmp/conky-weather.txt"

DATA=$(curl -s --max-time 10 "wttr.in/?format=j1" 2>/dev/null)

# Validate response
if [ -z "$DATA" ] || ! echo "$DATA" | jq -e '.current_condition[0]' >/dev/null 2>&1; then
    exit 1
fi

{
    # Current conditions
    echo "$DATA" | jq -r '.current_condition[0] |
    "TEMP=" + .temp_C +
    "\nFEELS=" + .FeelsLikeC +
    "\nHUMIDITY=" + .humidity +
    "\nDESC=" + .weatherDesc[0].value +
    "\nWIND=" + .windspeedKmph +
    "\nWIND_DIR=" + .winddir16Point +
    "\nPRECIP=" + .precipMM +
    "\nPRESSURE=" + .pressure +
    "\nUV=" + .uvIndex +
    "\nCLOUD=" + .cloudcover +
    "\nVISIBILITY=" + .visibility'

    # Location
    echo "$DATA" | jq -r '.nearest_area[0] |
    "LOCATION=" + .areaName[0].value + ", " + .country[0].value'

    # 3-day forecast
    for i in 0 1 2; do
        echo "$DATA" | jq -r ".weather[$i] |
        \"F${i}_MAX=\" + .maxtempC +
        \"\nF${i}_MIN=\" + .mintempC +
        \"\nF${i}_DESC=\" + .hourly[4].weatherDesc[0].value"
        echo "F${i}_DAY=$(date -d "+${i} days" +%A)"
    done
} > "$CACHE"
