#!/bin/bash

# GENERATE TEST CASE
#echo "==========Generating test case=========="
echo 1 | ./gentest > /dev/null
sleep 1 # pretty sure randomization is based on unix time
#cat test.data

# RUN TEST ON BASELINE
#echo "==========Running Baseline=========="
./hmm > /dev/null

# RUN TEST ON VERILOG
#echo "==========Running Verilog==========="
make > /dev/null

# COMPARE
base=( $(<baseline_output.out) )
#echo "BASE: $base"

mt=( $(<mt_baseline_output.out) )
#echo "MT: $mt"

vlog=( $(<verilog_output.out) )
#echo "VLOG: $vlog"

echo "BASE: $base		MT: $mt			VLOG: $vlog"
