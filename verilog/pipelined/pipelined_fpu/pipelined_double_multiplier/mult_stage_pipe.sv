`ifndef __MULT_STAGE_PIPE_SV__
`define __MULT_STAGE_PIPE_SV__

module mult_stage_pipe (
	input clk, reset, start,
	input [(2*64)-1:0] mplier_in, mcand_in,
	input double_multiply_pipeline_reg stage_in,
	input [(2*64)-1:0] product_in,
	input stall,

	output logic done,
	output double_multiply_pipeline_reg stage_out,
	output logic [(2*64)-1:0] mplier_out, mcand_out,
	output logic [(2*64)-1:0] product_out
);

	// parameter XLEN = 64;
	// parameter NUM_STAGE = 8;
	// parameter NUM_BITS = (2*XLEN)/NUM_STAGE;

	logic [(2*`XLEN)-1:0] prod_in_reg, partial_prod, next_partial_product, partial_prod_unsigned;
	logic [(2*`XLEN)-1:0] next_mplier, next_mcand;

	assign product_out = prod_in_reg + partial_prod;

	assign next_partial_product = mplier_in[(`NUM_BITS-1):0] * mcand_in;

	assign next_mplier = {{(`NUM_BITS){1'b0}},mplier_in[2*`XLEN-1:(`NUM_BITS)]};
	assign next_mcand  = {mcand_in[(2*`XLEN-1-`NUM_BITS):0],{(`NUM_BITS){1'b0}}};

	//synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			stage_out.valid <= 0;
			prod_in_reg <= 0;
			partial_prod <= 0;
			mplier_out <= 0;
			mcand_out <= 0;
			stage_out <= 0;
		end else if(!stall) begin
			prod_in_reg      <= product_in;
			partial_prod     <= next_partial_product;
			mplier_out       <= next_mplier;
			mcand_out        <= next_mcand;
			stage_out <= stage_in;
		end
	end

	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) begin
		if(reset) begin
			done     <= 1'b0;
		end else begin
			done     <= start & !stall;
		end
	end

endmodule

`endif