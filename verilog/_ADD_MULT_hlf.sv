`ifndef __ADD_MULT__
`define __ADD_MULT__

module ADD_MULT(
    input clk, reset, input_valid,
    input [63:0] add_left, // f_i or t_a
    input [63:0] add_right, // f_d or t_b
    input [63:0] mult_right, // a_dm or prior


    output logic [63:0] result, // t_a or f_m
    output logic done
);

logic [63:0] adder_result;
logic adder_done;

double_multiply m0(
    .input_a(adder_result),
    .input_b(mult_right),
    .clk(clk),
    .reset(reset),
    .input_valid(adder_done),
        
    //outputs
    .output_z(result),
    .output_done(done)
);

double_adder a0(
    .clk(clk),
    .reset(reset),
    .input_a(add_left),
    .input_b(add_right),
    .input_valid(input_valid),

    //outputs
    .output_z(adder_result),
    .done(adder_done)
);

endmodule

`endif