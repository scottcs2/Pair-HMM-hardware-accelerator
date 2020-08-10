#!/bin/bash

rm RESULTS

for i in $(eval echo {1..$1});
do
	echo -n "$i: " | tee RESULTS
	#echo "===== RUN $i ====="
	./run_test.sh | tee RESULTS
done

cat RESULTS
