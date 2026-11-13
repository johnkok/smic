`default_nettype none
// 12.288MHz clock. BCLK=3.072MHz; 64 bit times/frame; 48k frames/s.
// I2S: 2x32-bit slots, left=beam, right=zero, 1-bit I2S offset.
// TDM: 2x32-bit slots, FS single-bit pulse at frame start; first slot=beam.
module audio_tx(input wire clk,rst,mode_tdm,input wire signed [23:0] sample,
 input wire sample_valid,output wire bclk,output wire fs,output reg sd,output reg [31:0] frame_count);
 reg [1:0] div4;
 reg [5:0] bit_index;
 reg signed [23:0] sample_buf;
 reg [63:0] shift_data;
 assign bclk=div4[1];
 assign fs=mode_tdm ? (bit_index==0) : bit_index[5];
 always @(posedge clk) begin
  if(rst) begin div4<=0;bit_index<=0;sd<=0;frame_count<=0;sample_buf<=0;shift_data<=0;end
  else begin
   div4<=div4+1'b1;
   if(sample_valid) sample_buf<=sample;
   if(div4==2'd3) begin // update data while BCLK falls
    if(bit_index==6'd63) begin
     bit_index<=0;frame_count<=frame_count+1'b1;
     shift_data<={sample_buf,8'd0,32'd0};
     sd<=0;
    end else begin
     bit_index<=bit_index+1'b1;
     if(mode_tdm) begin sd<=shift_data[63];shift_data<={shift_data[62:0],1'b0};end
     else begin
      if(bit_index==6'd0 || bit_index==6'd32) sd<=0;
      else begin sd<=shift_data[63];shift_data<={shift_data[62:0],1'b0};end
     end
    end
   end
  end
 end
endmodule
`default_nettype wire
