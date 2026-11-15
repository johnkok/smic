`timescale 1ns/1ps
module tb_spi;
 reg clk=0,sck=0,cs_n=1,mosi=0,rst=0;
 always #40.69 clk=~clk;
 wire miso,commit,access;
 wire [31:0] mask,ctrl,mode,outgain;
 wire [31:0] test_control,test_amplitude,polarity_mask;
 wire [31:0] delays [0:31];
 wire [31:0] gains [0:31];
 wire [31:0] levels [0:31];
 genvar i;generate for(i=0;i<32;i=i+1)assign levels[i]=0;endgenerate
 spi_regs dut(.clk(clk),.rst(rst),.sck(sck),.cs_n(cs_n),.mosi(mosi),.miso(miso),
 .enable_mask(mask),.delays(delays),.gains(gains),.ctrl(ctrl),.mode(mode),.out_gain(outgain),
 .test_control(test_control),.test_amplitude(test_amplitude),.polarity_mask(polarity_mask),
 .commit(commit),.access(access),.frame_count(32'd0),.levels(levels),.error_flags(32'd0));
 integer access_count=0;
 reg [31:0] rxdata;
 always @(posedge clk) if(access) access_count<=access_count+1;
 task automatic xfer(input [7:0] op,input [15:0] addr,input [31:0] data,
                     output [31:0] received);
 reg [55:0] tx;
 reg [31:0] captured;
 integer b;
 begin
  tx={op,addr,data};captured=0;#300;cs_n=0;
  for(b=55;b>=0;b=b-1)begin
   sck=0;mosi=tx[b];#300;
   if(b<=31)captured={captured[30:0],miso};
   sck=1;#300;
  end
  sck=0;#300;cs_n=1;#600;received=captured;
 end endtask
 initial begin
  #100;rst=1;#400;rst=0;
  xfer(8'h02,16'h0020,32'h12345678,rxdata);
  repeat(10)@(posedge clk);
  if(mask!==32'h12345678)$fatal(1,"SPI write failed: %h",mask);
  xfer(8'h02,16'h0030,32'h0000010d,rxdata);
  xfer(8'h02,16'h0034,32'h00012345,rxdata);
  xfer(8'h02,16'h0038,32'h80000001,rxdata);
  repeat(10)@(posedge clk);
  if(test_control!==32'h0000010d || test_amplitude!==32'h00012345)
   $fatal(1,"Test registers failed");
  xfer(8'h02,16'h0100,32'h00018000,rxdata);
  xfer(8'h02,16'h0024,32'd1,rxdata);
  xfer(8'h03,16'h0000,32'd0,rxdata);
  repeat(10)@(posedge clk);
  if(delays[0]!==32'h00018000)$fatal(1,"Commit failed %h",delays[0]);
  if(polarity_mask!==32'h80000001)$fatal(1,"Polarity commit failed");
  if(rxdata!==32'hbf320001)$fatal(1,"SPI read failed: %h",rxdata);
  if(access_count!==7)$fatal(1,"Expected 7 register accesses, got %0d",access_count);
  $display("PASS SPI writes, commit and access indication");$finish;
 end
endmodule
