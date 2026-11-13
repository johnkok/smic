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
 integer i,k,wait_cycles;
 task automatic run_frame;
 begin
  @(negedge clk);tick=1;@(negedge clk);tick=0;
  wait_cycles=0;
  while(!valid && wait_cycles<240) begin
   @(negedge clk);wait_cycles=wait_cycles+1;
  end
  if(!valid)$fatal(1,"Beam core missed the 256-clock frame deadline");
 end
 endtask
 initial begin
  for(i=0;i<32;i=i+1)begin pcm[i]=24'sd100000;delay[i]=0;gain[i]=32768;end
  repeat(4)@(posedge clk);rst=0;
  for(k=0;k<8;k=k+1)begin
   run_frame();
   $display("frame=%0d beam=%0d valid=%b",k,beam,valid);
  end
  if(beam<24'sd95000 || beam>24'sd105000)$fatal(1,"Beam output mismatch: %0d",beam);

  // Exercise a non-power-of-two enabled count through the reciprocal table.
  mask=32'h00000007;
  for(i=0;i<32;i=i+1)pcm[i]=0;
  pcm[0]=24'sd90000;pcm[1]=24'sd180000;pcm[2]=24'sd270000;
  run_frame();
  if(beam<24'sd179990 || beam>24'sd180010)
   $fatal(1,"Three-channel normalization failed: %0d",beam);

  // One-channel, one-sample delay: the second frame must reproduce the first.
  @(negedge clk);rst=1;@(negedge clk);rst=0;
  mask=32'h00000001;
  for(i=0;i<32;i=i+1)begin pcm[i]=0;delay[i]=0;gain[i]=32768;end
  delay[0]=32'h00010000;pcm[0]=24'sd200000;
  run_frame();
  if(beam!==24'sd0)$fatal(1,"Unwritten history was not suppressed: %0d",beam);
  pcm[0]=24'sd300000;
  run_frame();
  if(beam<24'sd199990 || beam>24'sd200010)
   $fatal(1,"One-sample delay failed: %0d",beam);
  $display("PASS beamformer BRAM scheduling and delay");$finish;
 end
endmodule
