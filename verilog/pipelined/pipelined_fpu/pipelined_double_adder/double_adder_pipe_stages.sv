`ifndef DOUBLE_ADDER_PIPE_STAGES_SV
`define DOUBLE_ADDER_PIPE_STAGES_SV


module doubleadd_unpack (

    // inputs
    input logic [63:0]  input_a,
    input logic [63:0]  input_b,
    input logic         valid,
    input TAG           tag_in,
    input logic [63:0]  mult_operand,

    //outputs
    output double_adder_pipeline_reg stage_out

);

    always_comb begin
        stage_out = '0;
        if(valid) begin
            stage_out.a_m   = {input_a[51 : 0], 3'd0};
            stage_out.b_m   = {input_b[51 : 0], 3'd0};
            stage_out.a_e   = input_a[62 : 52] - 1023;
            stage_out.b_e   = input_b[62 : 52] - 1023;
            stage_out.a_s   = input_a[63];
            stage_out.b_s   = input_b[63];
            stage_out.tag   = tag_in;
            stage_out.valid = valid;
            stage_out.mult_operand = mult_operand;
        end

    end

endmodule


module doubleadd_specialcases (

    input double_adder_pipeline_reg  stage_in,
    output double_adder_pipeline_reg stage_out

);

    logic [55:0] a_m, b_m;
    logic [52:0] z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;
    logic [56:0] sum;

    assign a_m          =   stage_in.a_m;
    assign b_m          =   stage_in.b_m;
    assign z_m          =   stage_in.z_m;
    assign a_e          =   stage_in.a_e;
    assign b_e          =   stage_in.b_e;
    assign z_e          =   stage_in.z_e;
    assign a_s          =   stage_in.a_s; 
    assign b_s          =   stage_in.b_s;
    assign z_s          =   stage_in.z_s;
    assign guard        =   stage_in.guard;
    assign round_bit    =   stage_in.round_bit;
    assign sticky       =   stage_in.sticky;
    assign sum          =   stage_in.sum;

    always_comb begin

        stage_out = stage_in;

        if ((a_e == 1024 && a_m != 0) || 
                (b_e == 1024 && b_m != 0)) begin

            stage_out.output_z[63] = 1;
            stage_out.output_z[62:52] = 2047;
            stage_out.output_z[51] = 1;
            stage_out.output_z[50:0] = 0;
            stage_out.standby = 1;

        //if a is inf return inf
        end else if (a_e == 1024) begin

            stage_out.output_z[63] = a_s;
            stage_out.output_z[62:52] = 2047;
            stage_out.output_z[51:0] = 0;

            //if a is inf and signs don't match return nan
            if ((b_e == 1024) && (a_s != b_s)) begin

                stage_out.output_z[63] = 1;
                stage_out.output_z[62:52] = 2047;
                stage_out.output_z[51] = 1;
                stage_out.output_z[50:0] = 0;

            end

            stage_out.standby = 1;

        //if b is inf return inf
        end else if (b_e == 1024) begin

            stage_out.output_z[63] = b_s;
            stage_out.output_z[62:52] = 2047;
            stage_out.output_z[51:0] = 0;
            stage_out.standby = 1;
            
        //if a is zero return b
        end else if ((($signed(a_e) == -1023) && (a_m == 0)) && 
                        (($signed(b_e) == -1023) && (b_m == 0))) begin

            stage_out.output_z[63] = a_s & b_s;
            stage_out.output_z[62:52] = b_e[10:0] + 1023;
            stage_out.output_z[51:0] = b_m[55:3];
            stage_out.standby = 1;

        //if a is zero return b
        end else if (($signed(a_e) == -1023) && (a_m == 0)) begin

            stage_out.output_z[63] = b_s;
            stage_out.output_z[62:52] = b_e[10:0] + 1023;
            stage_out.output_z[51:0] = b_m[55:3];
            stage_out.standby = 1;

        //if b is zero return a
        end else if (($signed(b_e) == -1023) && (b_m == 0)) begin

            stage_out.output_z[63] = a_s;
            stage_out.output_z[62:52] = a_e[10:0] + 1023;
            stage_out.output_z[51:0] = a_m[55:3];
            stage_out.standby = 1;

        end else begin

            //Denormalised Number
            if ($signed(a_e) == -1023) begin
                stage_out.a_e = -1022;
            end else begin
                stage_out.a_m[55] = 1;
            end
            //Denormalised Number
            if ($signed(b_e) == -1023) begin
                stage_out.b_e = -1022;
            end else begin
                stage_out.b_m[55] = 1;
            end
            //stage_out.state = align;
            stage_out.standby = 0;
        end

    end

endmodule

module doubleadd_align (

    input   double_adder_pipeline_reg stage_in,
    output  double_adder_pipeline_reg stage_out

);

    logic [55:0] a_m, b_m;
    logic [52:0] z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;
    logic [56:0] sum;

    assign a_m          =   stage_in.a_m;
    assign b_m          =   stage_in.b_m;
    assign z_m          =   stage_in.z_m;
    assign a_e          =   stage_in.a_e;
    assign b_e          =   stage_in.b_e;
    assign z_e          =   stage_in.z_e;
    assign a_s          =   stage_in.a_s; 
    assign b_s          =   stage_in.b_s;
    assign z_s          =   stage_in.z_s;
    assign guard        =   stage_in.guard;
    assign round_bit    =   stage_in.round_bit;
    assign sticky       =   stage_in.sticky;
    assign sum          =   stage_in.sum;

    logic       [12:0] difference;

    always_comb begin
        difference = 0;
        stage_out = stage_in;

        if(!stage_in.standby) begin

            if ($signed(a_e) > $signed(b_e)) begin

                difference = $signed(a_e) - $signed(b_e);
                stage_out.b_e = b_e + difference;
                stage_out.b_m = b_m >> difference;
                stage_out.b_m[0] = 0;

                for(int i = 0; i < 56; ++i) begin
                    if(b_m[i]  && i <= difference)
                        stage_out.b_m[0] = 1;
                end

            end else if ($signed(a_e) < $signed(b_e)) begin

                difference = $signed(b_e) - $signed(a_e);
                stage_out.a_e = a_e + difference;
                stage_out.a_m = a_m >> difference;
                stage_out.a_m[0] = 0;

                for(int i = 0; i < 56; ++i) begin
                    if(a_m[i] && i <= difference) 
                        stage_out.a_m[0] = 1;
                end
        
            end
        end
    end

endmodule

module doubleadd_add0 (

    input double_adder_pipeline_reg  stage_in,
    output double_adder_pipeline_reg stage_out

);

    logic [55:0] a_m, b_m;
    logic [52:0] z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;
    logic [56:0] sum;

    assign a_m          =   stage_in.a_m;
    assign b_m          =   stage_in.b_m;
    assign z_m          =   stage_in.z_m;
    assign a_e          =   stage_in.a_e;
    assign b_e          =   stage_in.b_e;
    assign z_e          =   stage_in.z_e;
    assign a_s          =   stage_in.a_s; 
    assign b_s          =   stage_in.b_s;
    assign z_s          =   stage_in.z_s;
    assign guard        =   stage_in.guard;
    assign round_bit    =   stage_in.round_bit;
    assign sticky       =   stage_in.sticky;
    assign sum          =   stage_in.sum;

    always_comb begin
        stage_out = stage_in;

        if(!stage_in.standby) begin
            stage_out.z_e = a_e;
            if (a_s == b_s) begin
                stage_out.sum = {1'd0, a_m} + b_m;
                stage_out.z_s = a_s;
            end else begin
                if (a_m > b_m) begin
                    stage_out.sum = {1'd0, a_m} - b_m;
                    stage_out.z_s = a_s;
                end else begin
                    stage_out.sum = {1'd0, b_m} - a_m;
                    stage_out.z_s = b_s;
                end
            end
        end
    end


endmodule


module doubleadd_add1 (

    input double_adder_pipeline_reg  stage_in,
    output double_adder_pipeline_reg stage_out

);

    logic [55:0] a_m, b_m;
    logic [52:0] z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;
    logic [56:0] sum;

    assign a_m          =   stage_in.a_m;
    assign b_m          =   stage_in.b_m;
    assign z_m          =   stage_in.z_m;
    assign a_e          =   stage_in.a_e;
    assign b_e          =   stage_in.b_e;
    assign z_e          =   stage_in.z_e;
    assign a_s          =   stage_in.a_s; 
    assign b_s          =   stage_in.b_s;
    assign z_s          =   stage_in.z_s;
    assign guard        =   stage_in.guard;
    assign round_bit    =   stage_in.round_bit;
    assign sticky       =   stage_in.sticky;
    assign sum          =   stage_in.sum;

    always_comb begin

        stage_out = stage_in;

        if(!stage_in.standby) begin
            if (sum[56]) begin
                stage_out.z_m = sum[56:4];
                stage_out.guard = sum[3];
                stage_out.round_bit = sum[2];
                stage_out.sticky = sum[1] | sum[0];
                stage_out.z_e = z_e + 1;
            end else begin
                stage_out.z_m = sum[55:3];
                stage_out.guard = sum[2];
                stage_out.round_bit = sum[1];
                stage_out.sticky = sum[0];
            end
        end
    end

endmodule

module doubleadd_normalise1 (

    input double_adder_pipeline_reg  stage_in,
    output double_adder_pipeline_reg stage_out,
    output logic                      stall_out

);

    logic [55:0] a_m, b_m;
    logic [52:0] z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;
    logic [56:0] sum;

    assign a_m          =   stage_in.a_m;
    assign b_m          =   stage_in.b_m;
    assign z_m          =   stage_in.z_m;
    assign a_e          =   stage_in.a_e;
    assign b_e          =   stage_in.b_e;
    assign z_e          =   stage_in.z_e;
    assign a_s          =   stage_in.a_s; 
    assign b_s          =   stage_in.b_s;
    assign z_s          =   stage_in.z_s;
    assign guard        =   stage_in.guard;
    assign round_bit    =   stage_in.round_bit;
    assign sticky       =   stage_in.sticky;
    assign sum          =   stage_in.sum;

    always_comb begin

        stall_out = 0;
        stage_out = stage_in;

        if(!stage_in.standby) begin
            if (z_m[52] == 0 && $signed(z_e) > -1022) begin
                stage_out.z_e = z_e - 1;
                stage_out.z_m = z_m << 1;
                stage_out.z_m[0] = guard;
                stage_out.guard = round_bit;
                stage_out.round_bit = 0;
                stall_out = stage_in.valid;
            end 
        end
    end


endmodule

module doubleadd_normalise2 (

    input double_adder_pipeline_reg  stage_in,
    output double_adder_pipeline_reg stage_out,
    output logic                      stall_out

);

    logic [55:0] a_m, b_m;
    logic [52:0] z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;
    logic [56:0] sum;

    assign a_m          =   stage_in.a_m;
    assign b_m          =   stage_in.b_m;
    assign z_m          =   stage_in.z_m;
    assign a_e          =   stage_in.a_e;
    assign b_e          =   stage_in.b_e;
    assign z_e          =   stage_in.z_e;
    assign a_s          =   stage_in.a_s; 
    assign b_s          =   stage_in.b_s;
    assign z_s          =   stage_in.z_s;
    assign guard        =   stage_in.guard;
    assign round_bit    =   stage_in.round_bit;
    assign sticky       =   stage_in.sticky;
    assign sum          =   stage_in.sum;

    always_comb begin
        stage_out = stage_in;
        stall_out = 0;
        if(!stage_in.standby) begin
            if ($signed(z_e) < -1022) begin
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


module doubleadd_round (

    input double_adder_pipeline_reg  stage_in,
    output double_adder_pipeline_reg stage_out

);

    logic [55:0] a_m, b_m;
    logic [52:0] z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;
    logic [56:0] sum;

    assign a_m          =   stage_in.a_m;
    assign b_m          =   stage_in.b_m;
    assign z_m          =   stage_in.z_m;
    assign a_e          =   stage_in.a_e;
    assign b_e          =   stage_in.b_e;
    assign z_e          =   stage_in.z_e;
    assign a_s          =   stage_in.a_s; 
    assign b_s          =   stage_in.b_s;
    assign z_s          =   stage_in.z_s;
    assign guard        =   stage_in.guard;
    assign round_bit    =   stage_in.round_bit;
    assign sticky       =   stage_in.sticky;
    assign sum          =   stage_in.sum;

    always_comb begin

        stage_out = stage_in;

        if(!stage_in.standby) begin
            if (guard && (round_bit | sticky | z_m[0])) begin
                stage_out.z_m = z_m + 1;
                if (z_m == 53'h1fffffffffffff)
                    stage_out.z_e = z_e + 1;
            end
        end
    end

endmodule


module doubleadd_pack (

    input double_adder_pipeline_reg  stage_in,
    output double_adder_pipeline_reg stage_out

);

    logic [55:0] a_m, b_m;
    logic [52:0] z_m;
    logic [12:0] a_e, b_e, z_e;
    logic a_s, b_s, z_s;
    logic guard, round_bit, sticky;
    logic [56:0] sum;

    assign a_m          =   stage_in.a_m;
    assign b_m          =   stage_in.b_m;
    assign z_m          =   stage_in.z_m;
    assign a_e          =   stage_in.a_e;
    assign b_e          =   stage_in.b_e;
    assign z_e          =   stage_in.z_e;
    assign a_s          =   stage_in.a_s; 
    assign b_s          =   stage_in.b_s;
    assign z_s          =   stage_in.z_s;
    assign guard        =   stage_in.guard;
    assign round_bit    =   stage_in.round_bit;
    assign sticky       =   stage_in.sticky;
    assign sum          =   stage_in.sum;

    always_comb begin

        stage_out = stage_in;

        if(!stage_in.standby) begin

            stage_out.output_z[51 : 0] = z_m[51:0];
            stage_out.output_z[62 : 52] = z_e[10:0] + 1023;
            stage_out.output_z[63] = z_s;
            
            if ($signed(z_e) == -1022 && z_m[52] == 0)
                stage_out.output_z[62 : 52] = 0;

            if ($signed(z_e) == -1022 && z_m[52:0] == 0)
                stage_out.output_z[63] = 0;

            //if overflow occurs, return inf
            if ($signed(z_e) > 1023) begin
                stage_out.output_z[51 : 0] = 0;
                stage_out.output_z[62 : 52] = 2047;
                stage_out.output_z[63] = z_s;
            end
        end
    end

endmodule

`endif