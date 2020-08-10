`ifndef __DOUBLE_MULTIPLY_STAGES__
`define __DOUBLE_MULTIPLY_STAGES__

module doublemult_unpack (
    
    input logic [63:0] input_a,
    input logic [63:0] input_b,
    input              valid,
    input TAG          tag_in,
    output double_multiply_pipeline_reg stage_out
    

);

    always_comb begin
        stage_out = '0;
        if(valid) begin
            stage_out.a_m = input_a[51:0];
            stage_out.b_m = input_b[51:0];
            stage_out.a_e = input_a[62:52] - 1023;
            stage_out.b_e = input_b[62:52] - 1023;
            stage_out.a_s = input_a[63];
            stage_out.b_s = input_b[63];
            stage_out.tag = tag_in;
            stage_out.valid = 1;
        end

    end


endmodule

module doublemult_specialcases (
    input double_multiply_pipeline_reg stage_in, // intermidiate
    output double_multiply_pipeline_reg stage_out
);

    logic [52:0] a_m, b_m, z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;

    assign a_m = stage_in.a_m;
    assign b_m = stage_in.b_m;
    assign z_m = stage_in.z_m;
    assign a_e = stage_in.a_e;
    assign b_e = stage_in.b_e;
    assign z_e = stage_in.z_e;
    assign a_s = stage_in.a_s; 
    assign b_s = stage_in.b_s;
    assign z_s = stage_in.z_s;
    assign guard = stage_in.guard;
    assign round_bit = stage_in.round_bit;
    assign sticky = stage_in.sticky;

    always_comb begin
        stage_out = stage_in;
        stage_out.standby = stage_in.standby;
        //if a is NaN or b is NaN return NaN 
        if ((a_e == 1024 && a_m != 0) ||
            (b_e == 1024 && b_m != 0)) 
        begin
            stage_out.z[63]     = 1;
            stage_out.z[62:52]  = 2047;
            stage_out.z[51]     = 1;
            stage_out.z[50:0]   = 0;
            stage_out.standby = 1;
            // stage_out.state     = standby;
            //if a is inf return inf
        end else if (a_e == 1024) 
        begin
            stage_out.z[63]     = a_s ^ b_s;
            stage_out.z[62:52]  = 2047;
            stage_out.z[51:0]   = 0;
            stage_out.standby = 1;
            // stage_out.state     = standby;
            //if b is zero return NaN
            if (($signed(b_e) == -1023) && (b_m == 0))
            begin
                stage_out.z[63]     = 1;
                stage_out.z[62:52]  = 2047;
                stage_out.z[51]     = 1;
                stage_out.z[50:0]   = 0;
                stage_out.standby = 1;
                // stage_out.state     = standby;
            end
            
        //if b is inf return inf
        end else if (b_e == 1024) 
        begin
            stage_out.z[63]     = a_s ^ b_s;
            stage_out.z[62:52]  = 2047;
            stage_out.z[51:0]   = 0;
            //if b is zero return NaN
            if (($signed(a_e) == -1023) && (a_m == 0)) 
            begin
                stage_out.z[63]     = 1;
                stage_out.z[62:52]  = 2047;
                stage_out.z[51]     = 1;
                stage_out.z[50:0]   = 0;
                stage_out.standby = 1;
                // stage_out.state     = standby;
            end
            stage_out.standby = 1;
            // stage_out.state = standby;
            
        //if a is zero return zero
        end else if (($signed(a_e) == -1023) && (a_m == 0)) 
        begin
            stage_out.z[63] = a_s ^ b_s;
            stage_out.z[62:52] = 0;
            stage_out.z[51:0] = 0;
            stage_out.standby = 1;
            // stage_out.state = standby;
        //if b is zero return zero
        end else if (($signed(b_e) == -1023) && (b_m == 0)) 
        begin
            stage_out.z[63] = a_s ^ b_s;
            stage_out.z[62:52] = 0;
            stage_out.z[51:0] = 0;
            stage_out.standby = 1;
            // stage_out.state = standby;
        end else 
        begin
            //Denormalised Number
            if ($signed(a_e) == -1023) 
            begin
                stage_out.a_e = -1022;
            end else 
            begin
                stage_out.a_m[52] = 1;
            end
            //Denormalised Number
            if ($signed(b_e) == -1023) 
            begin
                stage_out.b_e = -1022;
            end else 
            begin
                stage_out.b_m[52] = 1;
            end
            // stage_out.state = normalise;
            stage_out.standby = 0;
        end
    end
endmodule

