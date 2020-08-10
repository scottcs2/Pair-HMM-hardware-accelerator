`ifndef DOUBLE_ADDER_SV
`define DOUBLE_ADDER_SV
//IEEE Floating Point Adder (Double Precision)
//Copyright (C) Jonathan P Dawson 2013
//2013-12-12

module double_adder(
        input   logic   [63:0]  input_a,
        input   logic   [63:0]  input_b,
	      input   logic           input_valid,
        input   logic           clk,
        input   logic           reset,
        output  logic   [63:0]  output_z,
        output  logic           done
);

  logic       s_output_z_stb, next_s_output_z_stb;
  logic       [63:0] s_output_z, next_s_output_z;

  logic       [3:0] state, next_state;
  parameter 
            unpack        = 4'd0,
            special_cases = 4'd1,
            align         = 4'd2,
            add_0         = 4'd3,
            add_1         = 4'd4,
            normalise_1   = 4'd5,
            normalise_2   = 4'd6,
            round         = 4'd7,
            pack          = 4'd8,
            standby       = 4'd9;

  logic       [55:0] a_m, b_m, next_a_m, next_b_m;
  logic       [52:0] z_m, next_z_m;
  logic       [12:0] a_e, b_e, z_e, next_a_e, next_b_e, next_z_e;
  logic       a_s, b_s, z_s, next_a_s, next_b_s, next_z_s;
  logic       guard, round_bit, sticky, next_guard, next_round_bit, next_sticky;
  logic       [56:0] sum, next_sum;
  logic       [12:0] difference;

  always_comb
  begin
    next_s_output_z_stb = s_output_z_stb;
    next_s_output_z = s_output_z;
    next_a_m = a_m;
    next_b_m = b_m;
    next_z_m = z_m;
    next_a_e = a_e;
    next_b_e = b_e; 
    next_z_e = z_e;
    next_a_s = a_s;
    next_b_s = b_s;
    next_z_s = z_s;
    next_guard = guard;
    next_round_bit = round_bit;
    next_sticky = sticky;
    next_sum = sum;
    next_state = state;
    difference = 0;

    case(state)

      unpack:
      begin //only proceed when input reaches this adder

	      if(input_valid)
	      begin
           next_a_m  = {input_a[51 : 0], 3'd0};
           next_b_m  = {input_b[51 : 0], 3'd0};
           next_a_e  = input_a[62 : 52] - 1023;
           next_b_e  = input_b[62 : 52] - 1023;
           next_a_s  = input_a[63];
           next_b_s  = input_b[63];
           next_state  = special_cases;
	      end
	      else next_state = unpack;
      end

      special_cases:
      begin
        //if a is NaN or b is NaN return NaN 
        if ((next_a_e == 1024 && next_a_m != 0) || (next_b_e == 1024 && next_b_m != 0)) begin
          next_s_output_z[63] = 1;
          next_s_output_z[62:52] = 2047;
          next_s_output_z[51] = 1;
          next_s_output_z[50:0] = 0;
	        next_s_output_z_stb = 1;
          next_state = standby;
        //if a is inf return inf
        end else if (next_a_e == 1024) begin
          next_s_output_z[63] = a_s;
          next_s_output_z[62:52] = 2047;
          next_s_output_z[51:0] = 0;
          //if a is inf and signs don't match return nan
          if ((next_b_e == 1024) && (next_a_s != next_b_s)) begin
              next_s_output_z[63] = 1;
              next_s_output_z[62:52] = 2047;
              next_s_output_z[51] = 1;
              next_s_output_z[50:0] = 0;
          end
	        next_s_output_z_stb = 1;
          next_state = standby;
        //if b is inf return inf
        end else if (b_e == 1024) begin
          next_s_output_z[63] = next_b_s;
          next_s_output_z[62:52] = 2047;
          next_s_output_z[51:0] = 0;
	        next_s_output_z_stb = 1;
          next_state = standby;
        //if a is zero return b
        end else if ((($signed(a_e) == -1023) && (a_m == 0)) && (($signed(b_e) == -1023) && (b_m == 0))) begin
          next_s_output_z[63] = a_s & b_s;
          next_s_output_z[62:52] = b_e[10:0] + 1023;
          next_s_output_z[51:0] = b_m[55:3];
          next_state = standby;
	        next_s_output_z_stb = 1;
        //if a is zero return b
        end else if (($signed(a_e) == -1023) && (a_m == 0)) begin
          next_s_output_z[63] = b_s;
          next_s_output_z[62:52] = b_e[10:0] + 1023;
          next_s_output_z[51:0] = b_m[55:3];
          next_state = standby;
	        next_s_output_z_stb = 1;
        //if b is zero return a
        end else if (($signed(b_e) == -1023) && (b_m == 0)) begin
          next_s_output_z[63] = a_s;
          next_s_output_z[62:52] = a_e[10:0] + 1023;
          next_s_output_z[51:0] = a_m[55:3];
          next_state = standby;
	        next_s_output_z_stb = 1;
        end else begin
          //Denormalised Number
          if ($signed(a_e) == -1023) begin
            next_a_e = -1022;
          end else begin
            next_a_m[55] = 1;
          end
          //Denormalised Number
          if ($signed(b_e) == -1023) begin
            next_b_e = -1022;
          end else begin
            next_b_m[55] = 1;
          end
            next_state = align;
        end
      end

      align:
      begin
        if ($signed(a_e) > $signed(b_e)) begin
          difference = $signed(a_e) - $signed(b_e);
          next_b_e = b_e + difference;
          next_b_m = b_m >> difference;
          next_b_m[0] = 0;
          for(int i = 0; i < 56; ++i) begin
            if(b_m[i]  && i <= difference)begin
              next_b_m[0] = 1;
            end
          end
          next_state = add_0;
        end else if ($signed(a_e) < $signed(b_e)) begin
          difference = $signed(b_e) - $signed(a_e);
          next_a_e = a_e + difference;
          next_a_m = a_m >> difference;
          next_a_m[0] = 0;
          for(int i = 0; i < 56; ++i) begin
            if(a_m[i] && i <= difference)begin
              next_a_m[0] = 1;
            end
          end
          next_state = add_0;
        end else begin
          next_state = add_0;
        end
      end

      add_0:
      begin
        next_z_e = a_e;
        if (a_s == b_s) begin
          next_sum = {1'd0, a_m} + b_m;
          next_z_s = a_s;
        end else begin
          if (a_m > b_m) begin
            next_sum = {1'd0, a_m} - b_m;
            next_z_s = a_s;
          end else begin
            next_sum = {1'd0, b_m} - a_m;
            next_z_s = b_s;
          end
        end
        next_state = add_1;
      end

      add_1:
      begin
        if (sum[56]) begin
          next_z_m = sum[56:4];
          next_guard = sum[3];
          next_round_bit = sum[2];
          next_sticky = sum[1] | sum[0];
          next_z_e = z_e + 1;
        end else begin
          next_z_m = sum[55:3];
          next_guard = sum[2];
          next_round_bit = sum[1];
          next_sticky = sum[0];
        end
        next_state = normalise_1;
      end

      normalise_1:
      begin
        if (z_m[52] == 0 && $signed(z_e) > -1022) begin
          next_z_e = z_e - 1;
          next_z_m = z_m << 1;
          next_z_m[0] = guard;
          next_guard = round_bit;
          next_round_bit = 0;
        end else
          next_state = normalise_2;
      end
      normalise_2:
      begin 
          if ($signed(z_e) < -1022) begin
            next_z_e = z_e + 1;
            next_z_m = z_m >> 1;
            next_guard = z_m[0];
            next_round_bit = guard;
            next_sticky = sticky | round_bit;
          end 
          else begin
            next_state = round;
          end
        //end of normalize_2
      end

      round:
      begin
        if (guard && (round_bit | sticky | z_m[0])) begin
          next_z_m = z_m + 1;
          if (z_m == 53'h1fffffffffffff) begin
            next_z_e = z_e + 1;
          end
        end
        next_state = pack;
      end

      pack:
      begin
        next_s_output_z[51 : 0] = z_m[51:0];
        next_s_output_z[62 : 52] = z_e[10:0] + 1023;
        next_s_output_z[63] = z_s;
        if ($signed(z_e) == -1022 && z_m[52] == 0) begin
          next_s_output_z[62 : 52] = 0;
        end
        if ($signed(z_e) == -1022 && z_m[52:0] == 0) begin
          next_s_output_z[63] = 0;
        end

        //if overflow occurs, return inf
        if ($signed(z_e) > 1023) begin
          next_s_output_z[51 : 0] = 0;
          next_s_output_z[62 : 52] = 2047;
          next_s_output_z[63] = z_s;
        end
        next_state = standby;
	      next_s_output_z_stb = 1;
      end

      standby: //when computation is finished, do nothing until the functional unit is reset
      begin
	      next_state = standby;
      end
    endcase

  end

  always_ff @(posedge clk) begin

    s_output_z_stb <= next_s_output_z_stb;
    s_output_z <= next_s_output_z;
    a_m <= next_a_m;
    b_m <= next_b_m;
    z_m <= next_z_m;
    a_e <= next_a_e;
    b_e <= next_b_e; 
    z_e <= next_z_e;
    a_s <= next_a_s;
    b_s <= next_b_s;
    z_s <= next_z_s;
    guard <= next_guard;
    round_bit <= next_round_bit;
    sticky <= next_sticky;
    sum <= next_sum;
    state <= next_state;
    
    if (reset == 1) begin
      state <= unpack;
      s_output_z_stb <= 0;
    end

  end

  assign done = s_output_z_stb;
  assign output_z = s_output_z;

endmodule

`endif