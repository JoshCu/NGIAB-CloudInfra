#!/bin/bash
# ANSI color codes
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
MAGENTA='\e[35m'
CYAN='\e[36m'
RESET='\e[0m'

workdir="${1:-/ngen}"
cd "${workdir}" || { echo -e "${RED}Failed to change directory to ${workdir}${RESET}"; exit 1; }
set -e
echo -e "${CYAN}Working directory is:${RESET}"
pwd
echo -e "\n"



# Function to automatically select file if only one is found
auto_select_file() {
  local files=($1)
  if [ "${#files[@]}" -eq 1 ]; then
    echo "${files[0]}"
  else
    echo ""
  fi
}

# Finding files
HYDRO_FABRIC_CATCHMENTS=$(find . -name "*.gpkg")
HYDRO_FABRIC_NEXUS=$(find . -name "*.gpkg")
NGEN_REALIZATIONS=$(find . -name "*realization*.json")

# Auto-selecting files if only one is found
selected_catchment=$(auto_select_file "$HYDRO_FABRIC_CATCHMENTS")
selected_nexus=$(auto_select_file "$HYDRO_FABRIC_NEXUS")
selected_realization=$(auto_select_file "$NGEN_REALIZATIONS")

# Displaying found files
echo -e "${BLUE}\e[4mFound these Catchment files:${RESET}" && echo "$HYDRO_FABRIC_CATCHMENTS" || echo -e "${RED}No Catchment files found.${RESET}"
echo -e "\n"
echo -e "${MAGENTA}\e[4mFound these Nexus files:${RESET}" && echo "$HYDRO_FABRIC_NEXUS" || echo -e "${RED}No Nexus files found.${RESET}"
echo -e "\n"
echo -e "${CYAN}\e[4mFound these Realization files:${RESET}" && echo "$NGEN_REALIZATIONS" || echo -e "${RED}No Realization files found.${RESET}"
echo -e "\n"

no_remotes=$(grep "remotes_enabled" $selected_realization | grep false | wc -l)

generate_partition() {
    # Store the grep result (0 if "false" is found, 1 if not)    
    
    if [ "$no_remotes" -eq 0 ]; then
        # Use the original partition generator
        /dmod/bin/partitionGenerator "$1" "$2" "partitions_$3.json" "$3" '' ''
    else
        # Use the round-robin partitioning
        python /dmod/utils/partitioning/round_robin_partioning.py -n $3 $1 partitions_$3.json
    fi
}


if [ "$no_remotes" -eq 1 ]; then
        sed -i 's/"routing"/"routing_disabled"/g' $selected_realization
fi