module doublemult_normalise(
    input double_multiply_pipeline_reg stage_in, // intermidiate
    output double_multiply_pipeline_reg stage_out
);

    logic [52:0] a_m, b_m, z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;

    assign a_m = stage_in.a_m;
    assign b_m = stage_in.b_m;
    assign z_m = stage_in.z_m;
    assign a_e = stage_in.a_e;
    assign b_e = stage_in.b_e;
    assign z_e = stage_in.z_e;
    assign a_s = stage_in.a_s; 
    assign b_s = stage_in.b_s;
    assign z_s = stage_in.z_s;
    assign guard = stage_in.guard;
    assign round_bit = stage_in.round_bit;
    assign sticky = stage_in.sticky;

    logic [5:0] shift_counter_a, shift_counter_b;

    always_comb begin
	    shift_counter_a = 0;
	    shift_counter_b = 0;
        stage_out = stage_in;
        if(!stage_in.standby) begin
            if(!a_m[52]) begin
                for(int i = 52; i >= 0; i--) begin
                    if(a_m[i] == 1) begin
                        shift_counter_a = 52-i;
                        break;
                    end
                end
            end 
            
            if(!b_m[52]) begin
                for(int i = 52; i >= 0; i--) begin
                    if(b_m[i] == 1) begin
                        shift_counter_b = 52-i;
                        break;
                    end
                end
            end
            
            stage_out.a_m = a_m << shift_counter_a;
            stage_out.a_e = a_e - shift_counter_a;
            
            stage_out.b_m = b_m << shift_counter_b;
            stage_out.b_e = b_e - shift_counter_b;
        end
    end
endmodule



module doublemult_normalise1(
    input double_multiply_pipeline_reg stage_in,
    output double_multiply_pipeline_reg stage_out,
    output logic stall_out
    
);

    always_comb begin
        stall_out = 1'b0;
        stage_out = stage_in;
        if(!stage_in.standby) begin
            if (stage_in.z_m[52] == 0) 
            begin
                stage_out.z_e = stage_in.z_e - 1;
                stage_out.z_m = stage_in.z_m << 1;
                stage_out.z_m[0] = stage_in.guard;
                stage_out.guard = stage_in.round_bit;
                stage_out.round_bit = 0;
                stall_out = stage_in.valid;
            end
        end
    end
    
endmodule

module doublemult_normalise2(
    input double_multiply_pipeline_reg stage_in, // intermidiate
    output double_multiply_pipeline_reg stage_out,
    output logic stall_out
);

    logic [52:0] a_m, b_m, z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;

    assign a_m = stage_in.a_m;
    assign b_m = stage_in.b_m;
    assign z_m = stage_in.z_m;
    assign a_e = stage_in.a_e;
    assign b_e = stage_in.b_e;
    assign z_e = stage_in.z_e;
    assign a_s = stage_in.a_s; 
    assign b_s = stage_in.b_s;
    assign z_s = stage_in.z_s;
    assign guard = stage_in.guard;
    assign round_bit = stage_in.round_bit;
    assign sticky = stage_in.sticky;
    
    always_comb begin
        stall_out = 1'b0;
        stage_out = stage_in;
        if(!stage_in.standby) begin
            if ($signed(z_e) < -1022) 
            begin
                stage_out.z_e = z_e + 1;
                stage_out.z_m = z_m >> 1;
                stage_out.guard = z_m[0];
                stage_out.round_bit = guard;
                stage_out.sticky = sticky | round_bit;
                stall_out = stage_in.valid;
            end
        end
    end
endmodule


module doublemult_pack(
    input double_multiply_pipeline_reg stage_in, // intermidiate
    output double_multiply_pipeline_reg stage_out
);

    logic [52:0] a_m, b_m, z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;

    assign a_m = stage_in.a_m;
    assign b_m = stage_in.b_m;
    assign z_m = stage_in.z_m;
    assign a_e = stage_in.a_e;
    assign b_e = stage_in.b_e;
    assign z_e = stage_in.z_e;
    assign a_s = stage_in.a_s; 
    assign b_s = stage_in.b_s;
    assign z_s = stage_in.z_s;
    assign guard = stage_in.guard;
    assign round_bit = stage_in.round_bit;
    assign sticky = stage_in.sticky;

    always_comb begin
        stage_out = stage_in;
        if(!stage_in.standby) begin
            // round:
            if (guard && (round_bit | sticky | z_m[0])) 
            begin
                stage_out.z_m = z_m + 1;
                if (z_m == 53'h1fffffffffffff) 
                begin
                    stage_out.z_e = z_e + 1;
                end
            end
        
            // pack:
            stage_out.z[51 : 0] = stage_out.z_m[51:0];
            stage_out.z[62 : 52] = stage_out.z_e[11:0] + 1023;
            stage_out.z[63] = z_s;
            if ($signed(stage_out.z_e) == -1022 && stage_out.z_m[52] == 0) 
            begin
                stage_out.z[62 : 52] = 0;
            end
            //if overflow occurs, return inf
            if ($signed(stage_out.z_e) > 1023) 
            begin
                stage_out.z[51 : 0] = 0;
                stage_out.z[62 : 52] = 2047;
                stage_out.z[63] = z_s;
            end
            stage_out.standby = 1;
        end
    end

endmodule

`endif