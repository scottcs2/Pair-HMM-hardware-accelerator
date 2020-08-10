`ifndef __MULT_ADD__
`define __MULT_ADD__

module MULT_ADD(
    input clk, reset, input_valid,
    input [63:0] left_mult_left, // a_mi or a_md
    input [63:0] left_mult_right, // f_m(i-1,j) or f_m(i,j-1)
    input [63:0] right_mult_left, //a_ii or a_dd
    input [63:0] right_mult_right,//f_i(i-1,j) or f_d(i,j-1)
    

    output logic [63:0]result, // f_i or f_d
    output logic done
);

logic [63:0] left_parent_result, right_parent_result;
logic left_parent_done, right_parent_done;
logic mults_done;

assign mults_done = left_parent_done & right_parent_done;

double_multiply left_parent(
    .input_a(left_mult_left),
    .input_b(left_mult_right),
    .clk,
    .reset,
    .input_valid(input_valid),
        
    //outputs
    .output_z(left_parent_result),
    .output_done(left_parent_done)
);

double_multiply right_parent(
    .input_a(right_mult_left),
    .input_b(right_mult_right),
    .clk,
    .reset,
    .input_valid(input_valid),
    
    //outputs
    .output_z(right_parent_result),
    .output_done(right_parent_done)
);

double_adder a0(
    .clk(clk),
    .reset(reset),
    .input_a(left_parent_result),
    .input_b(right_parent_result),
    .input_valid(mults_done),

    //outputs
    .output_z(result),
    .done(done)
);

endmodule

`endif
