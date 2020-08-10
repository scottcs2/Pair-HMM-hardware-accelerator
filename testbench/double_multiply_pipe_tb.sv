`ifndef __DOUBLE_MULTIPLY_TB__SV__
`define __DOUBLE_MULTIPLY_TB_SV__

`timescale 1ns/100ps;
module double_multiply_tb;
    logic  clock;
    logic  reset;
    logic [63:0] a;
    logic [63:0] b;
    logic [63:0] z, z_orig;
    logic z_ack;
    logic valid;
    logic done, done_orig;
    TAG tag_out;
    logic stall;
    logic global_stall;
    logic [63:0] counter, counter_orig;

    real DOUBLE_A, DOUBLE_B, result;
	
	int timeDifference;
	
	int num_calculations;
    
    logic [3:0] tag_in;

    real qua[$];
    real qub[$];

    assign a = $realtobits(DOUBLE_A);
    assign b = $realtobits(DOUBLE_B);
    assign result = $bitstoreal(z);

    always begin
        #10;
        clock = ~clock;
    end
	
	function makeRandom(output real value);
		// generates a random double between 1 and 100.		
		int before_double;
		before_double = $random;
		
		value = 0 + (1000-0)*($itor(before_double) / 32'hffffffff);
		
	endfunction
	
	task test_random;
        reset = 0;
        valid = 1;
        makeRandom(DOUBLE_A);
        makeRandom(DOUBLE_B);
        if(($random % 100) < 1) begin
            DOUBLE_A = 0;
        end
        if(($random % 100) < 1) begin
            DOUBLE_B = 1.0;
        end
        qua.push_back(DOUBLE_A);
        qub.push_back(DOUBLE_B);

		do 
            begin
                @(posedge clock);
            end 
        while(stall);
        valid = 0;
        ++tag_in;
	endtask

    integer done_count = 0;
    real x, y;
    always_ff @(posedge clock) begin
        if(done) begin
            x = qua.pop_front();
            y = qub.pop_front();
            $display("%f x %f = %f", x, y, result);
            if(x * y != result) begin
                $display("Error incorrect, expected: %f", x * y);
                $finish;
            end else begin
                $display("Success #%0d", tag_out);
            end
            ++done_count;
        end
    end
   
    always_ff @(posedge clock) begin
        if(reset) begin
            global_stall <= 0;
        end else begin
            global_stall <= ($random % 100) > 40;
            // global_stall <= !global_stall;
        end
    end

    double_multiply_pipe mine (
        // inputs
        .input_a(a),
        .input_b(b),
        .input_valid(valid),
        .clk(clock),
        .reset(reset),
        .tag_in(tag_in),
        .global_stall(global_stall),
        // outputs
        .output_z(z),
        .output_done(done),
        .tag_out,
        .stall
    );

    // double_multiply dm (
    //     // inputs
    //     .input_a(a),
    //     .input_b(b),
    //     .input_valid(valid),
    //     .clk(clock),
    //     .reset(reset),
    //     // outputs
    //     .output_z(z_orig),
    //     .output_done(done_orig)
    // );
  
    initial begin
        clock = 0;
        reset = 1;
        DOUBLE_A = -0.247904;
        DOUBLE_B = -0.482348;
        valid = 0;
        counter = 0;
        counter_orig = 0;
        tag_in = 1;
        // global_stall = 0;
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        for(int i = 0; i < 100000; ++i) begin
            test_random(); 
        end
        while(done_count != 100000) begin
            @(negedge clock);
        end 
        // valid = 1;
        // @(negedge clock);
        // valid = 0;
        // while(!done) begin
        //     $display("1");
        //     @(negedge clock);
        // end
        // $display("%f x %f = %f", DOUBLE_A, DOUBLE_B, result);
        // if(DOUBLE_A * DOUBLE_B != result) begin
        //     $display("Error incorrect, expected:%f", DOUBLE_A * DOUBLE_B);
        //     $finish;
        // end else begin
        //     $display("Success");
        // end

        /*// intialize
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
        */
        $display("ALL TESTS PASSED(%0d)", done_count);
        $display("Stalled: %0d times", mine.num_stalls);
		$finish;
		
    end


  endmodule
  
`endif
