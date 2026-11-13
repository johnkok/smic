`default_nettype none
// 32-channel delay-and-sum. Delay Q16.16; linear interpolation between samples.
// Gains unsigned Q1.15, output gain unsigned Q1.15. Delay max 254 samples.
// Time-multiplexed MAC: one channel per clock; finishes within 48kHz frame.
module beam_core(
 input wire clk, rst, sample_tick,
 input wire signed [23:0] pcm [0:31],
 input wire [31:0] enable_mask,
 input wire [31:0] delays [0:31],
 input wire [31:0] gains [0:31],
 input wire [31:0] ctrl, out_gain,
 output reg signed [23:0] beam,
 output reg beam_valid,
 output wire [31:0] levels [0:31]
);
 reg signed [23:0] history[0:31][0:255];
 reg [7:0] wr_ptr;
 reg [5:0] idx;
 reg busy;
 reg signed [63:0] acc;
 reg [5:0] count;
 reg [31:0] level_reg[0:31];
 genvar g;
 generate for(g=0;g<32;g=g+1) begin: level_out
 assign levels[g]=level_reg[g];
 end endgenerate
 wire [7:0] dint = delays[idx][23:16];
 wire [15:0] frac = delays[idx][15:0];
 wire [7:0] rd0 = wr_ptr - dint;
 wire [7:0] rd1 = wr_ptr - dint - 8'd1;
 wire signed [23:0] x0=history[idx][rd0];
 wire signed [23:0] x1=history[idx][rd1];
 wire signed [40:0] interp = $signed(x0)*$signed({1'b0,(16'hffff-frac)}) + $signed(x1)*$signed({1'b0,frac});
 wire signed [24:0] interpolated=interp >>> 16;
 wire signed [41:0] weighted=interpolated*$signed({1'b0,gains[idx][15:0]});
 wire signed [63:0] next_acc=acc + (enable_mask[idx] ? {{22{weighted[41]}},weighted} : 64'sd0);
 wire signed [63:0] average=next_acc / $signed({58'd0,(count+6'd1)});
 wire signed [79:0] scaled=average*$signed({1'b0,out_gain[15:0]});
 wire signed [63:0] result=scaled >>> 30;
 function automatic signed [23:0] sat24(input signed [63:0] v);
 begin
  if(v>64'sd8388607) sat24=24'sh7fffff;
  else if(v< -64'sd8388608) sat24=24'sh800000;
  else sat24=v[23:0];
 end endfunction
 integer i,j;
 always @(posedge clk) begin
  if(rst) begin
   wr_ptr<=0;idx<=0;busy<=0;acc<=0;count<=0;beam<=0;beam_valid<=0;
   for(i=0;i<32;i=i+1) begin
    level_reg[i]<=0;
    for(j=0;j<256;j=j+1) history[i][j]<=0;
   end
  end else begin
   beam_valid<=0;
   if(sample_tick) begin
    wr_ptr<=wr_ptr+1'b1;
    for(i=0;i<32;i=i+1) begin
     history[i][wr_ptr+8'd1]<=pcm[i];
     level_reg[i]<=pcm[i][23] ? {8'd0,(~pcm[i]+24'd1)} : {8'd0,pcm[i]};
    end
    idx<=0;acc<=0;count<=0;busy<=1;
   end else if(busy) begin
    acc<=next_acc;
    if(enable_mask[idx]) count<=count+1'b1;
    if(idx==6'd31) begin
     busy<=0;
     if(ctrl[0] && !ctrl[1]) begin
      beam<=sat24(result);beam_valid<=1;
     end else begin beam<=0;beam_valid<=1;end
    end else idx<=idx+1'b1;
   end
  end
 end
endmodule
`default_nettype wire
