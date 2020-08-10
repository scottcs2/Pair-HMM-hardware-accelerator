`ifndef __MULT_SV__
`define __MULT_SV__

module mult (
				input clk, reset,
				input start,
				input [1:0] sign,
				input [64-1:0] mcand, mplier,
				
				output [(2*64)-1:0] product,
				output done
			);
	// parameter XLEN = 64;
	// parameter NUM_STAGE = 8;
	logic [(2*`XLEN)-1:0] mcand_out, mplier_out, mcand_in, mplier_in;
	logic [`NUM_STAGE:0][2*`XLEN-1:0] internal_mcands, internal_mpliers;
	logic [`NUM_STAGE:0][2*`XLEN-1:0] internal_products;
	logic [`NUM_STAGE:0] internal_dones;

	assign mcand_in  = sign[0] ? {{`XLEN{mcand[`XLEN-1]}}, mcand}   : {{`XLEN{1'b0}}, mcand} ;
	assign mplier_in = sign[1] ? {{`XLEN{mplier[`XLEN-1]}}, mplier} : {{`XLEN{1'b0}}, mplier};

	assign internal_mcands[0]   = mcand_in;
	assign internal_mpliers[0]  = mplier_in;
	assign internal_products[0] = 128'h0;
	assign internal_dones[0]    = start;

	assign done    = internal_dones[`NUM_STAGE];
	assign product = internal_products[`NUM_STAGE];

	genvar i;
	generate 
	for (i = 0; i < `NUM_STAGE; ++i) begin : mstage
		mult_stage  ms (
			.clk(clk),
			.reset(reset),
			.product_in(internal_products[i]),
			.mplier_in(internal_mpliers[i]),
			.mcand_in(internal_mcands[i]),
			.start(internal_dones[i]),
			.product_out(internal_products[i+1]),
			.mplier_out(internal_mpliers[i+1]),
			.mcand_out(internal_mcands[i+1]),
			.done(internal_dones[i+1])
		);
	end
	endgenerate

endmodule


`endif //__MULT_SV__
