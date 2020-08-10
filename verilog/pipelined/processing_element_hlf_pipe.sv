`ifndef __PROCESSING_ELEMENT_HALVED__
`define __PROCESSING_ELEMENT_HALVED__

module processing_element_hlf (
    //inputs
	input logic						    clk,            // Signal upon which calculations are stored in registers
	input logic						    reset,          // Reset all values to initial conditions
    input logic                         advance,        // when high, signifies to move to next element in systolic array
    input logic			                enable,         // Should this PE do calculations?
    input logic                         set_tb_special, // when high use special tb value
    input transition_probs              probs,          // matrix of transition/emission probabilities
    input pe_calcs                      pe_vals_in,     // the previous PE's computed value from last cycle, v' in the pdf
    input [63:0]                        prior,
    input TAG                           tag_in,
    input logic                         global_stall,

    //outputs
    output pe_calcs                     pe_vals_out,    // my calculation output. This is the previous cycle's value.
    output logic                        done,            // goes high once we've finished our calculations for this element in the array.
    output TAG                          tag_out,
    output logic                        stall
);

pe_calcs my_vals;
pe_calcs next_vals;

logic tree_reset;
logic [4:0] tree_dones;

pe_calcs my_vals_use;

TAG f_i_tag_out, f_d_tag_out, f_m_tag_out, t_a_tag_out, t_b_tag_out; // these should all be the same
logic f_i_stall_out, f_d_stall_out, f_m_stall_out, t_a_stall_out, t_b_stall_out;
logic f_i_stall_in, f_d_stall_in, f_m_stall_in, t_a_stall_in, t_b_stall_in;

// VERY GOOD LOGIC BELOW
// GAZE UPON ITS MAJESTY
assign f_i_stall_in = (tree_dones[0] && !(tree_dones[1] && tree_dones[2] && tree_dones[3] && tree_dones[4])) || global_stall;
assign f_d_stall_in = (tree_dones[1] && !(tree_dones[0] && tree_dones[2] && tree_dones[3] && tree_dones[4])) || global_stall;
assign f_m_stall_in = (tree_dones[2] && !(tree_dones[0] && tree_dones[1] && tree_dones[3] && tree_dones[4])) || global_stall;
assign t_a_stall_in = (tree_dones[3] && !(tree_dones[0] && tree_dones[1] && tree_dones[2] && tree_dones[4])) || global_stall;
assign t_b_stall_in = (tree_dones[4] && !(tree_dones[0] && tree_dones[1] && tree_dones[2] && tree_dones[3])) || global_stall;

assign stall = f_i_stall_out || f_d_stall_out || f_m_stall_out || t_a_stall_out || t_b_stall_out || global_stall;

assign tag_out = f_i_tag_out; // picked arbitrarily because they should all be the same

assign tree_reset = reset | advance;
assign done = tree_dones == 5'b11111;

// F_I computation #0
MULT_ADD f_i(
    .clk(clk),
    .reset(tree_reset),
    .input_valid(enable),
    .left_mult_left(probs.a_mi),
    .left_mult_right(my_vals.m_val),
    .right_mult_left(probs.a_ii),
    .right_mult_right(my_vals.i_val),
    .tag_in,
    .global_stall(f_i_stall_in),

    //outputs
    .result(next_vals.i_val),
    .done(tree_dones[0]),
    .tag_out(f_i_tag_out),
    .stall(f_i_stall_out)
);

// F_D computation #1
MULT_ADD f_d(
    .clk(clk),
    .reset(tree_reset),
    .input_valid(enable),
    .left_mult_left(probs.a_md),
    .left_mult_right(pe_vals_in.m_val),
    .right_mult_left(probs.a_dd),
    .right_mult_right(pe_vals_in.d_val),
    .tag_in,
    .global_stall(f_d_stall_in),

    //outputs
    .result(next_vals.d_val),
    .done(tree_dones[1]),   
    .tag_out(f_d_tag_out),
    .stall(f_d_stall_out)
);

// F_M computation #3
ADD_MULT f_m(
    .clk(clk), 
    .reset(tree_reset), 
    .input_valid(enable),
    .add_left(my_vals.t_a),
    .add_right(set_tb_special ? pe_vals_in.t_b : my_vals.t_b),
    .mult_right(prior),
    .tag_in,
    .global_stall(f_m_stall_in),

    //outputs
    .result(next_vals.m_val),
    .done(tree_dones[2]),
    .tag_out(f_m_tag_out),
    .stall(f_m_stall_out)
);

// T_A computation #2
ADD_MULT t_a(
    .clk(clk), 
    .reset(tree_reset), 
    .input_valid(enable),
    .add_left(pe_vals_in.i_val),
    .add_right(pe_vals_in.d_val),
    .mult_right(probs.a_dm),
    .tag_in,
    .global_stall(t_a_stall_in),

    //outputs
    .result(next_vals.t_a),
    .done(tree_dones[3]),
    .tag_out(t_a_tag_out),
    .stall(t_a_stall_out)
);

//T_B computation #4
ADD_MULT t_b(
    .clk(clk), 
    .reset(tree_reset), 
    .input_valid(enable),
    .add_left(probs.a_mm),
    .add_right(0), // special case
    .mult_right(pe_vals_in.m_val),
    .tag_in,
    .global_stall(t_b_stall_in),

    //outputs
    .result(next_vals.t_b),
    .done(tree_dones[4]),
    .tag_out(t_b_tag_out),
    .stall(t_b_stall_out)
);

/*
//T_B computation #4
double_multiply t_b(
    // inputs
    .input_a(probs.a_mm),
    .input_b(pe_vals_in.m_val),
    .input_valid(enable),
    .clk(clk),
    .reset(tree_reset),

    // outputs
    .output_z(next_vals.t_b),
    .output_done(tree_dones[4])
);
*/

always_ff @(posedge clk) begin
    if(reset) begin
        my_vals <= 0;
    end

    else if (advance && enable)begin
        my_vals <= next_vals;
    end

    else begin
        my_vals <= my_vals;
    end
end

// output logic
assign pe_vals_out = my_vals;

endmodule

`endif 
