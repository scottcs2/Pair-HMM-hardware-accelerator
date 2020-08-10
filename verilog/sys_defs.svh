`define FALSE 1'h0
`define TRUE  1'h1
`define NUM_PROCS 4
`define MAX_STRING_LENGTH 128 //arbitrary string max
`define MAX_COUNT_WIDTH $clog2(`MAX_STRING_LENGTH + `NUM_PROCS)  
`define MAX_PASSES `MAX_STRING_LENGTH/`NUM_PROCS
`define XLEN 64
`define NUM_STAGE 8
`define NUM_BITS (2*`XLEN)/`NUM_STAGE

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