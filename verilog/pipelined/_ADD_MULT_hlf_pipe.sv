`ifndef __ADD_MULT__
`define __ADD_MULT__

module ADD_MULT(
    input clk, reset, input_valid,
    input [63:0] add_left, // f_i or t_a
    input [63:0] add_right, // f_d or t_b
    input [63:0] mult_right, // a_dm or prior
    input TAG tag_in,
    input logic global_stall,

    output logic [63:0] result, // t_a or f_m
    output logic done,
    output TAG tag_out,
    output logic stall
    //output integer num_stalls // not really used so I wired it arbitrarily
);

logic [63:0] mult_input_b; // mult_operand; the "late" operand needed by the multiply
logic [63:0] adder_result;
logic adder_done;

logic adder_stall_in, adder_stall_out, mult_stall_out;
TAG adder_tag_out;
integer adder_num_stalls, mult_num_stalls;

assign adder_stall_in = mult_stall_out || global_stall;
assign stall = adder_stall_out || mult_stall_out;

double_adder_pipe a0(
    .input_a(add_left),
    .input_b(add_right),
    .input_valid(input_valid),
    .clk(clk),
    .reset(reset),
    .tag_in,
    .global_stall(adder_stall_in),
    .mult_operand_in(mult_right),

    //outputs
    .output_z(adder_result),
    .output_done(adder_done),
    .tag_out(adder_tag_out),
    .stall(adder_stall_out),
    .num_stalls(adder_num_stalls),
    .mult_operand_out(mult_input_b)
);

double_multiply_pipe m0(
    .input_a(adder_result),
    .input_b(mult_input_b),
    .input_valid(adder_done),
    .clk(clk),
    .reset(reset),
    .tag_in(adder_tag_out),
    .global_stall,
        
    //outputs
    .output_z(result),
    .output_done(done),
    .tag_out,
    .stall(mult_stall_out),
    .num_stalls(mult_num_stalls)
);

endmodule
`endif