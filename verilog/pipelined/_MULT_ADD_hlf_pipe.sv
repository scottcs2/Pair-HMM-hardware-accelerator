`ifndef __MULT_ADD__
`define __MULT_ADD__

module MULT_ADD(
    input clk, reset, input_valid,
    input [63:0] left_mult_left, // a_mi or a_md
    input [63:0] left_mult_right, // f_m(i-1,j) or f_m(i,j-1)
    input [63:0] right_mult_left, //a_ii or a_dd
    input [63:0] right_mult_right,//f_i(i-1,j) or f_d(i,j-1)
    input TAG tag_in,
    input logic global_stall,

    output logic [63:0]result, // f_i or f_d
    output logic done,
    output TAG tag_out,
    output logic stall
    //output integer num_stalls // not really used so I wired it arbitrarily
);

logic [63:0] left_parent_result, right_parent_result;
logic left_parent_done, right_parent_done;
TAG left_parent_tag_out, right_parent_tag_out;
logic left_parent_stall_in, right_parent_stall_in; // adder_stall_in == global_stall
logic left_parent_stall_out, right_parent_stall_out, adder_stall_out;
logic mults_done;

integer left_parent_num_stalls, right_parent_num_stalls, adder_num_stalls;

assign mults_done = left_parent_done & right_parent_done;
assign left_parent_stall_in = left_parent_done && ~right_parent_done || adder_stall_out || global_stall;
assign right_parent_stall_in = right_parent_done && ~left_parent_done || adder_stall_out || global_stall;
assign stall = left_parent_stall_out || right_parent_stall_out || adder_stall_out;

double_multiply_pipe left_parent(
    .input_a(left_mult_left),
    .input_b(left_mult_right),
    .input_valid(input_valid),
    .clk,
    .reset,
    .tag_in,
    .global_stall(left_parent_stall_in),
        
    //outputs
    .output_z(left_parent_result),
    .output_done(left_parent_done),
    .tag_out(left_parent_tag_out),
    .stall(left_parent_stall_out),
    .num_stalls(left_parent_num_stalls)
);

double_multiply_pipe right_parent(
    .input_a(right_mult_left),
    .input_b(right_mult_right),
    .input_valid(input_valid),
    .clk,
    .reset,
    .tag_in,
    .global_stall(right_parent_stall_in),
    
    //outputs
    .output_z(right_parent_result),
    .output_done(right_parent_done),
    .tag_out(right_parent_tag_out),
    .stall(right_parent_stall_out),
    .num_stalls(right_parent_num_stalls)
);

double_adder_pipe a0(
    .input_a(left_parent_result),
    .input_b(right_parent_result),
    .input_valid(mults_done),
    .clk(clk),
    .reset(reset),
    .tag_in(left_parent_tag_out), // left was chosen arbitrarily: left and right tags should be equal
    .global_stall(global_stall),

    //outputs
    .output_z(result),
    .output_done(done),
    .tag_out,
    .stall(adder_stall_out),
    .num_stalls(adder_num_stalls)
);

endmodule

`endif
