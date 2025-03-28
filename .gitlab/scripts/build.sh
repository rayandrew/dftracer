#!/bin/bash

LOG_FILE="$PWD/build.log"

echo "Running build.sh on $(hostname)" | tee -a "$LOG_FILE"

# shellcheck source=/dev/null

export site=$(ls -d $CUSTOM_CI_ENV_DIR/$ENV_NAME/lib/python*/site-packages/ 2>>"$LOG_FILE")

echo "Remove preinstall version of dlio_benchmark" | tee -a "$LOG_FILE"
echo "Command: pip uninstall dlio_benchmark" | tee -a "$LOG_FILE"
set -x
pip uninstall -y dlio_benchmark >>"$LOG_FILE" 2>&1
set +x
if [ $? -ne 0 ]; then
    echo "Failed to uninstall dlio_benchmark. Check the log file: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

set -x
rm -rf $site/*dlio_benchmark* >>"$LOG_FILE" 2>&1
set +x
if [ $? -ne 0 ]; then
    echo "Failed to remove dlio_benchmark files. Check the log file: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Installing DLIO benchmark with url git+$DLIO_BENCHMARK_REPO@$DLIO_BENCHMARK_TAG" | tee -a "$LOG_FILE"
echo "Command: pip install --no-cache-dir git+$DLIO_BENCHMARK_REPO@$DLIO_BENCHMARK_TAG" | tee -a "$LOG_FILE"
set -x
pip install --no-cache-dir git+$DLIO_BENCHMARK_REPO@$DLIO_BENCHMARK_TAG >>"$LOG_FILE" 2>&1
set +x
if [ $? -ne 0 ]; then
    echo "Failed to install DLIO benchmark. Check the log file: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Remove preinstall version of dftracer" | tee -a "$LOG_FILE"
echo "Command: pip uninstall pydftracer" | tee -a "$LOG_FILE"
set -x
pip uninstall -y pydftracer >>"$LOG_FILE" 2>&1
set +x
if [ $? -ne 0 ]; then
    echo "Failed to uninstall pydftracer. Check the log file: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

set -x
rm -rf $site/*dftracer* >>"$LOG_FILE" 2>&1
set +x
if [ $? -ne 0 ]; then
    echo "Failed to remove dftracer files. Check the log file: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Installing DFTracer" | tee -a "$LOG_FILE"
echo "Command: pip install --no-cache-dir --force-reinstall git+${DFTRACER_REPO}@${CI_COMMIT_REF_NAME}" | tee -a "$LOG_FILE"
set -x
pip install --no-cache-dir --force-reinstall git+${DFTRACER_REPO}@${CI_COMMIT_REF_NAME} >>"$LOG_FILE" 2>&1
set +x
if [ $? -ne 0 ]; then
    echo "Failed to install DFTracer. Check the log file: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

python -c "import dftracer; import dftracer.logger; print(dftracer.__version__);"
export PATH=$site/dftracer/bin:$PATH