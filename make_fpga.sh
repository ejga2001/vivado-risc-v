#!/bin/bash

BHT_CONFIGS="16384 32768 65536 131072 262144"
GBP_CONFIGS="16384 32768 65536 131072 262144"
LBP_CONFIGS="4096:2048:2 4096:4096:4 8192:8192:3 16384:16384:2 65536:16384:3"
TOURNAMENT_CONFIGS="2048:4096:4096:1024 8192:8192:4096:2048 4096:16384:16384:4096 16384:16384:65536:4096 32768:32768:65536:16384"
TAGE_CONFIGS="8192:1:2048 16384:2:2048 32768:3:2048 65536:4:2048 131072:5:2048"
NUM_CORES=$(nproc)

# Run configs
declare -A job_list
MAX_JOBS=5
BANK_WIDTH=4
jobs=0
i=0

for BHT_ENTRIES in ${BHT_CONFIGS}; do
  ARGS="${BHT_ENTRIES}:${BANK_WIDTH}"
  METADATA="_bht=${BHT_ENTRIES}"
  make CONFIG=rocket64x1BimodalBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 vivado-project
  job_list[$jobs]="taskset -c $(( i % NUM_CORES )) make CONFIG=rocket64x1BimodalBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 bitstream"
  ((i++))
  ((jobs++))
done

for GBP_ENTRIES in ${GBP_CONFIGS}; do
  ARGS="${GBP_ENTRIES}:${BANK_WIDTH}"
  METADATA="_gbp=${GBP_ENTRIES}"
  make CONFIG=rocket64x1GshareBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 vivado-project
  job_list[$jobs]="taskset -c $(( i % NUM_CORES )) make CONFIG=rocket64x1GshareBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 bitstream"
  ((i++))
  ((jobs++))
done

for LBP_CONFIG in ${LBP_CONFIGS}; do
  LBP_ENTRIES=$(echo $LBP_CONFIG | cut -d ":" -f1)
  LHR_ENTRIES=$(echo $LBP_CONFIG | cut -d ":" -f2)
  CTR_BITS=$(echo $LBP_CONFIG | cut -d ":" -f3)
  ARGS="${LBP_ENTRIES}:${LHR_ENTRIES}:${CTR_BITS}:${BANK_WIDTH}"
  METADATA="_lbp=${LBP_ENTRIES}_lhr=${LHR_ENTRIES}_ctrbits=${CTR_BITS}"
  make CONFIG=rocket64x1LocalBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 vivado-project
  job_list[$jobs]="taskset -c $(( i % NUM_CORES )) make CONFIG=rocket64x1LocalBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 bitstream"
  ((i++))
  ((jobs++))
done

for TOURNAMENT_CONFIG in ${TOURNAMENT_CONFIGS}; do
  MBP_ENTRIES=$(echo $TOURNAMENT_CONFIG | cut -d ":" -f1)
  GBP_ENTRIES=$(echo $TOURNAMENT_CONFIG | cut -d ":" -f2)
  LBP_ENTRIES=$(echo $TOURNAMENT_CONFIG | cut -d ":" -f3)
  LHR_ENTRIES=$(echo $TOURNAMENT_CONFIG | cut -d ":" -f4)
  ARGS="${MBP_ENTRIES}:${GBP_ENTRIES}:${LBP_ENTRIES}:${LHR_ENTRIES}:${BANK_WIDTH}"
  METADATA="_mbp=${MBP_ENTRIES}_gbp=${GBP_ENTRIES}_lbp=${LBP_ENTRIES}_lhr=${LHR_ENTRIES}"
  make CONFIG=rocket64x1TournamentBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 vivado-project
  job_list[$jobs]="taskset -c $(( i % NUM_CORES )) make CONFIG=rocket64x1TournamentBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 bitstream"
  ((i++))
  ((jobs++))
done

for TAGE_CONFIG in ${TAGE_CONFIGS}; do
  BHT_ENTRIES=$(echo $TAGE_CONFIG | cut -d ":" -f1)
  POWER=$(echo $TAGE_CONFIG | cut -d ":" -f2)
  UBIT_PERIOD=$(echo $TAGE_CONFIG | cut -d ":" -f3)
  ARGS="${BHT_ENTRIES}:${POWER}:${UBIT_PERIOD}:${BANK_WIDTH}"
  METADATA="_bimodal=${BHT_ENTRIES}_power=${POWER}_ubitperiod=${UBIT_PERIOD}"
  make CONFIG=rocket64x1TAGEBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 vivado-project
  job_list[$jobs]="taskset -c $(( i % NUM_CORES )) make CONFIG=rocket64x1TAGEBP METADATA=${METADATA} PARAMS=${ARGS} BOARD=kc705 bitstream"
  ((i++))
  ((jobs++))
done

njobs=${#job_list[@]}
for (( job = 0; job < ${njobs}; job++ )); do
    echo "Job ${job}: ${job_list[$job]}"
    eval "${job_list[$job]}" &
    echo "$(jobs -rp | wc -l)/${MAX_JOBS} jobs"
    if [ "$(jobs -rp | wc -l)" -ge ${MAX_JOBS} ]; then
      echo "WAITING"
      wait -n
    fi
done

# Espera a que terminen todos los procesos al final
wait

echo "DONE"
