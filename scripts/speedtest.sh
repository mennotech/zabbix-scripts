#!/bin/bash

set -e

CACHE_FILE=/tmp/speedtest.log
LOCK_FILE=/tmp/speedtest.lock

SERVER_NUMBER=0
SERVER_ID[0]="3997"
SERVER_NAME[0]="Eolo"
SERVER_TR_DL[0]="25"
SERVER_TR_UL[0]="2.5"
SERVER_ID[1]="4318"
SERVER_NAME[1]="Tiscali"
SERVER_TR_DL[1]="6"
SERVER_TR_UL[1]="0.6"
SERVER_ID[2]="5502"
SERVER_NAME[2]="Linkem"
SERVER_TR_DL[2]="10"
SERVER_TR_UL[2]="1.5"

run_speedtest() {
        # Lock
        if [ -e "$LOCK_FILE" ]
        then
                echo "A speedtest is already running" >&2
                exit 2
        fi
        touch "$LOCK_FILE"

        #Invoke rm LOCK_FILE on exit
        trap "rm -rf $LOCK_FILE" EXIT HUP INT QUIT PIPE TERM

        #Variable declaration
        local output timestamp server_id server_sponsor country location ping download upload

        #Check if argument supplied to function, exec speedtest command and save output
        if [ -z "$1" ]
        then
                output=$(speedtest --json)
        else
                output=$(speedtest --server "$1" --json)
                CACHE_FILE+="_$1"
        fi

        #Debug
        #echo "Output: $output"

        # Extract fields
        timestamp=$(echo "$output" | jq '.timestamp' )
        server_id=$(echo "$output" | jq '.server.id' )
        server_sponsor=$(echo "$output" | jq '.server.sponsor' )
        country=$(echo "$output" | jq '.server.country' )
        location=$(echo "$output" | jq '.server | {lon, lat}' )

        #Extract and convert with only two decimal
        ping=$(echo "$output" | jq '.ping' | awk '{ printf("%.2f\n", $1) }')
        #Extract and convert to Mbit/s with only two decimal
        download=$(echo "$output" | jq '.download' | awk '{ printf("%.2f\n", $1 / 1000000) }')
        upload=$(echo "$output" | jq '.upload' | awk '{ printf("%.2f\n", $1 / 1000000) }')

        #Send value to CACHE_FILE
        {
                echo "Timestamp: $timestamp"
                echo "Country: $country"
                echo "ServerID: $server_id"
                echo "ServerSponsor: $server_sponsor"
                echo "Location: $location"
                echo "Ping: $ping ms"
                echo "Download: $download Mbit/s"
                echo "Upload: $upload Mbit/s"
        } > "$CACHE_FILE"

        CACHE_FILE=/tmp/speedtest.log

        # Make sure to remove the lock file (may be redundant)
        rm -rf "$LOCK_FILE"
}

display_help() {
        echo "Usage with this parameters"
        echo
        echo "                          Run the speedtest collector with default setting (best server)"
        echo "   -l xxx                 Run the speedtest collector on the server with id xxx"
        echo "   -a, --all              Run the speedtest collector on the all servers listed in array and the best server"
        echo "   -g, --get-all          Get all server on which run the speedtest with -a"
        echo "   -c, --cached           Get the result for the last speedtest with default setting"
        echo "   -u, --upload           Get the upload speed for the last speedtest with default setting"
        echo "   -d, --download         Get the download speed for the last speedtest with default setting"
        echo "   -p, --ping             Get the ping value for the last speedtest with default setting"
        echo "   -f, --force            Force delete of lock and run the speedtest collector"
        echo "   -h, --help             View this help"
        echo "   -[c|u|d|p] -l xxx      Get the result for the last speedtest on the server with id xxx"
        echo
}

check_cache_exist() {
        if [ ! -e "$1" ]
        then
                echo "Not yet runned the speedtest" >&2
                exit 2
        fi
}

if [ $# -eq 0 ] || [ $# -eq 1 ]
then
        case "$1" in
                -c|--cached)
                        check_cache_exist "$CACHE_FILE"
                        cat "$CACHE_FILE"
                        ;;
                -u|--upload)
                        check_cache_exist "$CACHE_FILE"
                        awk '/Upload/ { print $2 }' "$CACHE_FILE"
                        ;;
                -d|--download)
                        check_cache_exist "$CACHE_FILE"
                        awk '/Download/ { print $2 }' "$CACHE_FILE"
                        ;;
                -p|--ping)
                        check_cache_exist "$CACHE_FILE"
                        awk '/Ping/ { print $2 }' "$CACHE_FILE"
                        ;;
                -f|--force)
                        rm -rf "$LOCK_FILE"
                        run_speedtest
                        ;;
                -a|--all)
                        run_speedtest
                        for (( c=0; c<$SERVER_NUMBER; c++ ))
                        do
                                run_speedtest "${SERVER_ID[$c]}"
                        done
                        ;;
                -g|--get-all)
                        echo "{"
                        echo "\"data\":["
                        comma=""
                        for (( c=0; c<$SERVER_NUMBER; c++ ))
                        do
                                echo "    $comma{\"{#SERVERID}\":\"${SERVER_ID[$c]}\",\"{#SERVERNAME}\":\"${SERVER_NAME[$c]}\",\"{#SERVER_TR_DL}\":\"${SERVER_TR_DL[$c]}\",\"{#SERVER_TR_UL}\":\"${SERVER_TR_UL[$c]}\"}"
                                comma=","
                        done
                        echo "]"
                        echo "}"
                        ;;
                -h|--help)
                        display_help
                        ;;
                *)
                        run_speedtest
                        ;;
        esac
elif [ $# -eq 2 ]
then
        if [ $1 = "-l" ]
        then
                run_speedtest "$2"
        fi
elif [ $# -eq 3 ]
then
        if [ $2 = "-l" ]
        then
                case "$1" in
                        -c|--cached)
                                check_cache_exist "$CACHE_FILE"_"$3"
                                cat "$CACHE_FILE"_"$3"
                                ;;
                        -u|--upload)
                                check_cache_exist "$CACHE_FILE"_"$3"
                                awk '/Upload/ { print $2 }' "$CACHE_FILE"_"$3"
                                ;;
                        -d|--download)
                                check_cache_exist "$CACHE_FILE"_"$3"
                                awk '/Download/ { print $2 }' "$CACHE_FILE"_"$3"
                                ;;
                        -p|--ping)
                                check_cache_exist "$CACHE_FILE"_"$3"
                                awk '/Ping/ { print $2 }' "$CACHE_FILE"_"$3"
                                ;;
                esac
        fi
fi
