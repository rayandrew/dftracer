#!/bin/bash

# Enable debugging to echo commands being run
set -x

# Print the hostname where the script is being executed
echo "Running pre.sh on $(hostname) by $USER on $PWD"

# Load the required modules for Python, MPI, and GCC
echo "Loading modules: Python ($PYTHON_MODULE), MPI ($MPI_MODULE), and GCC ($GCC_MODULE)"
module load $PYTHON_MODULE $MPI_MODULE $GCC_MODULE
if [ $? -ne 0 ]; then
    echo "Error: Failed to load modules."
    exit 1
fi

# Check the values of the loaded modules
echo "PYTHON_MODULE: $PYTHON_MODULE"
echo "MPI_MODULE: $MPI_MODULE"
echo "GCC_MODULE: $GCC_MODULE"

# Check the values of the environment variables
echo "CUSTOM_CI_ENV_DIR: $CUSTOM_CI_ENV_DIR"
echo "ENV_NAME: $ENV_NAME"

# Create a new Python virtual environment (if not exist) in the specified directory
if [[ ! -d $CUSTOM_CI_ENV_DIR/$ENV_NAME ]]; then
    echo "Creating a new Python virtual environment at $CUSTOM_CI_ENV_DIR/$ENV_NAME"
    python -m venv $CUSTOM_CI_ENV_DIR/$ENV_NAME
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create Python virtual environment."
        exit 1
    fi
fi

# Activating environment
echo "Activating env at $CUSTOM_CI_ENV_DIR/$ENV_NAME"
. $CUSTOM_CI_ENV_DIR/$ENV_NAME/bin/activate
if [ $? -ne 0 ]; then
    echo "Error: Failed to activate Python virtual environment."
    exit 1
fi

# Upgrade pip
pip install --upgrade pip
if [ $? -ne 0 ]; then
    echo "Error: Failed to upgrade pip."
    exit 1
fi


echo "Defining scheduler function..."
scheduler() {
    hostname=$(hostname)
    case $hostname in
        *"corona"*)
            echo "Setting SCHEDULER_CMD for hostname containing 'corona'..."
            SCHEDULER_CMD=(flux submit -N $1 --tasks-per-node=$2 -q $QUEUE -t $WALLTIME --exclusive)
            ;;
        *)
            echo "Unknown hostname: $hostname"
            exit 1
            ;;
    esac
}

pip install -r .gitlab/scripts/requirements.txt

# Disable debugging
set +x