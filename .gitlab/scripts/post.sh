#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status
set -x  # Print each command before executing it

echo "Running post.sh on $(hostname)"

export DFTRACER_VERSION=$(python -c "import dftracer; print(dftracer.__version__)") || { echo "Failed to get DFTRACER_VERSION"; exit 1; }

pushd $LOG_STORE_DIR || { echo "Failed to change directory to $LOG_STORE_DIR"; exit 1; }

SYSTEM=$(hostname | sed 's/[0-9]//g') || { echo "Failed to determine SYSTEM"; exit 1; }

LFS_DIR=v$DFTRACER_VERSION/$SYSTEM

if test -d $LFS_DIR; then
    echo "Branch $LFS_DIR Exists"
else
    git clone ssh://git@czgitlab.llnl.gov:7999/iopp/dftracer-traces.git $LFS_DIR || { echo "Failed to clone repository"; exit 1; }
    cd $LFS_DIR || { echo "Failed to change directory to $LFS_DIR"; exit 1; }
    git checkout -b $LFS_DIR || { echo "Failed to create branch $LFS_DIR"; exit 1; }
    cp $LOG_STORE_DIR/v1.0.5-develop/corona/.gitattributes . || { echo "Failed to copy .gitattributes"; exit 1; }
    cp $LOG_STORE_DIR/v1.0.5-develop/corona/.gitignore . || { echo "Failed to copy .gitignore"; exit 1; }
    cp $LOG_STORE_DIR/v1.0.5-develop/corona/prepare_traces.sh . || { echo "Failed to copy prepare_traces.sh"; exit 1; }
    cp $LOG_STORE_DIR/v1.0.5-develop/corona/README.md . || { echo "Failed to copy README.md"; exit 1; }
    git commit -a -m "added initial files" || { echo "Failed to commit files"; exit 1; }
    git push origin $LFS_DIR || { echo "Failed to push branch $LFS_DIR"; exit 1; }
    cd - || { echo "Failed to return to previous directory"; exit 1; }
fi

cd $LFS_DIR || { echo "Failed to change directory to $LFS_DIR"; exit 1; }
index=0
for workload in "${DLIO_WORKLOADS[@]}"; do
    output=$CUSTOM_CI_OUTPUR_DIR/$workload/$CI_RUNNER_SHORT_TOKEN/train
    num_trace_files=$(find $output -name *.pfw.gz | wc -l)
    if [ $num_trace_files -eq 0 ]; then
        echo "No trace files found for workload $workload"
        continue
    fi
    echo "Copying trace files for workload $workload"
    workload_dir=$(echo $workload | sed 's/_/\//g') || { echo "Failed to process workload directory"; exit 1; }
    echo "workload_dir is $workload_dir"
    mkdir -p $workload_dir/node-${WORKLOAD_NODES[$index]}/ || { echo "Failed to create directory $workload_dir/node-${WORKLOAD_NODES[$index]}/"; exit 1; }
    current_versions=$(find $workload_dir/node-${WORKLOAD_NODES[$index]}/ -name v* | wc -l) || { echo "Failed to find current versions"; exit 1; }
    current_version=$((current_versions + 1))
    mkdir -p $workload_dir/node-${WORKLOAD_NODES[$index]}/v${current_version}/RAW || { echo "Failed to create RAW directory"; exit 1; }
    cmd="mv $output/*.pfw.gz $workload_dir/node-${WORKLOAD_NODES[$index]}/v${current_version}/RAW/"
    echo $cmd
    $cmd || { echo "Failed to move trace files"; exit 1; }

    cmd="mv $output/.hydra $workload_dir/node-${WORKLOAD_NODES[$index]}/v${current_version}/"
    echo $cmd
    $cmd || { echo "Failed to move .hydra folder"; exit 1; }
    
    cd $workload_dir/node-${WORKLOAD_NODES[$index]}/v${current_version}/ || { echo "Failed to change directory to $workload_dir/node-${WORKLOAD_NODES[$index]}/v${current_version}"; exit 1; }
    

    index=$((index + 1))
    # echo "Compacting $(ls *.pfw.gz 2>/dev/null | wc -l) dftracer files"
    # cmd="dftracer_split -d $PWD/RAW -o $PWD/COMPACT/ -s 1024 -n $workload"
    # echo "Generated command: $cmd"
    # $cmd || { echo "Failed to compact dftracer files"; exit 1; }

    # cmd="tar -cvf RAW.tar.gz RAW"
    # echo "Generated command: $cmd"
    # $cmd || { echo "Failed to create RAW.tar.gz"; exit 1; }
    
    # cmd="tar -cvf COMPACT.tar.gz COMPACT"
    # echo "Generated command: $cmd"
    # $cmd || { echo "Failed to create COMPACT.tar.gz"; exit 1; }

    cd - || { echo "Failed to return to previous directory";continue; }
done

cd - || { echo "Failed to return to previous directory"; exit 1; }