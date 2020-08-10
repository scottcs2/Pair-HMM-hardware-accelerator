`ifndef DOUBLE_MULTIPLY_SV
`define DOUBLE_MULTIPLY_SV
//IEEE Floating Point Multiplier (Double Precision)
//Copyright (C) Jonathan P Dawson 2014
//2014-01-10
//Found here: https://github.com/dawsonjon/fpu

//Heavily modified by Scott Smith to increase simplicity and better fit the project

module double_multiply (

        // inputs
        input   logic [63:0]  input_a,
        input   logic [63:0]  input_b,
        input   logic         input_valid,
        input   logic         clk,
        input   logic         reset,

        // outputs
        output  logic [63:0]  output_z,
        output  logic         output_done

		// debug output
	,	output 	logic [3:0]	  output_state
        
);

  logic       [63:0] z, next_z;

  	typedef enum logic [3:0]{
		unpack        = 4'd0,
		special_cases = 4'd1,
		normalise     = 4'd2,
		multiply_0    = 4'd3,
		multiply_1    = 4'd4,
		multiply_2	  = 4'd5,
		normalise_1   = 4'd6,
		normalise_2   = 4'd7,
		round         = 4'd8,
		pack          = 4'd9,
		put_z         = 4'd10,
		standby       = 4'd11
	} STATE;

  STATE state, next_state;

  logic       [63:0] a, b;
  logic       [52:0] a_m, b_m, z_m, next_a_m, next_b_m, next_z_m;
  logic       [12:0] a_e, b_e, z_e, next_a_e, next_b_e, next_z_e;
  logic       a_s, b_s, z_s, next_a_s, next_b_s, next_z_s;
  logic       guard, round_bit, sticky, next_guard, next_round_bit, next_sticky;
  logic       [107:0] product, next_product;

  double_multiply_pipeline_reg debug_reg;

  assign debug_reg.z = z;
  assign debug_reg.a_m = a_m;
  assign debug_reg.b_m = b_m;
  assign debug_reg.z_m = z_m;
  assign debug_reg.a_e = a_e;
  assign debug_reg.b_e = b_e;
  assign debug_reg.z_e = z_e;
  assign debug_reg.a_s = a_s;
  assign debug_reg.b_s = b_s;
  assign debug_reg.z_s = z_s;
  assign debug_reg.guard = guard;
  assign debug_reg.round_bit = round_bit;
  assign debug_reg.sticky = sticky;
  assign debug_reg.standby = 1'b0;

  always_ff @(posedge clk) begin
	$display("\nmulti-cycle @ t=%0d\nstate:%s", $time, state.name());
	print_doublemult_state(debug_reg);
	if(reset)
		debug_reg.valid <= 0;
	else
		debug_reg.valid <= debug_reg.valid | input_valid;
  end



  assign a = input_a;
  assign b = input_b;
  
  logic [5:0] shift_counter_a, shift_counter_b;
  logic [63:0] m_input_a, m_input_b;
  logic [127:0] m_product;
  logic m_done, m_start;

  always_comb
  begin
	
    next_state = state;
    next_a_m = a_m;
    next_a_e = a_e;
    next_a_s = a_s;
    next_b_e = b_e;
    next_b_m = b_m;
    next_b_s = b_s;
    next_guard = guard;
    next_product = product;
    next_round_bit = round_bit;
    next_sticky = sticky;
    next_z = z;
    next_z_e = z_e;
    next_z_m = z_m;
    next_z_s = z_s;
	shift_counter_a = 0;
	shift_counter_b = 0;
	m_start = 0;
	m_input_a = 0;
	m_input_b = 0;
	

    case(state)

		unpack:
		begin
			if(input_valid) begin
				next_a_m = a[51 : 0];
				next_b_m = b[51 : 0];
				next_a_e = a[62 : 52] - 1023;
				next_b_e = b[62 : 52] - 1023;
				next_a_s = a[63];
				next_b_s = b[63];
				next_state = special_cases;
			end
		end

		special_cases:
		begin
			//if a is NaN or b is NaN return NaN 
			if ((a_e == 1024 && a_m != 0) ||
				  (b_e == 1024 && b_m != 0)) 
			begin
				next_z[63]     = 1;
				next_z[62:52]  = 2047;
				next_z[51]     = 1;
				next_z[50:0]   = 0;
				next_state     = standby;
				//if a is inf return inf
			end else if (a_e == 1024) 
			begin
				next_z[63]     = a_s ^ b_s;
				next_z[62:52]  = 2047;
				next_z[51:0]   = 0;
				next_state     = standby;
				//if b is zero return NaN
				if (($signed(b_e) == -1023) && (b_m == 0))
				begin
					next_z[63]     = 1;
					next_z[62:52]  = 2047;
					next_z[51]     = 1;
					next_z[50:0]   = 0;
					next_state     = standby;
				end
				
			//if b is inf return inf
			end else if (b_e == 1024) 
			begin
				next_z[63]     = a_s ^ b_s;
				next_z[62:52]  = 2047;
				next_z[51:0]   = 0;
				//if b is zero return NaN
				if (($signed(a_e) == -1023) && (a_m == 0)) 
				begin
					next_z[63]     = 1;
					next_z[62:52]  = 2047;
					next_z[51]     = 1;
					next_z[50:0]   = 0;
					next_state     = standby;
				end
				next_state = standby;
				
			//if a is zero return zero
			end else if (($signed(a_e) == -1023) && (a_m == 0)) 
			begin
				next_z[63] = a_s ^ b_s;
				next_z[62:52] = 0;
				next_z[51:0] = 0;
				next_state = standby;
			//if b is zero return zero
			end else if (($signed(b_e) == -1023) && (b_m == 0)) 
			begin
				next_z[63] = a_s ^ b_s;
				next_z[62:52] = 0;
				next_z[51:0] = 0;
				next_state = standby;
			end else 
			begin
				//Denormalised Number
				if ($signed(a_e) == -1023) 
				begin
					next_a_e = -1022;
				end else 
				begin
					next_a_m[52] = 1;
				end
				//Denormalised Number
				if ($signed(b_e) == -1023) 
				begin
					next_b_e = -1022;
				end else 
				begin
					next_b_m[52] = 1;
				end
				next_state = normalise;
			end
		end

		normalise:
		begin
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
			
			next_a_m = a_m << shift_counter_a;
			next_a_e = a_e - shift_counter_a;
			
			next_b_m = b_m << shift_counter_b;
			next_b_e = b_e - shift_counter_b;
			
			next_state = multiply_0;
			
		end

		multiply_0:
		begin
			m_start = 1;
			next_z_s = a_s ^ b_s;
			next_z_e = a_e + b_e + 1;
			m_input_a = a_m;
			m_input_b = b_m << 2;
			next_state = multiply_1;
		end
		
		multiply_1:
		begin
			m_start = 0;
			if(m_done) begin
				next_state = multiply_2;
				next_product = m_product;
			end	
		end

		multiply_2:
		begin
			next_z_m = product[107:55];
			next_guard = product[54];
			next_round_bit = product[53];
			next_sticky = (product[52:0] != 0);
			next_state = normalise_1;
		end

		normalise_1:
		begin
			if (z_m[52] == 0) 
			begin
				next_z_e = z_e - 1;
				next_z_m = z_m << 1;
				next_z_m[0] = guard;
				next_guard = round_bit;
				next_round_bit = 0;
			end else 
			begin
				next_state = normalise_2;
			end
		end

		normalise_2:
		begin
			if ($signed(z_e) < -1022) 
			begin
				next_z_e = z_e + 1;
				next_z_m = z_m >> 1;
				next_guard = z_m[0];
				next_round_bit = guard;
				next_sticky = sticky | round_bit;
			end else 
			begin
				next_state = pack;
			end
		end

		pack:
		begin
			// round:
			if (guard && (round_bit | sticky | z_m[0])) 
			begin
				next_z_m = z_m + 1;
				if (z_m == 53'h1fffffffffffff) 
				begin
					next_z_e = z_e + 1;
				end
			end
		
			// pack:
			next_z[51 : 0] = next_z_m[51:0];
			next_z[62 : 52] = next_z_e[11:0] + 1023;
			next_z[63] = z_s;
			if ($signed(next_z_e) == -1022 && next_z_m[52] == 0) 
			begin
				next_z[62 : 52] = 0;
			end
			//if overflow occurs, return inf
			if ($signed(next_z_e) > 1023) 
			begin
				next_z[51 : 0] = 0;
				next_z[62 : 52] = 2047;
				next_z[63] = z_s;
			end
			next_state = standby;
		end

		standby:
		begin
		
		end

	endcase
	
  end
	// synopsys sync_set_reset "reset"
	always_ff @(posedge clk) 
	begin
		if(reset) begin
			state <= unpack;
			a_m <= 0;
			a_e <= 0;
			a_s <= 0;
			b_e <= 0;
			b_m <= 0;
			b_s <= 0;
			guard <= 0;
			product <= 0;
			round_bit <= 0;
			sticky <= 0;
			z <= 0;
			z_e <= 0;
			z_m <= 0;
			z_s <= 0;
		end else begin
			state <= next_state;
			a_m <= next_a_m;
			a_e <= next_a_e;
			a_s <= next_a_s;
			b_e <= next_b_e;
			b_m <= next_b_m;
			b_s <= next_b_s;
			guard <= next_guard;
			product <= next_product;
			round_bit <= next_round_bit;
			sticky <= next_sticky;
			z <= next_z;
			z_e <= next_z_e;
			z_m <= next_z_m;
			z_s <= next_z_s;
		end
	end
	
	
	mult  multiply_pipelined (
		// inputs
		.clk(clk),
		.reset(reset),
		.start(m_start),
		.sign(/* TODO: what the banana do I put here*/ 2'b0),
		.mcand(m_input_a),
		.mplier(m_input_b),
		
		// outputs
		.product(m_product),
		.done(m_done)
		
	);

	assign output_done = (state == standby);
	assign output_z = z;

endmodule
`endif