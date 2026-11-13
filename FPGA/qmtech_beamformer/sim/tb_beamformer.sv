`timescale 1ns/1ps
module tb_beamformer;
 reg clk=0,rst=1,tick=0;
 always #40.69 clk=~clk;
 reg signed [23:0] pcm[0:31];
 reg [31:0] delay[0:31],gain[0:31];
 reg [31:0] mask=32'hffffffff,ctrl=1,outgain=32768;
 wire signed [23:0] beam;
 wire valid;
 wire [31:0] levels[0:31];
 beam_core dut(.clk(clk),.rst(rst),.sample_tick(tick),.pcm(pcm),.enable_mask(mask),
 .delays(delay),.gains(gain),.ctrl(ctrl),.out_gain(outgain),.beam(beam),.beam_valid(valid),.levels(levels));
 integer i,k;
 initial begin
  for(i=0;i<32;i=i+1)begin pcm[i]=24'sd100000;delay[i]=0;gain[i]=32768;end
  repeat(4)@(posedge clk);rst=0;
  for(k=0;k<8;k=k+1)begin
   @(negedge clk);tick=1;@(negedge clk);tick=0;
   repeat(40)@(negedge clk);
   $display("frame=%0d beam=%0d valid=%b",k,beam,valid);
  end
  if(beam<24'sd95000 || beam>24'sd105000)$fatal(1,"Beam output mismatch: %0d",beam);
  $display("PASS beamformer constant input");$finish;
 end
endmodule
