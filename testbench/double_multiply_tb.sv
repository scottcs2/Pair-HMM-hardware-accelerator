`ifndef __DOUBLE_MULTIPLY_SV__
`define __DOUBLE_MULTIPLY_SV__

module double_multiply_tb;
    logic  clock;
    logic  reset;

    logic [63:0] a;
    logic [63:0] b;
    logic [63:0] z, z_orig;
    logic z_ack;
    logic valid;
    logic done, done_orig;

    logic [63:0] counter, counter_orig;

    real DOUBLE_A, DOUBLE_B;
	
	int timeDifference;
	
	int num_calculations;
    

    always begin
        #10;
        clock = ~clock;
    end
	
	function makeRandom;
		// generates a random double between 1 and 100.
		output real value;
		int before_double;
		before_double = $random;
		
		value = 0 + (1-0)*($itor(before_double) / 32'hffffffff);
		
	endfunction
	
	task test_random;
	
		reset = 0;
		valid = 1;
	
		makeRandom(DOUBLE_A);
		makeRandom(DOUBLE_B);
		a = $realtobits(DOUBLE_A);
       		b = $realtobits(DOUBLE_B);
		
		while(~done_orig | ~done) begin
			$display("time:%d", $time);
			if(~done_orig) begin
				counter_orig = counter_orig + 1;
				$display("Original count: %d\n", counter_orig);
				if(counter_orig > 20'd1000) begin
						$display("ERROR, count too high");
						$display("other counter: %d", counter);
						$finish();
				end
			end
            
			if(~done) begin
				counter = counter + 1;
				$display("New count: %d\n", counter);
				if(counter > 20'd1000) begin
					$display("ERROR, count too high");
					$display("other counter: %d", counter_orig);
					$finish();
				end
			end
	
            @(negedge clock);

		end
		
		timeDifference = timeDifference + (counter - counter_orig);
		
		if(z_orig == z) begin

        end else begin
            $display("OUTPUTS NOT EQUAL!\n\n");
			$finish;
       	end
		
		
		valid = 0;
		reset = 1;
		counter = 0;
		counter_orig = 0;
		@(negedge clock);
		@(negedge clock);
		
	
	endtask
  
    double_multiply mine (
        // inputs
        .input_a(a),
        .input_b(b),
        .input_valid(valid),
        .clk(clock),
        .reset(reset),
        // outputs
        .output_z(z),
        .output_done(done)
    );


    double_multiplier_original original(

        // inputs
        .input_a(a),
        .input_b(b),
        .input_a_stb(valid),
        .input_b_stb(valid),
        .output_z_ack(z_ack),
        .clk(clock),
        .rst(reset),
        
        // outputs
        .output_z(z_orig),
        .output_z_stb(done_orig),
        .input_a_ack(),
        .input_b_ack()
    );


  
    initial begin
        // intialize
        $display("INITIALIZING: \n");
		timeDifference = 0;
	    clock = 0;
        reset = 0; 
        counter = 0;
        counter_orig = 0;
		valid = 0;        
        @(negedge clock);
        @(negedge clock);

        // reset values
        $display("RESETTING: \n");
        reset = 1;
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);

        // test value
        $display("TESTING VALUES: \n");
		
		num_calculations = 1;
		for(int i = 0; i < 100000; i++) begin
			num_calculations = num_calculations + 1;
			test_random();
		end
		
		$display("ALL TESTS PASSED!");
		$display("Time Difference (num cycles new - num cycles old) = %d",
					timeDifference);
		$display("On average, that is: %f per calculation", $itor(timeDifference) / 100000);
		$finish;
		
    end


  endmodule
  
`endif