if [ "$2" == "auto" ]
  then
    echo "AUTO MODE ENGAGED"
    echo "Running NextGen model framework in parallel mode"
    if [ -z "$3" ]; then
      procs=$(($(nproc) - 2))
    else
      procs=$3
    fi

    partitions=$(find . -name "*partitions_$procs.json")
    if [[ -z $partitions ]]; then
      echo "No partitions file found, generating..."
      generate_partition "$selected_catchment" "$selected_nexus" "$procs" "$selected_realization"
    else
      echo "Found paritions file! "$partitions
    fi
    rm -f /ngen/ngen/data/outputs/ngen/*.csv
    mpirun -n $procs /dmod/bin/ngen-parallel $selected_catchment all $selected_nexus all $selected_realization $(pwd)/partitions_$procs.json
    #TODO run troute manually if remotes were disabled
    if [ "$no_remotes" -eq 1 ]; then
        grep "routing_disabled" $selected_realization >> /dev/null
	routing_used=$?
	sed -i 's/"routing_disabled"/"routing"/g' $selected_realization
        ts-merger /ngen/ngen/data/outputs/ngen/ _output.csv nex-
        if [ "$routing_used" -eq 0 ]; then
            python -m nwm_routing -V4 -f /ngen/ngen/data/config/troute.yaml
        fi
    fi
    echo "Run completed successfully, exiting, have a nice day!"
    exit 0
  else
    echo "Entering Interactive Mode"    
fi

echo -e "${YELLOW}Select an option (type a number): ${RESET}"
options=("Run NextGen model framework in serial mode" "Run NextGen model framework in parallel mode" "Run Bash shell" "Exit")
select option in "${options[@]}"; do
  case $option in
    "Run NextGen model framework in serial mode"|"Run NextGen model framework in parallel mode")
      echo -e "\n"
      n1=${selected_catchment:-$(read -p "Enter the hydrofabric catchment file path: " n1; echo "$n1")}
      n2=${selected_nexus:-$(read -p "Enter the hydrofabric nexus file path: " n2; echo "$n2")}
      n3=${selected_realization:-$(read -p "Enter the Realization file path: " n3; echo "$n3")}

      echo -e "${GREEN}Selected files:\nCatchment: $n1\nNexus: $n2\nRealization: $n3${RESET}\n"

      if [ "$option" == "Run NextGen model framework in parallel mode" ]; then
        procs=$(nproc)
        # num_catchments=$(find forcings -name *.csv | wc -l)
        # if [ $num_catchments -lt $procs ]; then
        #         procs=$num_catchments
        # fi
        generate_partition "$n1" "$n2" "$procs" "$n3"
        run_command="mpirun -n $procs /dmod/bin/ngen-parallel $n1 all $n2 all $n3 $(pwd)/partitions_$procs.json"
      else
        run_command="/dmod/bin/ngen-serial $n1 all $n2 all $n3"
      fi

      echo -e "${YELLOW}Your NGEN run command is $run_command${RESET}"
      break
      ;;
    "Run Bash shell")
      echo -e "${CYAN}Starting a shell, simply exit to stop the process.${RESET}"
      /bin/bash
      exit 0
      ;;
    "Exit")
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option $REPLY${RESET}"
      ;;
  esac
done

echo -e "${GREEN}If your model didn't run, or encountered an error, try checking the Forcings paths in the Realizations file you selected.${RESET}"
# Ask user if they want to redirect output to /dev/null
echo -e "${YELLOW}Do you want to redirect command output to /dev/null? (y/N, default: n):${RESET}"
read -r redirect_choice

# Execute the command
if [[ "$redirect_choice" == [Yy]* ]]; then
    echo -e "${GREEN}Redirecting output to /dev/null.${RESET}"
    time $run_command > /dev/null 2>&1
else
    time $run_command
fi
command_status=$?


#TODO run troute manually if remotes were disabled
if [ "$no_remotes" -eq 1 ]; then
    grep "routing_disabled" $selected_realization >> /dev/null
    routing_used=$?
    sed -i 's/"routing_disabled"/"routing"/g' $selected_realization
    ts-merger /ngen/ngen/data/outputs/ngen/ _output.csv nex-
    if [ "$routing_used" -eq 1 ]; then
        python -m nwm_routing -V4 -f /ngen/ngen/data/config/troute.yaml
    fi
fi

# Set message color based on command status
if [ $command_status -eq 0 ]; then
    color=$GREEN
    message="Finished executing command successfully."
else
    color=$RED
    message="Command execution failed with exit code $command_status."
fi

echo -e "${color}${message}${RESET}"

echo -e "${YELLOW}Would you like to continue?${RESET}"
echo -e "${YELLOW}Select an option (type a number): ${RESET}"
options=("Interactive-Shell" "Exit")
select option in "${options[@]}"; do
  case $option in
    "Interactive-Shell")
      echo -e "${CYAN}Starting a shell, simply exit to stop the process.${RESET}"
      /bin/bash
      break
      ;;
    "Exit")
      echo -e "${GREEN}Have a nice day.${RESET}"
      break
      ;;
    *)
      echo -e "${RED}Invalid option $REPLY${RESET}"
      ;;
  esac
done
exit
