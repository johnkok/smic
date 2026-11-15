`timescale 1ns/1ps
module tb_test_source;
 reg clk=0,rst=1,tick=0;
 reg [31:0] control=0,amplitude=32'h00012345;
 reg signed [23:0] pcm_in[0:31];
 wire signed [23:0] pcm_out[0:31];
 always #5 clk=~clk;
 test_source dut(.clk(clk),.rst(rst),.sample_tick(tick),.control(control),
  .amplitude(amplitude),.pcm_in(pcm_in),.pcm_out(pcm_out));
 integer i;
 task automatic step;
 begin @(negedge clk);tick=1;@(negedge clk);tick=0;end
 endtask
 initial begin
  for(i=0;i<32;i=i+1)pcm_in[i]=i;
  repeat(2)@(posedge clk);rst=0;
  if(pcm_out[7]!==24'sd7)$fatal(1,"Bypass failed");
  control=1|(5<<2);#1;
  if(pcm_out[5]!==24'sh012345 || pcm_out[4]!==0)
   $fatal(1,"Selected-channel routing failed");
  control=3|(2<<8);#1;
  if(pcm_out[0]!==24'sh012345 || pcm_out[31]!==24'sh012345)
   $fatal(1,"All-channel DC routing failed");
  control=3|(1<<8);step();#1;
  if(pcm_out[0]!==0)$fatal(1,"Impulse phase failed");
  control=0;#1;
  if(pcm_out[31]!==24'sd31)$fatal(1,"Return to PDM failed");
  $display("PASS synthetic test source routing and patterns");$finish;
 end
endmodule
