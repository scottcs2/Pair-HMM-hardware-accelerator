`ifndef __PROCESSING_ELEMENT_TB_SV__
`define __PROCESSING_ELEMENT_TB_SV__

typedef struct {
	real a_mm;
    real a_im; 
    real a_dm;
    real a_mi;
    real a_ii;
    real a_md;
    real a_dd;
} transition_probs_real;

typedef struct {
    real m_val;
    real i_val;
    real d_val;
	real t_a;
	real t_b;
} pe_calcs_real;

module processing_element_tb;
    logic  clock;
    logic  reset;
/* 
	// for our use in testbench for checking values (inputs to double multiplier)
    logic [63:0] mult_a, mult_b, mult_z;
    logic mult_valid, mult_done;
*/
	 
	TAG tag_counter;

	// inputs to the processing element
	logic [63:0] prior;
	logic done, enable, advance, set_tb_special;
	logic global_stall, stall;
	TAG tag_in, tag_out;
	transition_probs probs;
	pe_calcs pe_vals_in; 
	pe_calcs pe_vals_out;

	
	// real versions of inputs
	pe_calcs_real pe_vals_in_real;
	pe_calcs_real pe_vals_out_real;
	pe_calcs_real prev_pe_vals_real;
	transition_probs_real probs_real;
	real prior_real;
	
	int num_calculations; // tracks how many tests we've run
    
    always begin
        #10;
        clock = ~clock;
    end

	always_ff @(posedge clock) begin
        if(reset) begin
            global_stall <= 0;
        end else begin
            //global_stall <= ($random % 100) > 40;
            //global_stall <= !global_stall;
        end
    end
	
	function makeRandom;
		// generates a random real between 0 and 1.
		output real value;
		int before_double;
		before_double = $random;
		
		value = 0 + (1-0)*($itor(before_double) / 32'hffffffff);
		if(value < 0)
			value = value * -1;
		
	endfunction
	
	function makeTransitionProbs;
		// generates transition probabilities
		output transition_probs values;
		output transition_probs_real real_values;
		real T_PROB_REAL;
		
		// create all random numbers
		makeRandom(T_PROB_REAL);
		real_values.a_mm = T_PROB_REAL;
		values.a_mm = $realtobits(T_PROB_REAL);
		
		makeRandom(T_PROB_REAL);
		real_values.a_im = T_PROB_REAL;
		real_values.a_dm = real_values.a_im;
		values.a_im = $realtobits(T_PROB_REAL);
		values.a_dm = values.a_im;
		
		makeRandom(T_PROB_REAL);
		real_values.a_mi = T_PROB_REAL;
		values.a_mi = $realtobits(T_PROB_REAL);
		
		makeRandom(T_PROB_REAL);
		real_values.a_ii = T_PROB_REAL;
		real_values.a_dd = real_values.a_ii;
		values.a_ii = $realtobits(T_PROB_REAL);
		values.a_dd = values.a_ii;
		
		makeRandom(T_PROB_REAL);
		real_values.a_md = T_PROB_REAL;
		values.a_md = $realtobits(T_PROB_REAL);


	endfunction
	
	function makePeCalcs;
		output pe_calcs values;
		output pe_calcs_real real_values;
		real PE_CALC_REAL;
		
		makeRandom(PE_CALC_REAL);
		real_values.m_val = PE_CALC_REAL;
		values.m_val = $realtobits(PE_CALC_REAL);
		
		makeRandom(PE_CALC_REAL);
		real_values.i_val = PE_CALC_REAL;
		values.i_val = $realtobits(PE_CALC_REAL);
		
		makeRandom(PE_CALC_REAL);
		real_values.d_val = PE_CALC_REAL;
		values.d_val = $realtobits(PE_CALC_REAL);

	endfunction
	
	task test_random;
		logic failed;
	
		$display("Test Number %d:",num_calculations);
		reset = 0;
		makeTransitionProbs(probs, probs_real);
		makePeCalcs(pe_vals_in, pe_vals_in_real);
		//makePeCalcs(pe_vals_in[1], pe_vals_in_real[1]);
		makeRandom(prior_real);
		prior = $realtobits(prior_real);
		
		prev_pe_vals_real = pe_vals_out_real;
		
		pe_vals_out_real.m_val = prior_real * (
									prev_pe_vals_real.t_a + prev_pe_vals_real.t_b
								);
		pe_vals_out_real.i_val = probs_real.a_mi * prev_pe_vals_real.m_val +
								 probs_real.a_ii * prev_pe_vals_real.i_val;
								 
		pe_vals_out_real.d_val = probs_real.a_md * pe_vals_in_real.m_val +
								 probs_real.a_dd * pe_vals_in_real.d_val;

		pe_vals_out_real.t_a = probs_real.a_dm * (pe_vals_in_real.i_val + pe_vals_in_real.d_val);

		pe_vals_out_real.t_b = probs_real.a_mm * pe_vals_in_real.m_val;
								 
		enable = 1;
		advance = 0;
		failed = 0;
		tag_counter += 1;
		
		while(~done) begin
			@(negedge clock);
			set_tb_special = 0;
		end
	
		advance = 1;
		@(negedge clock);
		enable = 0;
		advance = 0;
		
		if(pe_vals_out_real.m_val != $bitstoreal(pe_vals_out.m_val)) begin
			failed = 1;
		end
		
		if(pe_vals_out_real.i_val != $bitstoreal(pe_vals_out.i_val)) begin
			failed = 1;
		end
		
		if(pe_vals_out_real.d_val != $bitstoreal(pe_vals_out.d_val)) begin
			failed = 1;
		end

		if(pe_vals_out_real.t_a != $bitstoreal(pe_vals_out.t_a)) begin
			failed = 1;
		end

		if(pe_vals_out_real.t_b != $bitstoreal(pe_vals_out.t_b)) begin
			failed = 1;
		end

		
		if(failed) begin
			$display("Failed testcase number:%d", num_calculations);
		//end else begin 
			//$display("Passed testcase number %d", num_calculations);
			$display("Real m_val=%f", pe_vals_out_real.m_val);
			$display("Real i_val=%f", pe_vals_out_real.i_val);
			$display("Real d_val=%f", pe_vals_out_real.d_val);
			$display("Real t_a=%f",	pe_vals_out_real.t_a);
			$display("Real t_b=%f",	pe_vals_out_real.t_b);
			$display("PE m_val=%f", $bitstoreal(pe_vals_out.m_val));
			$display("PE i_val=%f", $bitstoreal(pe_vals_out.i_val));
			$display("PE d_val=%f", $bitstoreal(pe_vals_out.d_val));
			$display("PE t_a=%f", $bitstoreal(pe_vals_out.t_a));
			$display("PE t_b=%f", $bitstoreal(pe_vals_out.t_b));

			
			$finish;
		end	
	
		@(negedge clock);
		@(negedge clock);
		
	endtask
	
	processing_element_hlf pe (
		// inputs
		.clk(clock),
		.reset(reset),
		.advance(advance),
		.enable(enable),
		.set_tb_special,
		.probs(probs),
		.pe_vals_in(pe_vals_in),
		.prior(prior),
		.tag_in(tag_counter),
		.global_stall,
		
		// outputs
		.pe_vals_out(pe_vals_out),
		.done(done),
		.tag_out,
		.stall
	);
  
    initial begin
        // intialize
        $display("INITIALIZING: \n");
	    clock = 0;
        reset = 0;  
        @(negedge clock);
		@(negedge clock);
	
		pe_vals_out_real.m_val = 0;
		pe_vals_out_real.i_val = 0;
		pe_vals_out_real.d_val = 0;
		

        // reset values
        $display("RESETTING: \n");
        reset = 1;
		tag_counter = 0;
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);

        // test value
        $display("TESTING RANDOM INPUTS: \n");
		
		set_tb_special = 1;
		num_calculations = 0;
		// for(int i = 0; i < 1000000; i++) begin
		for(int i = 0; i < 100; i++) begin
			num_calculations = num_calculations + 1;
			test_random();
		end
		
		$display("ALL TESTS PASSED!");
		$finish;
		
    end


  endmodule
  
`endif
