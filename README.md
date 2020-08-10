# Pair-HMM-hardware-accelerator
RTL design for a hardware accelerator for Pairwise Hidden Markov Models. Specifically accelerates the forward algorithm.
This project accelerates the forward algorithm for Pairwise Hidden Markov Models (Pair-HMM). https://github.com/dawsonjon/fpu
This was created for our final project in EECS 570: Parallel Computer Architecture at the University of Michigan
To learn more about what this project does, please read the final report: final_report.pdf

# About the branches:
Branch main is a simple accelerator design that does not include a ring buffer optimization.
Branch ring contains an RTL design with a ring buffer which dramatically increases the performance of the accelerator.
Both of these versions are described more thoroughly in the final_report.pdf

# Usage
The src/ folder contains cpp source files for a singlethreadded implementation of the forward algorithm for Pair-HMM.
The src_multi/ folder contains cpp source files for multithreaded implementations of the forward algorithm for Pair-HMM.
The Verilog/ folder contains the RTL source for our accelerator.
The fpu/ folder contains the original floating point units that we took from https://github.com/dawsonjon/fpu. We modified them and put our modified versions in the Verilog/ folder.


# Authors:
1. Scott Smith
2. Joseph Nwabueze
3. Samuel Hall
4. John Campbell

