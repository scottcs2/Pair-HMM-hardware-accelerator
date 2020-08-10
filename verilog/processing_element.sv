/*
    Trademark CacheMachine (Patent Pending)
    Joseph Nwabueze
    Scott Smith
    Sam Hall
    John Campbell
*/

module processing_element (
	//inputs
	input logic						    clk,          // Signal upon which calculations are stored in registers
	input logic						    reset,          // Reset all values to initial conditions
    input logic                         advance,        // when high, signifies to move to next element in systolic array
    input logic			                enable,         // Should this PE do calculations?
    input transition_probs              probs,          // matrix of transition/emission probabilities
    input pe_calcs [1:0]                pe_vals_in,     // the previous PE's computed value from last cycle, v' in the pdf
    input [63:0]                        prior,


    //outputs
    output pe_calcs [1:0]               pe_vals_out,    // my calculation output. This is the previous cycle's value.
    output logic                        done            // goes high once we've finished our calculations for this element in the array.

);

    parameter 
              mult          = 2'd0,
              add           = 2'd1,
              final_mult    = 2'd2;

    // registers for holding calculations used on next cycle
    pe_calcs [1:0]        my_vals;

    // next state logic
    logic [1:0] state, next_state;
    pe_calcs next_val;
    logic force_reset; //necessary for reusing a multiplier within a single PE computation

    //FPUs:
    logic [6:0][63:0] mult_input_a, mult_input_b, mult_output_z;
    logic [6:0] mult_input_valid, mult_output_done;

    double_multiply multipliers [6:0](
        // inputs
        .input_a(mult_input_a),
        .input_b(mult_input_b),
        .input_valid(mult_input_valid),
        .clk(clk),
        .reset(advance | reset | force_reset),

        // outputs
        .output_z(mult_output_z),
        .output_done(mult_output_done)
    );

    logic [3:0][63:0] add_input_a, add_input_b, add_output_z;
    logic [3:0] add_input_valid, add_done;

    double_adder adders [3:0](        
        // inputs
        .input_a(add_input_a),
        .input_b(add_input_b),
	    .input_valid(add_input_valid),
        .clk(clk),
        .rst(advance | reset),

        // outputs
        .output_z(add_output_z),
        .done(add_done)
    );

    // combinational logic
    always_comb begin

        next_val = my_vals[0];
        next_state = state;
        force_reset = 0;
        mult_input_a = 0;
        mult_input_b = 0;
        add_input_a = 0;
        add_input_b = 0;
        mult_input_valid = 0;
        add_input_valid = 0;

        case(state)
            mult: begin
                if(enable) begin
                    mult_input_a[0] = probs.a_mm;
                    mult_input_b[0] = pe_vals_in[1].m_val;
                    mult_input_valid[0] = 1;

                    mult_input_a[1] = probs.a_im;
                    mult_input_b[1] = pe_vals_in[1].i_val;
                    mult_input_valid[1] = 1;

                    mult_input_a[2] = probs.a_dm;
                    mult_input_b[2] = pe_vals_in[1].d_val;
                    mult_input_valid[2] = 1;

                    mult_input_a[3] = probs.a_mi;
                    mult_input_b[3] = my_vals[0].m_val;
                    mult_input_valid[3] = 1;

                    mult_input_a[4] = probs.a_ii;
                    mult_input_b[4] = my_vals[0].i_val;
                    mult_input_valid[4] = 1;

                    mult_input_a[5] = probs.a_md;
                    mult_input_b[5] = pe_vals_in[0].m_val;
                    mult_input_valid[5] = 1;

                    mult_input_a[6] = probs.a_dd;
                    mult_input_b[6] = pe_vals_in[0].d_val;
                    mult_input_valid[6] = 1;

                    if(mult_output_done == 7'h7f) //if all multiplies are done, move to addition
                        next_state = add;
                end
            end


            add: begin

                add_input_a[0] = mult_output_z[0];
                add_input_b[0] = mult_output_z[1];
                add_input_valid[0] = 1;

                add_input_a[2] = mult_output_z[3];
                add_input_b[2] = mult_output_z[4];
                add_input_valid[2] = 1;

                add_input_a[3] = mult_output_z[5];
                add_input_b[3] = mult_output_z[6];
                add_input_valid[3] = 1;

                add_input_a[1] = add_output_z[0];
                add_input_b[1] = mult_output_z[2];
                add_input_valid[1] = add_done[0];

                if(add_done == 4'hf)begin
                    next_state = final_mult;
                    force_reset = 1;
                end 

            end

            final_mult: begin
                mult_input_a[0] = prior;
                mult_input_b[0] = add_output_z[1];
                mult_input_valid[0] = 1;

                if(mult_output_done[0]) begin
                    next_val.m_val = mult_output_z[0];
                    next_val.i_val = add_output_z[2];
                    next_val.d_val = add_output_z[3];
                end

            end

        endcase
    end

    // sequential logic
    always_ff @(posedge clk) begin
        if(reset) begin
            my_vals <= 0;
            state <= mult;
        end

        else if (advance)begin
            my_vals[1] <= my_vals[0];
            my_vals[0] <= next_val;
            state <= mult;
        end

        else begin
            my_vals <= my_vals;
            state <= next_state;
        end
    end



    // output logic
    assign pe_vals_out[1] = my_vals[1];
    assign pe_vals_out[0] = my_vals[0];
    assign done = (state == final_mult) && mult_output_done[0];

endmodule // complete
