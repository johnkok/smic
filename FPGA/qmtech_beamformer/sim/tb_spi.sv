`timescale 1ns/1ps
module tb_spi;
 reg clk=0,sck=0,cs_n=1,mosi=0,rst=1;
 always #40.69 clk=~clk;
 wire miso,commit;
 wire [31:0] mask,ctrl,mode,outgain;
 wire [31:0] delays [0:31];
 wire [31:0] gains [0:31];
 wire [31:0] levels [0:31];
 genvar i;generate for(i=0;i<32;i=i+1)assign levels[i]=0;endgenerate
 spi_regs dut(.clk(clk),.rst(rst),.sck(sck),.cs_n(cs_n),.mosi(mosi),.miso(miso),
 .enable_mask(mask),.delays(delays),.gains(gains),.ctrl(ctrl),.mode(mode),.out_gain(outgain),
 .commit(commit),.frame_count(32'd0),.levels(levels),.error_flags(32'd0));
 task automatic xfer(input [7:0] op,input [15:0] addr,input [31:0] data);
 reg [55:0] tx;
 integer b;
 begin
  tx={op,addr,data};#300;cs_n=0;
  for(b=55;b>=0;b=b-1)begin
   sck=0;mosi=tx[b];#300;sck=1;#300;
  end
  sck=0;#300;cs_n=1;#600;
 end endtask
 initial begin
  #500;rst=0;
  xfer(8'h02,16'h0020,32'h12345678);
  repeat(10)@(posedge clk);
  if(mask!==32'h12345678)$fatal(1,"SPI write failed: %h",mask);
  xfer(8'h02,16'h0100,32'h00018000);
  xfer(8'h02,16'h0024,32'd1);
  repeat(10)@(posedge clk);
  if(delays[0]!==32'h00018000)$fatal(1,"Commit failed %h",delays[0]);
  $display("PASS SPI writes and commit");$finish;
 end
endmodule
