`ifndef SYSTOLIC_TESTBENCH_SV
`define SYSTOLIC_TESTBENCH_SV
module systolic_testbench;

    logic [`NUM_PROCS-1:0] enables;
    logic advance_out, sweep_out;
    real num_enabled;
    real active_cycles;
    real total_cycles;

    logic clk, reset, complete, read_x_valid, read_y_valid;
    READS base_reads, next_base_reads;
    PRIORS prior_reads, next_prior_reads;
    logic [$clog2(`MAX_STRING_LENGTH)-1:0] string_length, y_length;
    transition_probs tp;
    logic [$clog2(`MAX_STRING_LENGTH)-1:0] read_index_x, read_index_y;
    logic [63:0] final_val;
    int fd_r, read_length, fd_w;
    real qi,qd,qg, ans, temp;
    string line;
    STRING[`MAX_STRING_LENGTH-1:0] reference, exp;
    int q_scores [`MAX_STRING_LENGTH-1:0]; //integer quality scores
    real q_scores_real [`MAX_STRING_LENGTH-1:0];
    systolic_array sa0(
        //inputs
        .clk(clk),
        .reset(reset),
        .base_reads(base_reads),
        .prior_reads(prior_reads),
        .string_length(string_length), //the length of the strings
        .y_length(y_length),
        .tp(tp),


        //outputs
        .complete(complete),      //complete asserts when all computation is finished
        .read_index_x(read_index_x), 
        .read_index_y(read_index_y),
        .read_x_valid(read_x_valid), 
        .read_y_valid(read_y_valid),
        .final_val(final_val),
	.enables,
	.advance_out,
	.sweep_out
    );

    always begin
        #5
        clk = ~clk;
    end

    task wait_for_stable_output; begin
        while(~complete)begin
	    // total_cycles += 1;
	    if(advance_out || sweep_out) begin
            //$display("TOGGLED %d", num_enabled);
	    	for(int i = 0; i < `NUM_PROCS-1; ++i) begin
                num_enabled += $itor(enables[i]);
                active_cycles += 20 * (num_enabled / $itor(`NUM_PROCS));
                total_cycles += 20;
		    end
		    num_enabled = 0;
	    end
            @(posedge clk);
        end
    end
    endtask

    always_comb begin
        next_base_reads = base_reads;
        next_prior_reads = prior_reads;
        if(read_x_valid) begin
            next_base_reads.reference = reference[read_index_x];
            next_base_reads.valid = 1;
        end

        if(read_y_valid) begin
            next_base_reads.exp = exp[read_index_y];
            
            temp = 1 - q_scores_real[read_index_y];
            next_prior_reads.match = $realtobits(temp);

            temp = q_scores_real[read_index_y];
            next_prior_reads.neq = $realtobits(temp);

            next_prior_reads.valid = 1;
        end
    end

    always_ff @(posedge clk) begin
        if(reset)begin
            base_reads <= 0;
            prior_reads <= 0;
        end

        else begin
            base_reads <= next_base_reads;
            prior_reads <= next_prior_reads;
        end

    end

    initial begin
	clk = 0;
	reset = 0;
	exp = {`MAX_STRING_LENGTH{STRING_T}};
	qi = 0;
	qd = 0;
	qg = 0;

	reference = {`MAX_STRING_LENGTH{STRING_T}};
	
	
	tp = 0;
	ans = 0;
        //open the test file
        fd_r = $fopen ("test.data", "r");
        if(!fd_r) begin
            $display("failed to open test file!");
            $finish;
        end

        //grab the first line, this contains the time stamp so yeet that shit
        $fgets(line, fd_r);
        //next, get the length
        $fgets(line,fd_r);	
        read_length = line.atoi();
        string_length = read_length;
        $fgets(line,fd_r); //the second length, the y dimension
        y_length = line.atoi();
        $fgets(line, fd_r);
        qi = line.atoreal();
        $fgets(line, fd_r);
        qd = line.atoreal();
        $fgets(line, fd_r);
        qg = line.atoreal();


        //set the reference string
        $fgets(line, fd_r);
        for(int i=0; i <read_length; ++i) begin
            if(line.getc(i) == "T")begin
                reference[i] = STRING_T;
	    end
            else if(line[i] == "C")
                reference[i] = STRING_C;
            else if(line[i] == "G")
                reference[i] = STRING_G;
            else if(line[i] == "A")
                reference[i] = STRING_A;
            else
                reference[i] = STRING_DASH;
        end

        //set the experimental string
        $fgets(line, fd_r);
        for(int i=0; i<y_length; ++i)begin
            if(line[i] == "T")
                exp[i] = STRING_T;
            else if(line[i] == "C")
                exp[i] = STRING_C;
            else if(line[i] == "G")
                exp[i] = STRING_G;
            else if(line[i] == "A")
                exp[i] = STRING_A;
            else
                exp[i] = STRING_DASH;
        end

        //get the quality scores
        $fgets(line, fd_r);
        for(int i=0; i<y_length; ++i)begin
            q_scores[i] = line[i];
            //10^-(q/10)
	    q_scores_real[i] = q_scores[i]/-10.0;
            q_scores_real[i] = 10.0**(q_scores_real[i]); 
        end


        //assign transition probs
        ans = 1-(qi + qd);
        tp.a_mm = $realtobits(ans);

        ans = 1-qg;
        tp.a_im = $realtobits(ans);
        tp.a_dm = tp.a_im;

        ans = qi;
        tp.a_mi = $realtobits(ans);

        ans = qg;
        tp.a_ii = $realtobits(ans);

        ans = qd;
        tp.a_md = $realtobits(ans);

        ans = qg;
        tp.a_dd = $realtobits(ans);

        



	num_enabled = 0;


        @(negedge clk);
        reset = 1;
        @(negedge clk);
        reset = 0;
        $display("start time is %0t",$time); 
        wait_for_stable_output();
        $display("end time is %0t",$time); 
        $display("final value = %e",$bitstoreal(final_val));
        //write the result to the output file
        fd_w = $fopen ("verilog_output.out", "w");
        $fdisplay (fd_w, $bitstoreal(final_val));

        $display("UTILIZATION: %f", active_cycles / total_cycles);

        $finish;
    end

endmodule
`endif
