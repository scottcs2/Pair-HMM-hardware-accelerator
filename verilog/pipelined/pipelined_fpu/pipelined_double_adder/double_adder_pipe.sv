`ifndef DOUBLE_ADDER_PIPE_SV
`define DOUBLE_ADDER_PIPE_SV
//Below is a copyright from the place we got this FPU originally.
//We heavily modified and pipelined the FPU to make it better suit our needs. 
//IEEE Floating Point Adder (Double Precision)
//Copyright (C) Jonathan P Dawson 2013
//2013-12-12
//Found here: https://github.com/dawsonjon/fpu

module double_adder_pipe (

    //inputs
    input   logic   [63:0]  input_a,
    input   logic   [63:0]  input_b,
    input   logic           input_valid,
    input   logic           clk,
    input   logic           reset,
    input   TAG             tag_in,
    input   logic           global_stall,
    input   logic   [63:0]  mult_operand_in,

    // outputs
    output  logic   [63:0]  output_z,
    output  logic           output_done,
    output  TAG             tag_out,
    output  logic           stall,
    output integer          num_stalls,
    output logic    [63:0]  mult_operand_out // "late" operand needed for add_mult
);

    double_adder_pipeline_reg   unpack_out,
                                special_cases_in, special_cases_out,
                                align_in, align_out,
                                add0_in, add0_out,
                                add1_in, add1_out,
                                normalise1_in, normalise1_out,
                                normalise2_in, normalise2_out,
                                round_in, round_out,
                                pack_in, pack_out,
                                result;
    
    always_ff @(posedge clk) begin
		if(reset) begin
			num_stalls = 0;
		end else if(global_stall) begin
			num_stalls++;
		end
		/*$display("@@@Pipeline @ t=%0d", $time);
		if(special_cases_in.valid) begin
			$display("\tspecialcases--\t");
			print_doubleadd_state(special_cases_in);
		end
		if(align_in.valid) begin
			$display("\talign--\t");
			print_doubleadd_state(align_in);
		end
		if(add0_in.valid) begin
			$display("\tadd0--\t");
			print_doubleadd_state(add0_in);
		end
        if(add1_in.valid) begin
			$display("\tadd1--\t");
			print_doubleadd_state(add1_in);
		end
		if(normalise1_in.valid) begin
			$display("\tnormalise1--\t");
			print_doubleadd_state(normalise1_in);
		end
		if(normalise2_in.valid) begin
			$display("\tnormalise2--\t");
			print_doubleadd_state(normalise2_in);
		end
        if(round_in.valid) begin
			$display("\round--\t");
			print_doubleadd_state(round_in);
		end
		if(pack_in.valid) begin
			$display("\tpack--\t");
			print_doubleadd_state(pack_in);
		end
		if(result.valid) begin
			$display("\tresult--\t");
			print_doubleadd_state(result);
		end*/
	end

    logic normalise1_stall, normalise2_stall;

    assign stall = normalise1_stall || normalise2_stall;

    assign tag_out = result.tag;
    assign output_done = result.valid;
    assign output_z = result.output_z;
    assign mult_operand_out = result.mult_operand;

    doubleadd_unpack unpack (
        .input_a(input_a),
        .input_b(input_b),
        .valid(input_valid),
        .tag_in(tag_in),
        .mult_operand(mult_operand_in),

        .stage_out(unpack_out)

    );

    always_ff @(posedge clk) begin
        if(reset) begin
            special_cases_in.valid <= 0;
        end else if(stall) begin
            special_cases_in <= special_cases_in;
        end else begin
            special_cases_in <= unpack_out;
        end
    end

    doubleadd_specialcases specialcases (
        .stage_in(special_cases_in),
        .stage_out(special_cases_out)
    );

    always_ff @(posedge clk) begin
        if(reset) begin
            align_in.valid <= 0;
        end else if(stall) begin
            align_in <= align_in;
        end else begin
            align_in <= special_cases_out;
        end
    end

    doubleadd_align align (
        .stage_in(align_in),
        .stage_out(align_out)
    );

    always_ff @(posedge clk) begin
        if(reset) begin
            add0_in.valid <= 0;
        end else if(stall) begin
            add0_in <= add0_in;
        end else begin
            add0_in <= align_out;
        end
    end

    doubleadd_add0 add0 (
        .stage_in(add0_in),
        .stage_out(add0_out)
    );

    always_ff @(posedge clk) begin
        if(reset) begin
            add1_in.valid <= 0;
        end else if(stall) begin
            add1_in <= add1_in;
        end else begin
            add1_in <= add0_out;
        end
    end

    doubleadd_add1 add1 (
        .stage_in(add1_in),
        .stage_out(add1_out)
    );

	always_ff @(posedge clk) begin
		if(reset) begin
			normalise1_in.valid <= 0;
		end else if(!global_stall) begin
			if(normalise1_stall) begin
				normalise1_in <= normalise1_out;
			end else if(!normalise2_stall) begin
				normalise1_in <= add1_out;
			end 
		end
    end	
    
    doubleadd_normalise1 normalise1 (
        .stage_in(normalise1_in),
        .stage_out(normalise1_out),
        .stall_out(normalise1_stall)
    );

    always_ff @(posedge clk) begin
		if(reset) begin // insert nop
			normalise2_in.valid <= 0;
		end else if(!global_stall) begin
			if(normalise2_stall) begin
				normalise2_in <= normalise2_out;
			end else if(normalise1_stall) begin
				normalise2_in.valid <= 0;
			end else begin
				normalise2_in <= normalise1_out;
			end
		end 
    end	
    
    
	doubleadd_normalise2 normalise2 (
		.stage_in(normalise2_in),
		.stage_out(normalise2_out),
		.stall_out(normalise2_stall)
    );	
    
    always_ff @(posedge clk) begin
		if(reset) begin // insert nop
			round_in.valid <= 0;
		end else if(!global_stall) begin
			if(normalise2_stall) begin
				round_in.valid <= 0;
			end else begin
				round_in <= normalise2_out;
			end
		end
    end	  
    
    doubleadd_round round(
		.stage_in(round_in),
		.stage_out(round_out)
    );
    always_ff @(posedge clk) begin
		if(reset) begin
			pack_in.valid <= 0;
		end if(!global_stall) begin
			pack_in <= round_out;
		end
	end	

    doubleadd_pack pack(
		.stage_in(pack_in),
		.stage_out(pack_out)
    );
    
    always_ff @(posedge clk) begin
		if(reset) begin
			result.valid <= 0;
		end if(global_stall) begin
			result.valid <= 0;
		end else begin
			result <= pack_out;
		end
	end	
 
endmodule

`endif