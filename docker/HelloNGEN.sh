#!/bin/bash
workdir="${1:-/ngen}"
cd "${workdir}" || { echo -e "\e[31mFailed to change directory to ${workdir}\e[0m"; exit 1; }
set -e
echo -e "\e[36mWorking directory is:\e[0m"
pwd
echo -e "\n"

# ANSI color codes
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
MAGENTA='\e[35m'
CYAN='\e[36m'
RESET='\e[0m'

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
HYDRO_FABRIC_CATCHMENTS=$(find . -name "*catchment*.geojson")
HYDRO_FABRIC_NEXUS=$(find . -name "*nexus*.geojson")
NGEN_REALIZATIONS=$(find . -name "*realization*.json")

# Auto-selecting files if only one is found
selected_catchment=$(auto_select_file "$HYDRO_FABRIC_CATCHMENTS")
selected_nexus=$(auto_select_file "$HYDRO_FABRIC_NEXUS")
selected_realization=$(auto_select_file "$NGEN_REALIZATIONS")

# Displaying found files
echo -e "${BLUE}\e[4mFound these Catchment files:\e[0m${RESET}" && echo "$HYDRO_FABRIC_CATCHMENTS" || echo -e "${RED}No Catchment files found.${RESET}"
echo -e "\n"
echo -e "${MAGENTA}\e[4mFound these Nexus files:\e[0m${RESET}" && echo "$HYDRO_FABRIC_NEXUS" || echo -e "${RED}No Nexus files found.${RESET}"
echo -e "\n"
echo -e "${CYAN}\e[4mFound these Realization files:\e[0m${RESET}" && echo "$NGEN_REALIZATIONS" || echo -e "${RED}No Realization files found.${RESET}"
echo -e "\n"

generate_partition() {
  /dmod/bin/partitionGenerator "$1" "$2" "partitions_$3.json" "$3" '' ''
}

PS3="${YELLOW}Select an option (type a number): ${RESET}"
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
        procs=2 # Temporary fixed value
        generate_partition "$n1" "$n2" "$procs"
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
echo -e "${GREEN}Your model run is beginning!${RESET}"
$run_command

echo -e "${YELLOW}Would you like to continue?${RESET}"
PS3="${YELLOW}Select an option (type a number): ${RESET}"
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
