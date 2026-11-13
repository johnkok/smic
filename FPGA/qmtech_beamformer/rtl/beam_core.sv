`default_nettype none
// 32-channel delay-and-sum beamformer. Delays are unsigned Q16.16 samples;
// gains and output gain are unsigned Q1.15. Maximum integer delay is 254.
//
// The 32x256 history is a single 8192x24 simple dual-port block RAM. A frame
// is processed sequentially in 195 clocks, within the 256 clocks available at
// 48 kHz from the 12.288 MHz system clock.
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
 localparam [3:0] ST_IDLE      = 4'd0;
 localparam [3:0] ST_WRITE     = 4'd1;
 localparam [3:0] ST_READ0_REQ = 4'd2;
 localparam [3:0] ST_READ0_CAP = 4'd3;
 localparam [3:0] ST_READ1_REQ = 4'd4;
 localparam [3:0] ST_READ1_CAP = 4'd5;
 localparam [3:0] ST_MAC       = 4'd6;
 localparam [3:0] ST_NORMALIZE = 4'd7;
 localparam [3:0] ST_GAIN      = 4'd8;
 localparam [3:0] ST_OUTPUT    = 4'd9;

 (* ram_style = "block" *) reg signed [23:0] history [0:8191];
 reg signed [23:0] frame_pcm [0:31];
 reg signed [23:0] ram_read_data;
 reg signed [23:0] sample0, sample1;
 reg [31:0] level_reg [0:31];
 reg [7:0] wr_ptr, frame_ptr;
 reg [7:0] valid_samples;
 reg [4:0] channel;
 reg [3:0] state;
 reg [7:0] delay_int_latched;
 reg [15:0] frac_latched, gain_latched;
 reg enabled_latched, read0_valid, read1_valid;
 reg signed [46:0] acc, final_acc, normalized;
 reg signed [63:0] scaled;
 reg [5:0] enabled_count, final_count;

 genvar g;
 generate for(g=0;g<32;g=g+1) begin: level_out
  assign levels[g]=level_reg[g];
 end endgenerate

 wire ram_write_enable = (state==ST_WRITE);
 wire [12:0] ram_write_addr = {channel,frame_ptr};
 wire signed [23:0] ram_write_data = frame_pcm[channel];
 wire [7:0] read_index = (state==ST_READ1_REQ) ?
  (frame_ptr-delay_int_latched-8'd1) :
  (frame_ptr-delays[channel][23:16]);
 wire [12:0] ram_read_addr = {channel,read_index};

 // One synchronous read port and one write port infer block RAM. History is
 // intentionally not reset; valid_samples suppresses unwritten locations.
 always @(posedge clk) begin
  if(ram_write_enable) history[ram_write_addr] <= ram_write_data;
  ram_read_data <= history[ram_read_addr];
 end

 wire [17:0] inv_frac = 18'h10000-{2'b0,frac_latched};
 wire signed [41:0] interp_full =
  $signed(sample0)*$signed(inv_frac) +
  $signed(sample1)*$signed({2'b0,frac_latched});
 wire signed [24:0] interpolated = interp_full >>> 16;
 wire signed [41:0] weighted = interpolated*$signed({1'b0,gain_latched});
 wire signed [46:0] weighted_extended = {{5{weighted[41]}},weighted};
 wire signed [46:0] acc_next = acc +
  (enabled_latched ? weighted_extended : 47'sd0);
 wire [5:0] count_next = enabled_count + (enabled_latched ? 6'd1 : 6'd0);

 // Q0.24 reciprocal table avoids a large variable divider. Normalization and
 // output gain are registered in separate states to keep the datapath short.
 function automatic [24:0] reciprocal_q24(input [5:0] count);
 begin
  case(count)
   6'd1: reciprocal_q24=25'd16777216;
   6'd2: reciprocal_q24=25'd8388608;
   6'd3: reciprocal_q24=25'd5592405;
   6'd4: reciprocal_q24=25'd4194304;
   6'd5: reciprocal_q24=25'd3355443;
   6'd6: reciprocal_q24=25'd2796203;
   6'd7: reciprocal_q24=25'd2396745;
   6'd8: reciprocal_q24=25'd2097152;
   6'd9: reciprocal_q24=25'd1864135;
   6'd10: reciprocal_q24=25'd1677722;
   6'd11: reciprocal_q24=25'd1525201;
   6'd12: reciprocal_q24=25'd1398101;
   6'd13: reciprocal_q24=25'd1290555;
   6'd14: reciprocal_q24=25'd1198373;
   6'd15: reciprocal_q24=25'd1118481;
   6'd16: reciprocal_q24=25'd1048576;
   6'd17: reciprocal_q24=25'd986895;
   6'd18: reciprocal_q24=25'd932068;
   6'd19: reciprocal_q24=25'd883011;
   6'd20: reciprocal_q24=25'd838861;
   6'd21: reciprocal_q24=25'd798915;
   6'd22: reciprocal_q24=25'd762601;
   6'd23: reciprocal_q24=25'd729444;
   6'd24: reciprocal_q24=25'd699051;
   6'd25: reciprocal_q24=25'd671089;
   6'd26: reciprocal_q24=25'd645278;
   6'd27: reciprocal_q24=25'd621378;
   6'd28: reciprocal_q24=25'd599186;
   6'd29: reciprocal_q24=25'd578525;
   6'd30: reciprocal_q24=25'd559241;
   6'd31: reciprocal_q24=25'd541201;
   6'd32: reciprocal_q24=25'd524288;
   default: reciprocal_q24=25'd0;
  endcase
 end endfunction

 wire signed [72:0] normalize_product =
  final_acc*$signed({1'b0,reciprocal_q24(final_count)});
 wire signed [63:0] gain_product =
  normalized*$signed({1'b0,out_gain[15:0]});
 wire signed [63:0] result = scaled >>> 30;

 function automatic signed [23:0] sat24(input signed [63:0] value);
 begin
  if(value>64'sd8388607) sat24=24'sh7fffff;
  else if(value< -64'sd8388608) sat24=24'sh800000;
  else sat24=value[23:0];
 end endfunction

 integer i;
 always @(posedge clk) begin
  if(rst) begin
   wr_ptr<=0;frame_ptr<=0;valid_samples<=0;channel<=0;state<=ST_IDLE;
   delay_int_latched<=0;frac_latched<=0;gain_latched<=0;
   enabled_latched<=0;read0_valid<=0;read1_valid<=0;
   sample0<=0;sample1<=0;acc<=0;final_acc<=0;normalized<=0;scaled<=0;
   enabled_count<=0;final_count<=0;beam<=0;beam_valid<=0;
   for(i=0;i<32;i=i+1) begin
    frame_pcm[i]<=0;level_reg[i]<=0;
   end
  end else begin
   beam_valid<=0;
   case(state)
    ST_IDLE: if(sample_tick) begin
     frame_ptr<=wr_ptr;channel<=0;state<=ST_WRITE;
     for(i=0;i<32;i=i+1) begin
      frame_pcm[i]<=pcm[i];
      level_reg[i]<=pcm[i][23] ? {8'd0,(~pcm[i]+24'd1)} : {8'd0,pcm[i]};
     end
    end
    ST_WRITE: begin
     if(channel==5'd31) begin
      channel<=0;acc<=0;enabled_count<=0;state<=ST_READ0_REQ;
     end else channel<=channel+1'b1;
    end
    ST_READ0_REQ: begin
     delay_int_latched<=delays[channel][23:16];
     frac_latched<=delays[channel][15:0];
     gain_latched<=gains[channel][15:0];
     enabled_latched<=enable_mask[channel];
     read0_valid<=({1'b0,delays[channel][23:16]}<={1'b0,valid_samples});
     state<=ST_READ0_CAP;
    end
    ST_READ0_CAP: begin
     sample0<=read0_valid ? ram_read_data : 24'sd0;
     state<=ST_READ1_REQ;
    end
    ST_READ1_REQ: begin
     read1_valid<=({1'b0,delay_int_latched}+9'd1<={1'b0,valid_samples});
     state<=ST_READ1_CAP;
    end
    ST_READ1_CAP: begin
     sample1<=read1_valid ? ram_read_data : 24'sd0;
     state<=ST_MAC;
    end
    ST_MAC: begin
     acc<=acc_next;enabled_count<=count_next;
     if(channel==5'd31) begin
      final_acc<=acc_next;final_count<=count_next;state<=ST_NORMALIZE;
     end else begin
      channel<=channel+1'b1;state<=ST_READ0_REQ;
     end
    end
    ST_NORMALIZE: begin
     normalized<=normalize_product >>> 24;
     state<=ST_GAIN;
    end
    ST_GAIN: begin
     scaled<=gain_product;
     state<=ST_OUTPUT;
    end
    ST_OUTPUT: begin
     if(ctrl[0] && !ctrl[1]) beam<=sat24(result);
     else beam<=0;
     beam_valid<=1;wr_ptr<=wr_ptr+1'b1;
     if(valid_samples!=8'hff) valid_samples<=valid_samples+1'b1;
     state<=ST_IDLE;
    end
    default: state<=ST_IDLE;
   endcase
  end
 end
endmodule
`default_nettype wire
