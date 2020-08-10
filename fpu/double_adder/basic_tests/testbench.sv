module test_bench(
  output logic Z_stb, A_ack, B_ack, //stable and ack signals
  output logic[63:0] Z //the sum
);

logic clk, rst, A_stb, B_stb, Z_ack;
logic [63:0] inA, inB;

task wait_for_stable_output; begin
  while(~Z_stb)begin
    @(negedge clk);
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
    .input_a(inA),
    .input_a_stb(A_stb),
    .input_a_ack(A_ack),
    .input_b(inB),
    .input_b_stb(B_stb),
    .input_b_ack(B_ack),
    .output_z(Z),
    .output_z_stb(Z_stb),
    .output_z_ack(Z_ack)
  );

  initial 
  begin
  clk = 0;
  rst = 0;
  @(negedge clk);
  rst = 1;
  @(negedge clk);
  @(negedge clk);
  rst = 0;
  A = 3.14;
  B = 3.14;
  inA = $realtobits(A);
  inB = $realtobits(B);
  A_stb = 1;
  B_stb = 1;
  wait_for_stable_output();
  
  $display("%f + %f = %f", $bitstoreal(inA), 
  $bitstoreal(inB), $bitstoreal(Z));

  $finish;


  end
endmodule
