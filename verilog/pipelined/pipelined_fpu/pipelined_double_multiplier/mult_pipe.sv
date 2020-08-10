`ifndef __MULT_PIPE_SV__
`define __MULT_PIPE_SV__

module mult_pipe (
	input clk, reset,
	input start,
	input stall,
	input double_multiply_pipeline_reg stage_in,
	input [1:0] sign,
	input [64-1:0] mcand, mplier,
	
	output double_multiply_pipeline_reg stage_out,
	output [(2*64)-1:0] product,
	output done
);

	// parameter XLEN = 64;
	// parameter NUM_STAGE = 8;
	logic [(2*`XLEN)-1:0] mcand_out, mplier_out, mcand_in, mplier_in;
	logic [`NUM_STAGE:0][2*`XLEN-1:0] internal_mcands, internal_mpliers;
	logic [`NUM_STAGE:0][2*`XLEN-1:0] internal_products;
	logic [`NUM_STAGE:0] internal_dones;
	double_multiply_pipeline_reg [`NUM_STAGE:0] internal_stages;

	assign mcand_in  = sign[0] ? {{`XLEN{mcand[`XLEN-1]}}, mcand}   : {{`XLEN{1'b0}}, mcand} ;
	assign mplier_in = sign[1] ? {{`XLEN{mplier[`XLEN-1]}}, mplier} : {{`XLEN{1'b0}}, mplier};

	assign internal_mcands[0]   = mcand_in;
	assign internal_mpliers[0]  = mplier_in;
	assign internal_products[0] = 128'h0;
	assign internal_dones[0]    = start & !stall;

	assign done    = internal_dones[`NUM_STAGE];
	assign product = internal_products[`NUM_STAGE];

	always_comb begin
		internal_stages[0] = stage_in;
		internal_stages[0].z_s = stage_in.a_s ^ stage_in.b_s;
		internal_stages[0].z_e = stage_in.a_e + stage_in.b_e + 1;
		
		stage_out = internal_stages[`NUM_STAGE];
		stage_out.z_m = product[107:55];
		stage_out.guard = product[54];
		stage_out.round_bit = product[53];
		stage_out.sticky = (product[52:0] != 0);
	end

	genvar i;
	generate 
	for (i = 0; i < `NUM_STAGE; ++i) begin : mstage
		mult_stage_pipe  ms (
			//inputs
			.clk(clk),
			.reset(reset),
			.stall(stall),
			.product_in(internal_products[i]),
			.mplier_in(internal_mpliers[i]),
			.stage_in(internal_stages[i]),
			.mcand_in(internal_mcands[i]),
			.start(internal_dones[i]),

			// outputs
			.product_out(internal_products[i+1]),
			.stage_out(internal_stages[i+1]),
			.mplier_out(internal_mpliers[i+1]),
			.mcand_out(internal_mcands[i+1]),
			.done(internal_dones[i+1])
		);
	end
	endgenerate

endmodule


`endif //__MULT_SV__
