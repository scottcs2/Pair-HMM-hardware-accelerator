# make          <- runs simv (after compiling simv if needed)
# make simv     <- compile simv if needed (but do not run)
# make syn      <- runs syn_simv (after synthesizing if needed then 
#                                 compiling synsimv if needed)
# make clean    <- remove files created during compilations (but not synthesis)
# make nuke     <- remove all files created during compilation and synthesis
#
# To compile additional files, add them to the TESTBENCH or SIMFILES as needed
# Every .vg file will need its own rule and one or more synthesis scripts
# The information contained here (in the rules for those vg files) will be 
# similar to the information in those scripts but that seems hard to avoid.
#

VCS = SW_VCS=2017.12-SP2-1 vcs -sverilog +vc -Mupdate -line -full64 +define+TEST_SIZE=$(CAM_SIZE)

all:    simv
	./simv | tee program.out

##### 
# Modify starting here
#####


TESTBENCH = Verilog_multi/sys_defs.svh Verilog_multi/systolic_testbench.sv 
#SIMFILES = $(wildcard Verilog_multi/*)
SIMFILES = Verilog_multi/pipeline.sv Verilog_multi/processing_element.sv Verilog_multi/_ADD_MULT.sv Verilog_multi/_MULT_ADD.sv Verilog_multi/double_adder.sv Verilog_multi/double_multiply.sv Verilog_multi/mult.sv Verilog_multi/mult_stage.sv
SYNFILES = processing_element_halved.vg
LIB = /afs/umich.edu/class/eecs470/lib/verilog/lec25dscc25.v

export DOUBLE_MULTIPLY_SOURCE = Verilog/mult_stage.sv Verilog/mult.sv Verilog/double_multiply.sv 
export HEADERS = Verilog/sys_defs.svh

export RESET_NET_NAME = reset

CAM.vg:	cam.v cam.tcl 
	dc_shell-t -f cam.tcl | tee synth.out

double_adder.vg: Verilog/double_adder.sv double_adder.tcl
	dc_shell-t -f double_adder.tcl | tee synth.out

double_multiplier_original.vg: fpu/double_multiplier/double_multiplier_original.v double_multiplier_original.tcl
	dc_shell-t -f double_multiplier.tcl | tee synth.out

mult.vg: Verilog/mult.sv mult_stage.vg mult.tcl
	dc_shell-t -f ./mult.tcl | tee mult_synth.out

mult_stage.vg:	Verilog/mult_stage.sv mult_stage.tcl
	dc_shell-t -f ./mult_stage.tcl | tee mult_stage_synth.out

double_multiply.vg: mult_stage.vg mult.vg Verilog/double_multiply.sv
	dc_shell-t -f ./double_multiply.tcl | tee double_multiply_synth.out

processing_element.vg: mult_stage.vg mult.vg double_multiply.vg double_adder.vg Verilog/processing_element.sv
	dc_shell-t -f ./processing_element.tcl | tee processing_element_synth.out

processing_element_halved.vg: mult_stage.vg mult.vg MULT_ADD.vg ADD_MULT.vg Verilog_multi/processing_element.sv
	dc_shell-t -f ./processing_element_halved.tcl | tee processing_element_halved_synth.out

systolic_array.vg: processing_element.vg double_adder.vg Verilog/pipeline.sv
	dc_shell-t -f ./pipeline.tcl | tee pipeline_synth.out

MULT_ADD.vg: double_multiply.vg double_adder.vg
	dc_shell-t -f ./MULT_ADD.tcl | tee MULT_ADD_synth.out

ADD_MULT.vg: double_multiply.vg double_adder.vg
	dc_shell-t -f ./ADD_MULT.tcl | tee ADD_MULT_synth.out

#####
# Should be no need to modify after here
#####

dve:	$(SIMFILES) $(TESTBENCH) 
	$(VCS) +memcbk $(TESTBENCH) $(SIMFILES) -o dve -R -gui
	
dve_syn:	$(SYNFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) +define+SYNTH_TEST -o syn_simv -R -gui

simv:	$(SIMFILES) $(TESTBENCH)	
	$(VCS) $(TESTBENCH) $(SIMFILES)	-o simv

syn_simv:	$(SYNFILES) $(TESTBENCH)
	$(VCS) $(TESTBENCH) $(SYNFILES) $(LIB) +define+SYNTH_TEST -o syn_simv

syn:	syn_simv
	./syn_simv | tee syn_program.out

clean:
	rm -rvf simv *.daidir csrc vcs.key program.out \
	  syn_simv syn_simv.daidir syn_program.out \
          dve *.vpd *.vcd *.dump ucli.key hmm multi_hmm

nuke:	clean
	rm -rvf *.vg *.rep *.db *.chk *.log *.out DVEfiles/ *.ddc *.res *_svsim.sv default.svf *.vdb


GCC = g++ -std=c++17

hmm: $(wildcard src/*)
	$(GCC) -g3 -Og -o hmm -pthread $^

multi_hmm: $(wildcard src_multi/*) 
	$(GCC) -g3 -Og -o multi_hmm -pthread $^

bane: $(wildcard src/*)
	icpc --std=c++11 -g3 -o hmm -pthread $^

mic: $(wildcard src/*)
	icpc --std=c++11 -g3 -o hmm.mic -pthread $^ -mmic
