#!/bin/bash

echo "Running create_log_dir.sh on $(hostname)" | tee -a "$LOG_FILE"
if [ "x$DFTRACER_VERSION" == "x" ]; then
    export DFTRACER_VERSION=$(python -c "import dftracer; print(dftracer.__version__)") || { echo "Failed to get DFTRACER_VERSION"; exit 1; }
fi
pushd "$LOG_STORE_DIR" || { echo "Failed to change directory to $LOG_STORE_DIR"; exit 1; }

LFS_DIR=v$DFTRACER_VERSION/$SYSTEM_NAME

if test -d "$LFS_DIR"; then
    echo "Branch $LFS_DIR Exists"
else
    if [ "$DFTRACER_VERSION" == "PR" ]; then
        module load mpifileutils 
        flux run -n48 drm "$LFS_DIR"
        mkdir -p "$LFS_DIR"
    else
        git clone "ssh://git@czgitlab.llnl.gov:7999/iopp/dftracer-traces.git" "$LFS_DIR" || { echo "Failed to clone repository"; exit 1; }
        cd "$LFS_DIR" || { echo "Failed to change directory to $LFS_DIR"; exit 1; }
        git checkout -b "$LFS_DIR" || { echo "Failed to create branch $LFS_DIR"; exit 1; }
        cd - || { echo "Failed to return to previous directory"; exit 1; }
    fi    
    cp "$LOG_STORE_DIR/v1.0.5-develop/corona/.gitattributes" . || { echo "Failed to copy .gitattributes"; exit 1; }
    cp "$LOG_STORE_DIR/v1.0.5-develop/corona/.gitignore" . || { echo "Failed to copy .gitignore"; exit 1; }
    cp "$LOG_STORE_DIR/v1.0.5-develop/corona/prepare_traces.sh" . || { echo "Failed to copy prepare_traces.sh"; exit 1; }
    cp "$LOG_STORE_DIR/v1.0.5-develop/corona/README.md" . || { echo "Failed to copy README.md"; exit 1; }
fi

popd || { echo "Failed to change directory from $LOG_STORE_DIR"; exit 1; }
