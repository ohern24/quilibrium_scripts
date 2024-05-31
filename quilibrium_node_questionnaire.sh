cd ~/ceremonyclient/node
echo;
echo "Quilibrium Node Spec Questionnaire";
cpu_info=$(cat /proc/cpuinfo  | grep 'model name'| uniq | cut -f2- -d':'); echo "CPU: $cpu_info";
cpu_count=$(lscpu | grep 'Socket' | uniq | cut -d':' -f 2); cpu_count=${cpu_count//[[:blank:]]/}; if [[ cpu_count -gt 4 ]]; then cpu_count='Possible VPS/VDS Detected Put 1 CPU'; fi; echo 'CPU Count: '$cpu_count;
threads_info=$(cat /proc/cpuinfo  | grep process| wc -l); echo "vCores/Threads: $threads_info";
ram_info=$(dmidecode --type memory | less | grep -o "\<[1-1024].*\> GB"| uniq); echo "Total Ram: $ram_info"' (Double check your system/plan if it seems off)';
ram_type=$(lshw -class memory | grep 'description: DIMM' | uniq | cut -d':' -f 2); if [[ "$ram_type" == " DIMM RAM" ]]; then ram_type=' VPS/VDS'; else ram_type="${ram_type:5}"; fi; echo 'RAM Type:'$ram_type;
last_next_difficulty=$(journalctl -u ceremonyclient -ocat -n 100 | grep difficulty | awk -F'[:,}]' '{for(i=1;i<=NF;i++){if($i~"next_difficulty_metric"){gsub(/[ "]/,"",$i); print $(i+1)}}}' | tail -n 1); echo "Last Difficulty: $last_next_difficulty";
peer_id=$(./node-1.4.18-linux-amd64 -peer-id| grep 'Peer' | cut -d':' -f 2); echo 'Peer ID: '$peer_id;
echo;
echo 'Use  this information to fill out the questionnaire @ https://forms.gle/Zy2Ht91LLsMru5kN9';
