`ifndef SYS_DEFS_PIPE_SVH
`define SYS_DEFS_PIPE_SVH

`define NUM_STRINGS 10
`define FALSE 1'h0
`define TRUE  1'h1
`define NUM_PROCS 50
`define MAX_STRING_LENGTH 128 //arbitrary string max
`define MAX_COUNT_WIDTH $clog2(`MAX_STRING_LENGTH + `NUM_PROCS)  
`define MAX_PASSES `MAX_STRING_LENGTH/`NUM_PROCS
`define XLEN 64
`define NUM_STAGE 8
`define NUM_BITS (2*`XLEN)/`NUM_STAGE

parameter type TAG = logic[$clog2(`NUM_STRINGS)-1:0];


typedef enum logic [2:0] {
    INIT_RUN     = 3'h0,
    INIT_RUN2    = 3'h1,
    FETCH_DATA   = 3'h2,
    WAIT         = 3'h3,
    RESULT       = 3'h4,
    RESULT_2     = 3'h5
} ARRAY_STATE;

typedef enum logic [2:0] {
    STRING_T    = 3'h0,
    STRING_C    = 3'h1,
    STRING_G    = 3'h2,
    STRING_A    = 3'h3,
    STRING_DASH = 3'h4
} STRING;


typedef struct packed {
    logic [63:0] m_val;
    logic [63:0] i_val;
    logic [63:0] d_val;
    logic [63:0] t_a;
    logic [63:0] t_b;
} pe_calcs;

typedef struct packed {
    logic [63:0] a_mm;
    logic [63:0] a_im; 
    logic [63:0] a_dm;
    logic [63:0] a_mi;
    logic [63:0] a_ii;
    logic [63:0] a_md;
    logic [63:0] a_dd;
    //logic [63:0] Prior;
} transition_probs;

typedef struct packed {
   STRING reference;
   STRING [`NUM_PROCS-1:0] exp;
   logic                 valid;
} READS;

typedef struct packed {
    logic [`NUM_PROCS-1:0] [63:0] match;
    logic [`NUM_PROCS-1:0] [63:0] neq;
    logic valid;
} PRIORS;

typedef struct packed {
  logic [63:0] z;
  logic [52:0] a_m, b_m, z_m;
  logic [12:0] a_e, b_e, z_e;
  logic a_s, b_s, z_s;
  logic guard, round_bit, sticky;
  TAG tag;
  logic valid;
  logic standby;
} double_multiply_pipeline_reg;


typedef struct packed {

    logic [55:0]    a_m, b_m;
    logic [52:0]    z_m;
    logic [12:0]    a_e, b_e, z_e;
    logic           a_s, b_s, z_s;
    logic           guard, round_bit, sticky;
    logic [56:0]    sum;
    logic [63:0]    output_z;
    logic           valid;
    logic           standby;
    TAG             tag;
    logic [63:0]    mult_operand; // needed at the second level of the add_mult tree

} double_adder_pipeline_reg;

function print_doublemult_state(double_multiply_pipeline_reg state);
    $display("\tvalid:%1h|standby:%1h\n\tz:%10h\n\ta_m:%10h\n\tb_m:%10h\n\tz_m:%10h\n\t\
a_e:%6h|b_e:%6h|z_e:%06h\n\t\
a_s:%1h|b_s:%1h|z_s:%1h\n\t\
guard:%1h|round_bit:%1h|sticky:%1h\n\t\
tag:%3h\n\t\
", state.valid, state.standby, state.z, state.a_m, state.b_m, state.z_m, state.a_e, state.b_e,
    state.z_e, state.a_s, state.b_s, state.z_s, state.guard, state.round_bit, state.sticky,
    state.tag);
endfunction

function print_doubleadd_state(double_adder_pipeline_reg state);
    $display("\tvalid:%1h|standby:%1h\n\toutput_z:%10h\n\ta_m:%10h\n\tb_m:%10h\n\tz_m:%10h\n\t\
a_e:%6h|b_e:%6h|z_e:%06h\n\t\
a_s:%1h|b_s:%1h|z_s:%1h\n\t\
guard:%1h|round_bit:%1h|sticky:%1h\n\t\
sum:%20h\n\t\
tag:%3h\n\t\
", state.valid, state.standby, state.output_z, state.a_m, state.b_m, state.z_m, state.a_e, state.b_e,
    state.z_e, state.a_s, state.b_s, state.z_s, state.guard, state.round_bit, state.sticky, state.sum,
    state.tag);
endfunction

`endif