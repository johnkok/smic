`default_nettype none
// Synthetic post-decimator source used to verify the beam and DAI datapaths.
module test_source(
 input wire clk, rst, sample_tick,
 input wire [31:0] control, amplitude,
 input wire signed [23:0] pcm_in [0:31],
 output wire signed [23:0] pcm_out [0:31]
);
 reg [5:0] phase;
 wire signed [23:0] level = amplitude[23:0];
 wire signed [23:0] negative_level =
  (level==24'sh800000) ? 24'sh7fffff : -level;
 wire signed [23:0] value =
  (control[9:8]==2'b01) ? ((phase==0) ? level : 24'sd0) :
  (control[9:8]==2'b10) ? level :
  (control[9:8]==2'b11) ? (phase[0] ? negative_level : level) :
  ((phase<24) ? level : negative_level);

 genvar channel;
 generate for(channel=0;channel<32;channel=channel+1) begin: route
  assign pcm_out[channel] = control[0] &&
   (control[1] || control[6:2]==channel) ? value :
   (control[0] ? 24'sd0 : pcm_in[channel]);
 end endgenerate

 always @(posedge clk) begin
  if(rst || !control[0]) phase<=0;
  else if(sample_tick) phase<=(phase==47) ? 0 : phase+1'b1;
 end
endmodule
`default_nettype wire
