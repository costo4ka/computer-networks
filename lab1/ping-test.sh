#!/bin/bash

domains=(
    "google.com"
    "microsoft.com"
    "github.com"
    "stackoverflow.com"
    "reddit.com"
    "amazon.com"
    "wikipedia.org"
    "cloudflare.com"
    "apple.com"
    "youtube.com"
)

echo "Domain,Status,RTT_stats,PacketLoss_percent,Ping_time" > ping_results.csv

for domain in "${domains[@]}"; do
    start_time=$(date +%s%3N) #кол-во миллисекунд

    ping_output=$(ping -c 4 -W 2 "$domain" 2>&1)

    end_time=$(date +%s%3N)

    ping_time=$((end_time - start_time))

    if [ $? -eq 0 ]; then
        rtt_line=$(echo "$ping_output" | grep "rtt min/avg/max/mdev")
        if [ -n "$rtt_line" ]; then
            rtt_stats=$(echo "$rtt_line" | awk '{print $4}')

            packet_loss=$(echo "$ping_output" | grep "packet loss" | awk '{print $6}' | cut -d'%' -f1)

            echo "$domain,Success,$rtt_stats,$packet_loss,$ping_time" >> ping_results.csv
        else
            echo "$domain,Failed,N/A,100,$ping_time" >> ping_results.csv
        fi
    else
        echo "$domain,Failed,N/A,100,$ping_time" >> ping_results.csv
    fi
done

echo "результаты сохранены в ping_results.csv"
