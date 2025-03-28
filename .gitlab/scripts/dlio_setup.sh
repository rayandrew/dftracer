#!/bin/bash

set -e  # Exit on any error
set -x  # Print each command before executing it

trap 'echo "Error occurred at line $LINENO"; exit 1' ERR

echo "Checking if $DATA_PATH is empty..."
if [ -z "$DATA_PATH" ]; then
    echo "Empty $DATA_PATH"
    exit 1
fi

echo "Cleaning output folder"
mkdir -p $CUSTOM_CI_OUTPUR_DIR
rm -rf "${CUSTOM_CI_OUTPUR_DIR:?}"/*

echo "Finding configurations"
dlio_path=$(dirname "$(python -c "import dlio_benchmark; print(dlio_benchmark.__file__);")")
config_path="$dlio_path/configs/workload/"
DLIO_WORKLOADS=$(find "$config_path" -maxdepth 1 -type f -name "*.yaml" -exec basename {} .yaml \; | sed ':a;N;$!ba;s/\n/ /g' | sed 's/default //g')
export DLIO_WORKLOADS=($DLIO_WORKLOADS)
echo "Found ${#DLIO_WORKLOADS[@]} configurations"


