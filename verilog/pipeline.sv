// TODO: describe interconnections between the PE's.


module systolic_array (
	//inputs
    input clock,
    input reset,

	input READS base_reads,
    //input logic [`NUM_PROCS-1:0] [63:0] prior_match, // quality scores for if the reads match <=== in the PRIORS struct now
    //input logic [`NUM_PROCS-1:0] [63:0] prior_neq,   // quality scores for if the reads differ
    input PRIORS prior_reads,
    input logic [$clog2(`MAX_STRING_LENGTH)-1:0] string_length, //the length of the strings
    input transition_probs tp,


    //outputs
    output logic complete,      //complete asserts when all computation is finished
    output logic [$clog2(`MAX_STRING_LENGTH)-1:0] read_index_x, read_index_y,
    output logic read_x_valid, read_y_valid,
    output logic [63:0] final_val
);

logic [`NUM_PROCS-1:0] enables, next_enables; // controls enable signal for each PE
logic [`NUM_PROCS-1:0] dones;
logic advance, sweep; // tells every PE to move over one
logic [$clog2(`NUM_PROCS)-1:0] num_active; // number of active PEs
logic need_data;
logic [`NUM_PROCS-1:0] [63:0] pe_priors, next_pe_priors; // the chosen prior to be passed to PE


pe_calcs [`NUM_PROCS-1:0] [1:0] pe_calcs_buffers; // used to handoff pe_calcs between PEs
// PE_n will read from pe_calcs_buffers[n] to get its dependencies
// PE_0 will be an edge case where the values in pe_calcs_buffers[0] will be pre-calculated
// multidimensional as each PE must store 2 pe_calcs for the next PE
// will need to shift when advance is high
pe_calcs [1:0] last_pe_output;
pe_calcs [`MAX_STRING_LENGTH-1:0] last_pe_checkpoint, next_last_pe_checkpoint; // only used if computation requires multiple passes, 
                                                      // stores the computations from the last PE

logic [$clog2(`MAX_STRING_LENGTH)-1:0] pass_counter, next_pass_counter, bases_remaining; //which pass we are on


STRING [`NUM_PROCS-1:0] ref_read, next_ref_read; //shift register that stores up to NUM_PROCS bases of the reference

logic [`MAX_COUNT_WIDTH-1:0] counter, next_counter; //counter for determining PE enables

ARRAY_STATE state, next_state;

//variables for the final adder
logic [63:0] input_a, input_b, temp_final_val, next_temp_result, temp_result;
logic input_valid, temp_complete, reset_addr;

generate
    genvar i;
        for(i = 0; i < `NUM_PROCS-1; ++i) begin : pes
            processing_element pe(
                .clk(clock),
                .reset(reset | sweep),
                .advance(advance),
                .enable(enables[i]),
                .probs(tp),
                .prior(pe_priors[i]),
                .pe_vals_in(pe_calcs_buffers[i]),

                .pe_vals_out(pe_calcs_buffers[i+1]),
                .done(dones[i])
            );
        end : pes
endgenerate

processing_element pe_last(
    .clk(clock),
    .reset(reset | sweep),
    .advance(advance),
    .enable(enables[`NUM_PROCS-1]),
    .probs(tp),
    .prior(pe_priors[`NUM_PROCS-1]),
    .pe_vals_in(pe_calcs_buffers[`NUM_PROCS-1]),

    .pe_vals_out(last_pe_output), //this will write into the checkpoint if multi pass is needed
    .done(dones[`NUM_PROCS-1])
);

double_adder result_adder(
    .input_a(input_a),
    .input_b(input_b),
	.input_valid(input_valid),
    .clk(clock),
    .rst(reset_addr),
    .output_z(temp_final_val),
    .done(temp_complete)
);

always_comb begin
    next_counter = counter;
    next_state = state;
    next_enables = enables;
    next_pass_counter = pass_counter;
    next_ref_read = ref_read;
    next_pe_priors = pe_priors;
    next_last_pe_checkpoint = last_pe_checkpoint;
    read_x_valid = 0;
    read_y_valid = 0;
    read_index_x = 0;
    read_index_y = 0;
    advance = 0;
    sweep = 0;

    input_a = 0;
    input_b = 0;
    input_valid = 0;
    complete = 0;
    final_val = 0;
    reset_addr = 0;
    next_temp_result = temp_result;

    bases_remaining = string_length - pass_counter;

    pe_calcs_buffers[0] = 0;
    //if we need to read from the checkpoint
    if(counter <= string_length) begin
        if(counter == 1) begin
	        if(pass_counter == 0) begin
                pe_calcs_buffers[0][0] = 0;
	            pe_calcs_buffers[0][1] = 0;
                pe_calcs_buffers[0][1].m_val = 64'h3f800000;
	        end
	        else begin
                pe_calcs_buffers[0][0] = last_pe_checkpoint[0];
                pe_calcs_buffers[0][1] = 0;
	        end
        end

        else begin
            pe_calcs_buffers[0][0] = last_pe_checkpoint[counter-1];
            pe_calcs_buffers[0][1] = last_pe_checkpoint[counter-2];
        end
        
    end

    case(state)

        INIT_RUN: begin //fetch x and y
            read_index_x = 0;
            read_index_y = pass_counter;
            read_x_valid = 1;
            read_y_valid = 1; 

            //if we just wrapped around, write the most recent result from the last PE into the last checkpoint index
            if(pass_counter > 0) begin
                next_last_pe_checkpoint[string_length-1] = last_pe_output[0];
                sweep = 1;
            end

            next_state = INIT_RUN2;
        end

        INIT_RUN2: begin 

            
            
            if(prior_reads.valid && base_reads.valid)begin
                
                next_enables[0] = 1; //only enable the first PE

                //arbitrate the prior for the first PE
		
                if(base_reads.reference == base_reads.exp[0])
                    next_pe_priors[0] = prior_reads.match[0];

                else 
                    next_pe_priors[0] = prior_reads.neq[0];
                //push in the first reference base
                next_ref_read[0] = base_reads.reference;
                next_state = FETCH_DATA;
            end


            
        end

        //while computation is happening, in the background...
        FETCH_DATA: begin //fetch the next x
            
            read_index_x = counter;
            read_x_valid = 1;
            next_state = WAIT;
            
            //write the previous result of the last PE into the checkpoint
            if(enables[`NUM_PROCS-1]) 
                next_last_pe_checkpoint[counter - `NUM_PROCS-1] = last_pe_output[0];

        end

        WAIT: begin
            //use the enables to check dones
            for(int i=0; i < `NUM_PROCS; ++i)begin
                if(enables[i] && ~dones[i])
                    break;
                else if(i == `NUM_PROCS-1) begin //if we've seen all the dones we're looking for
                    advance = 1;
                    next_counter = counter + 1;
                    
                    //if we just finished the last sweep
                    if(bases_remaining <= `NUM_PROCS && counter == string_length + `NUM_PROCS -1) begin
                        next_state = RESULT;
			            reset_addr = 1;
		            end
                    //if this was the last computation of a sweep
                    else if(counter == string_length + `NUM_PROCS-1) begin
                        next_counter = 1;
                        next_state = INIT_RUN;
                        next_pass_counter = pass_counter + `NUM_PROCS;
                    end

                    else begin
                        //shift in the next reference base, and choose priors
                        next_ref_read[0] = base_reads.reference;
                        for(int i = 0; i < `NUM_PROCS-1; ++i) begin
                            next_ref_read[i+1] = ref_read[i];
                        end

                        //set next_enables based on the next_counter value
                        for(int i=0; i < `NUM_PROCS; ++i)begin
                            if(next_counter > i && next_counter-i <= string_length && i < bases_remaining)
                                next_enables[i] = 1;
			    else 
				next_enables[i] = 0;
                        end

                        //set priors based on comparison between exp and next_ref_read values
                        //might need to change to i-1 if this becomes critical path
                        for(int i=0; i < `NUM_PROCS; ++i) begin
                            if(next_ref_read[i] == base_reads.exp[i]) 
                                next_pe_priors[i] = prior_reads.match[i];
                            else
                                next_pe_priors[i] = prior_reads.neq[i];
                        end
                        next_state = FETCH_DATA;
                    end
                    
                    
                    
                end


            end    
            
        end //WAIT state

        RESULT: begin
            input_a = bases_remaining == `NUM_PROCS ? last_pe_output[0].m_val : pe_calcs_buffers[bases_remaining][0].m_val;
            input_b = bases_remaining == `NUM_PROCS ? last_pe_output[0].i_val : pe_calcs_buffers[bases_remaining][0].i_val;
            input_valid = 1;

            if(temp_complete) begin
                next_temp_result = temp_final_val;
                reset_addr = 1;
                next_state = RESULT_2;
            end
        end

        RESULT_2: begin
            input_a = temp_result;
            input_b = bases_remaining == `NUM_PROCS ? last_pe_output[0].d_val : pe_calcs_buffers[bases_remaining][0].d_val;
            input_valid = 1;
            
            complete = temp_complete;
            final_val = temp_final_val;


        end
    endcase
end



always_ff @(posedge clock) begin
    if(reset) begin
        counter <= 1;
        enables <= 0;
        state <= INIT_RUN;
        pass_counter <= 0;
        ref_read <= {`NUM_PROCS-1{STRING_T}};
        pe_priors <= 0;
        last_pe_checkpoint <= 0; 
        temp_result <= 0;
    end 
    else begin
        counter <= next_counter;
        enables <= next_enables;
        state <= next_state;
        pass_counter <= next_pass_counter;
        ref_read <= next_ref_read;
        pe_priors <= next_pe_priors;
        last_pe_checkpoint <= next_last_pe_checkpoint;
        temp_result <= next_temp_result;
    end
end

endmodule
