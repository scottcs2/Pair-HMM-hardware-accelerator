`ifndef DOUBLE_MULTIPLY_PIPE_SV
`define DOUBLE_MULTIPLY_PIPE_SV
//Below is a copyright from the place we got this FPU originally.
//We heavily modified and pipelined the FPU to make it better suit our needs. 
//IEEE Floating Point Adder (Double Precision)
//Copyright (C) Jonathan P Dawson 2013
//2013-12-12
//IEEE Floating Point Multiplier (Double Precision)
//Copyright (C) Jonathan P Dawson 2014
//2014-01-10
//Found here: https://github.com/dawsonjon/fpu

//Heavily modified by Scott Smith to increase simplicity and better fit the project


module double_multiply_pipe (

        // inputs
        input   logic [63:0]  input_a,
        input   logic [63:0]  input_b,
        input   logic         input_valid,
        input   logic         clk,
		input   logic         reset,
		input 	TAG 		  tag_in,
		input	logic 		  global_stall,

        // outputs
        output  logic [63:0]  output_z,
        output  logic         output_done,
		output 	TAG 		  tag_out,
		output 	logic 		  stall,   
		output integer num_stalls   
);

	logic normalise2_stall, normalise1_stall;
	double_multiply_pipeline_reg unpack_out, normalise2_in, normalise2_out, 
								pack_in, pack_out, normalise1_in, 
								normalise1_out, specialcases_in, 
								specialcases_out, normalise_in,
								multiply_in, multiply_out, 
								normalise_out, result;
								
	assign tag_out = result.tag;
	assign output_done = result.valid;
	assign output_z = result.z;
	assign stall = normalise1_stall || normalise2_stall;

	always_ff @(posedge clk) begin
		if(reset) begin
			num_stalls = 0;
		end else if(global_stall) begin
			num_stalls++;
		end
		/*$display("@@@Pipeline @ t=%0d", $time);
		// $display("unpack\t");
		// if(unpack_in.valid) begin
		// 	print_doublemult_state(unpack_in);
		// end
		if(specialcases_in.valid) begin
			$display("\tspecialcases--\t");
			print_doublemult_state(specialcases_in);
		end
		if(normalise_in.valid) begin
			$display("\tnormalise--\t");
			print_doublemult_state(normalise_in);
		end
		if(multiply_in.valid) begin
			$display("\tmultiply--\t");
			print_doublemult_state(multiply_in);
		end
		if(normalise1_in.valid) begin
			$display("\tnormalise1--\t");
			print_doublemult_state(normalise1_in);
		end
		if(normalise2_in.valid) begin
			$display("\tnormalise2--\t");
			print_doublemult_state(normalise2_in);
		end
		if(pack_in.valid) begin
			$display("\tpack--\t");
			print_doublemult_state(pack_in);
		end
		if(result.valid) begin
			$display("\tresult--\t");
			print_doublemult_state(result);
		end*/
	end


	doublemult_unpack unpack(
		.input_a,
		.input_b,
		.valid(input_valid),
		.tag_in(tag_in),
		.stage_out(unpack_out)
	);
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			specialcases_in.valid <= 0;
		end else if(!stall) begin
			specialcases_in <= unpack_out;
		end
	end	

	doublemult_specialcases specialcases(
		.stage_in(specialcases_in),
		.stage_out(specialcases_out)
	);
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			normalise_in.valid <= 0;
		end else if(!stall) begin
			normalise_in <= specialcases_out;			
		end
	end	

	doublemult_normalise normalise(
		.stage_in(normalise_in),
		.stage_out(normalise_out)
	);
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			multiply_in.valid <= 0;
		end else if(!stall) begin
			multiply_in <= normalise_out;
		end
	end	

	// multiply here
	logic [63:0] mcand_in, mplier_in;
	assign mcand_in = multiply_in.a_m;
	assign mplier_in = multiply_in.b_m << 2;
	mult_pipe multiply_pipelined (
		//inputs
		.clk(clk),
		.reset(reset),
		.start(multiply_in.valid),
		.stall(stall),
		.stage_in(multiply_in),
		.sign(2'b0),
		.mcand(mcand_in),
		.mplier(mplier_in),
		
		//outputs
		.stage_out(multiply_out)
		// ,.product(), // they are inside the stage_out
		// .done(),
	);
	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			normalise1_in.valid <= 0;
		end else if(!global_stall) begin
			if(normalise1_stall) begin
				normalise1_in <= normalise1_out;
			end else if(!normalise2_stall) begin
				normalise1_in <= multiply_out;
			end 
		end
	end	

	doublemult_normalise1 normalise1(
		.stage_in(normalise1_in),
		.stage_out(normalise1_out),
		.stall_out(normalise1_stall)
	);
	// synopsys sync_set_reset "reset"
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

	doublemult_normalise2 normalise2(
		.stage_in(normalise2_in),
		.stage_out(normalise2_out),
		.stall_out(normalise2_stall)
	);	
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin // insert nop
			pack_in.valid <= 0;
		end else if(!global_stall) begin
			if(normalise2_stall) begin
				pack_in.valid <= 0;
			end else begin
				pack_in <= normalise2_out;
			end
		end
	end	   

	doublemult_pack pack(
		.stage_in(pack_in),
		.stage_out(pack_out)
	);
	// synopsys sync_set_reset "reset"
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
