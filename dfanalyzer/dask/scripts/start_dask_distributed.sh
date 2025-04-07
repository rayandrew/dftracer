#!/bin/bash
set -x
source $HOME/.dftracer/configuration.sh
export PYTHONPATH=${DFTRACER_APP}:${PYTHONPATH}

hostname=`hostname`
DFTRACER_DASK_CONF_NAME="UNSET"
case $hostname in
  *"corona"*)
    DFTRACER_DASK_CONF_NAME=${DFTRACER_APP}/dfanalyzer/dask/conf/corona.yaml
    ;;
  *"ruby"*)
    DFTRACER_DASK_CONF_NAME=${DFTRACER_APP}/dfanalyzer/dask/conf/ruby.yaml
    ;;
  "quartz"*)
    DFTRACER_DASK_CONF_NAME=${DFTRACER_APP}/dfanalyzer/dask/conf/quartz.yaml
    ;;
  "polaris"*)
    DFTRACER_DASK_CONF_NAME=${DFTRACER_APP}/dfanalyzer/dask/conf/polaris.yaml
    ;;
esac

if [[ "$DFTRACER_DASK_CONF_NAME" == "UNSET" ]]; then
  echo "UNSUPPORTED $hostname"
  exit 1
fi

source ${DFTRACER_APP}/dfanalyzer/dask/scripts/utils.sh
eval $(parse_yaml $DFTRACER_DASK_CONF_NAME DFTRACER_)


source ${DFTRACER_ENV}/bin/activate

# Create necessary directories and validate
if ! mkdir -p ${DFTRACER_CONFIG_LOG_DIR}; then
    echo "Error: Failed to create DFTRACER_CONFIG_LOG_DIR (${DFTRACER_CONFIG_LOG_DIR})."
    echo "Please update the paths in ~/.dftracer/configuration.yaml."
    exit 1
fi

if ! mkdir -p ${DFTRACER_CONFIG_RUN_DIR}; then
    echo "Error: Failed to create DFTRACER_CONFIG_RUN_DIR (${DFTRACER_CONFIG_RUN_DIR})."
    echo "Please update the paths in ~/.dftracer/configuration.yaml."
    exit 1
fi

if [ ! -d "${DFTRACER_CONFIG_RUN_DIR}" ]; then
    echo "Error: ${DFTRACER_CONFIG_RUN_DIR} does not exist after attempting to create it. Check permissions or paths."
    exit 1
fi

echo "Using DFTRACER_CONFIG_RUN_DIR: ${DFTRACER_CONFIG_RUN_DIR}"

# Remove old scheduler JSON if it exists
rm -rf ${DFTRACER_CONFIG_RUN_DIR}/scheduler_${USER}.json

# Start Dask Scheduler
${DFTRACER_DASK_SCHEDULER} --scheduler-file ${DFTRACER_CONFIG_RUN_DIR}/scheduler_${USER}.json --port ${DFTRACER_SCHEDULER_PORT} > ${DFTRACER_CONFIG_LOG_DIR}/scheduler_${USER}.log 2>&1 &
scheduler_pid=$!
echo $scheduler_pid > ${DFTRACER_CONFIG_RUN_DIR}/scheduler_${USER}.pid

# Wait for scheduler JSON to be created (timeout after 30 seconds)
file=${DFTRACER_CONFIG_RUN_DIR}/scheduler_${USER}.json
timeout=30  # Time (seconds) to wait for the file
SECONDS=0

until [ -s "$file" ] || (( SECONDS >= timeout )); do
    sleep 1
done

if [ -f "$file" ]; then
    echo "Scheduler with PID $scheduler_pid is running."
else
    echo "Error: Scheduler with PID $scheduler_pid failed. Check ${DFTRACER_CONFIG_LOG_DIR}/scheduler_${USER}.log for details."
    exit 1
fi

# Remove old job PID file if it exists
rm -f ${DFTRACER_CONFIG_RUN_DIR}/job_id_${USER}.pid

# Start Dask Worker
${DFTRACER_SCHEDULER_CMD} ${DFTRACER_CONFIG_SCRIPT_DIR}/start_dask_worker.sh ${DFTRACER_DASK_CONF_NAME} ${hostname}
