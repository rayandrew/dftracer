#!/bin/bash

set -e  # Exit on any error
set -x  # Print each command before executing it

trap 'echo "Error occurred at line $LINENO"; exit 1' ERR



echo "Cloning DLIO benchmark repository..."
git clone -b "${DLIO_BENCHMARK_TAG}" "${DLIO_BENCHMARK_REPO}"

echo "Listing workloads from DLIO benchmark configs..."
DLIO_WORKLOADS=$(ls dlio_benchmark/dlio_benchmark/configs/workload/ | sed 's/\.yaml//g' | sed ':a;N;$!ba;s/\n/ /g' | sed 's/default //g')
echo "Workloads: $DLIO_WORKLOADS"

echo "Converting workloads to array..."
export DLIO_WORKLOADS=($DLIO_WORKLOADS)
echo "Workloads array: ${DLIO_WORKLOADS[@]}"

export WORKLOAD_JOB_IDS=()
COMPRESS_JOB_IDS=()
export WORKLOAD_NODES=()
echo "Starting workload loop..."
for workload in "${DLIO_WORKLOADS[@]}"; do
    echo "Processing workload: $workload"
    output=$CUSTOM_CI_OUTPUR_DIR/$workload/$CI_RUNNER_SHORT_TOKEN
    mkdir -p $output/generate/ $output/train/
    echo "Output folder: $output"

    echo "Creating Data folder $DATA_PATH/$workload"
    mkdir -p $DATA_PATH/$workload

    echo "Removing Checkpoint folder $DATA_PATH/$workload/checkpoint"
    rm -rf $DATA_PATH/$workload/checkpoint

    echo "Disabling DFTracer logs..."
    export DFTRACER_ENABLE=0
    
    echo "Setting args for workload:$workload"
    override_args=(++workload.dataset.data_folder="$DATA_PATH/$workload/data" ++workload.checkpoint.checkpoint_folder="$DATA_PATH/$workload/checkpoint" ++workload.output.folder="$output/generate/" ++workload.train.epochs=1)
    
    echo "Query workload configurations"
    tp_size=$(dlio_benchmark_query workload=$workload "${override_args[@]}" ++workload.workflow.query="model.parallelism.tensor")
    pp_size=$(dlio_benchmark_query workload=$workload "${override_args[@]}" ++workload.workflow.query="model.parallelism.pipeline")
    num_gpus=$((tp_size*pp_size))
    if [[ "$num_gpus" == 1 ]]; then
        NODES=1
        GPUS=8
    else
        NODES=$((num_gpus / GPUS))
    fi
    export WORKLOAD_NODES+=("$NODES")

    if [[ $NODES -gt $MAX_NODES ]]; then
        echo "$NODES are too large for $(hostname) cluster."
        export WORKLOAD_JOB_IDS+=("None")
        export COMPRESS_JOB_IDS+=("None")
    continue
    fi
    # NODES=4
    
    if [ -d "$DATA_PATH/$workload/data" ]; then
        echo "$DATA_PATH/$workload exists. Not generating data."
        unset generate_data
    else
        echo "Generating data for workload..."
        scheduler $NODES "$CORES"
        cmd="${SCHEDULER_CMD[@]} --job-name gen_${workload} dlio_benchmark workload=$workload ++workload.workflow.generate_data=True ++workload.workflow.train=False ${override_args[@]}"
        echo "Running command: $cmd"
        $cmd
        generate_data="--dependency=afterany:$(flux job last)"
    fi

    echo "Enabling DFTracer logs..."
    export DFTRACER_ENABLE=1
    export DFTRACER_INC_METADATA=1
    override_args=(++workload.dataset.data_folder="$DATA_PATH/$workload/data" ++workload.checkpoint.checkpoint_folder="$DATA_PATH/$workload/checkpoint" ++workload.output.folder="$output/train/" ++workload.train.epochs=1 hydra.run.dir="$output/train/")
    
    scheduler $NODES "$GPUS"
    echo "Running training for workload..."
    cmd="${SCHEDULER_CMD[@]} $generate_data --job-name train_${workload} dlio_benchmark workload=$workload ++workload.workflow.generate_data=False ++workload.workflow.train=True ${override_args[@]}"
    echo "Running command: $cmd"
    $cmd
    train_data=$(flux job last)
    echo "Disabling DFTracer logs..."
    export DFTRACER_ENABLE=0

    export WORKLOAD_JOB_IDS+=("$train_data")
    scheduler 1 "$CORES"
    echo "Compressing $(ls "$output"/*.pfw | wc -l) DFTracer files"
    cmd="${SCHEDULER_CMD[@]} --dependency=afterany:$train_data --job-name comp_${workload} dftracer_pgzip -d $output/train"
    echo "Running command: $cmd"
    $cmd

    compress_data=$(flux job last)
    COMPRESS_JOB_IDS+=("$compress_data")

    echo "Removing Checkpoint folder $DATA_PATH/$workload/checkpoint"
    cmd="${SCHEDULER_CMD[@]} --dependency=afterany:$train_data --job-name clean_${workload} rm -rf $DATA_PATH/$workload/checkpoint"
    echo "Running command: $cmd"
    $cmd
done

echo "We have created $(flux jobs | wc -l) jobs"

echo "Waiting for all training jobs..."
for job_id in "${WORKLOAD_JOB_IDS[@]}"; do
    if [[ "$job_id" != "None" ]]; then
        flux job status "$job_id" || true
    fi
done

echo "Waiting for all compression jobs..."
for job_id in "${COMPRESS_JOB_IDS[@]}"; do
    if [[ "$job_id" != "None" ]]; then
        flux job status "$job_id" || true
    fi
done

echo "Checking for failed compression jobs..."
index=0
for job_id in "${COMPRESS_JOB_IDS[@]}"; do
    if [[ "$job_id" != "None" ]]; then
        workload="${DLIO_WORKLOADS[$index]}"
        job_exit_code=$(flux job info $job_id guest.exec.eventlog | grep exitcode | jq -c '.context.exitcode')
        if [[ "$job_exit_code" -ne "0" ]]; then
        
            echo "Workload $workload failed and exits with code $job_exit_code check $CUSTOM_CI_OUTPUR_DIR/$workload/$CI_RUNNER_SHORT_TOKEN for info"
            output=$CUSTOM_CI_OUTPUR_DIR/$workload/$CI_RUNNER_SHORT_TOKEN/train
            echo "Compressing traces "
            dftracer_pgzip -d $output
        else
            echo "Compression for workload $workload is successful"
        fi
    fi
    index=$((index+1))
done

echo "Deleting failed jobs..."
index=0
for job_id in "${WORKLOAD_JOB_IDS[@]}"; do
    if [[ "$job_id" != "None" ]]; then
        workload="${DLIO_WORKLOADS[$index]}"
        job_exit_code=$(flux job info $job_id guest.exec.eventlog | grep exitcode | jq -c '.context.exitcode')
        if [[ "$job_exit_code" -ne "0" ]]; then       
            echo "Workload $workload failed and exits with code $job_exit_code check $CUSTOM_CI_OUTPUR_DIR/$workload/$CI_RUNNER_SHORT_TOKEN for info"
            output=$CUSTOM_CI_OUTPUR_DIR/$workload/$CI_RUNNER_SHORT_TOKEN/train
            echo "Removing trace files from $output as workload has failed"
            rm -rf $output/*.pfw*
        else
            echo "Workload $workload is successful"
        fi
    fi
    index=$((index+1))
done

