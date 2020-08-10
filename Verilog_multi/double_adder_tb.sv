`ifndef DOUBLE_ADDER_TB_SV
`define DOUBLE_ADDER_TB_SV

module test_bench(
  output logic Z_stb,
  output logic[63:0] Z //the sum
);

logic clk, rst, input_valid;
logic [63:0] inA, inB;

task wait_for_stable_output; begin
  while(~Z_stb)begin
    @(posedge clk);
    $display(A1.state);
  end
end
endtask

  real A, B;
  always begin
    #5
    clk =  ~clk;
  end
  double_adder A1(
    .clk(clk),
    .rst(rst),
    .input_valid(input_valid),
    .input_a(inA),
    .input_b(inB), 
    .output_z(Z),
    .done(Z_stb)
  );

  initial 
  begin
  clk = 0;
  rst = 0;
  input_valid = 0;
  @(negedge clk);
  rst = 1;
  @(negedge clk);
  @(negedge clk);
  rst = 0;
  A = 0.4;
  B = 0.1;
  inA = $realtobits(A);
  inB = $realtobits(B);
  input_valid = 1;
  @(posedge clk);
 $display("STATEMENT 1 :: start time is %0t",$time); 
  wait_for_stable_output();
$display("STATEMENT 1 :: end time is %0t",$time); 
  
  $display("%f + %f = %f", $bitstoreal(inA), 
  $bitstoreal(inB), $bitstoreal(Z));

  $finish;


  end
endmodule
`endif