`ifndef __DOUBLE_ADDER_TB_SV__
`define __DOUBLE_ADDER_TB_SV__

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
            $display("%20.20f + %20.20f = %20.20f", x, y, result);
            $display("%h + %h = %h", $realtobits(x), $realtobits(y), $realtobits(result));
            if(x + y != result) begin
                $display("Error incorrect, expected: %20.20f", x + y);
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
            // global_stall <= ($random % 100) > 40;
            // global_stall <= !global_stall;
        end
    end

    double_adder_pipe mine (
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

    // double_adder ad (
    //     // inputs
    //     .input_a(a),
    //     .input_b(b),
    //     .input_valid(valid),
    //     .clk(clock),
    //     .reset(reset),
    //     // outputs
    //     .output_z(z_orig),
    //     .done(done_orig)
    // );
  
    initial begin
        clock = 0;
        reset = 1;
        DOUBLE_A = $bitstoreal(64'hc0119c9b4ef19c9b);
        DOUBLE_B = $bitstoreal(64'hc05d5aa34daf5aa3);
        // should be: -121.81915345644092951716
        valid = 0;
        counter = 0;
        counter_orig = 0;
        tag_in = 1;
        // global_stall = 0;
        @(negedge clock);
        reset = 0;
        // valid = 1;
        // reset = 0;
        // @(negedge clock);
        // valid = 0;
        // @(negedge clock);
        // @(negedge clock);

        // while(!done | !done_orig) begin
        //     @(negedge clock);
        // end
        // $display("%f + %f = %20.20f", DOUBLE_A, DOUBLE_B, result);
        // if(DOUBLE_A + DOUBLE_B != result) begin
        //     $display("Error incorrect, expected:%20.20f", DOUBLE_A + DOUBLE_B);
        //     $finish;
        // end else begin
        //     $display("Success");
        // end
        //     @(negedge clock);
        //     @(negedge clock);

        for(int i = 0; i < 100000; ++i) begin
            test_random(); 
        end
        while(done_count != 100000) begin
            @(negedge clock);
        end 

        $display("ALL TESTS PASSED(%0d)", done_count);
        //$display("Stalled: %0d times", mine.num_stalls);
		$finish;
		
    end


  endmodule
  
`endif
