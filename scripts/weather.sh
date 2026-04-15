#!/bin/bash
# Fetch weather data from wttr.in and cache to /tmp/conky-weather.txt
# Called by conky via ${execi 1800 ...} (every 30 minutes)
CACHE="/tmp/conky-weather.txt"

DATA=$(curl -s --max-time 10 "wttr.in/?format=j1" 2>/dev/null)

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
    "\nCODE=" + .weatherCode +
    "\nWIND=" + .windspeedKmph +
    "\nWIND_DIR=" + .winddir16Point +
    "\nWIND_DEG=" + .winddirDegree +
    "\nPRECIP=" + .precipMM +
    "\nPRESSURE=" + .pressure +
    "\nUV=" + .uvIndex +
    "\nCLOUD=" + .cloudcover +
    "\nVISIBILITY=" + .visibility'

    # Location
    echo "$DATA" | jq -r '.nearest_area[0] |
    "LOCATION=" + .areaName[0].value + ", " + .country[0].value'

    # Astronomy (today)
    echo "$DATA" | jq -r '.weather[0].astronomy[0] |
    "SUNRISE=" + .sunrise +
    "\nSUNSET=" + .sunset +
    "\nMOON=" + .moon_phase'

    # 3-day forecast (max/min/desc/code)
    for i in 0 1 2; do
        echo "$DATA" | jq -r ".weather[$i] |
        \"F${i}_MAX=\" + .maxtempC +
        \"\nF${i}_MIN=\" + .mintempC +
        \"\nF${i}_DESC=\" + .hourly[4].weatherDesc[0].value +
        \"\nF${i}_CODE=\" + .hourly[4].weatherCode"
        echo "F${i}_DAY=$(date -d "+${i} days" +%A)"
    done

    # Hourly forecast — next 24h (8 points, every 3h) starting from current time slot
    NOW_H=$(date +%H)
    START_IDX=$(( 10#$NOW_H / 3 ))
    IDX=0
    for d in 0 1; do
        for h in 0 1 2 3 4 5 6 7; do
            if [ "$d" = "0" ] && [ "$h" -lt "$START_IDX" ]; then continue; fi
            [ "$IDX" -ge 8 ] && break 2
            HOUR_LABEL=$(printf "%02d" $((h*3)))
            echo "$DATA" | jq -r ".weather[$d].hourly[$h] |
            \"H${IDX}_T=\" + .tempC +
            \"\nH${IDX}_P=\" + .precipMM +
            \"\nH${IDX}_C=\" + .weatherCode"
            echo "H${IDX}_H=${HOUR_LABEL}"
            IDX=$((IDX+1))
        done
    done
} > "$CACHE"
