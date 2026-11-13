`default_nettype none
// PDM clock 12.288MHz/4 = 3.072MHz; paired microphones use opposite clock edges.
// DATA pin pair: channel 2*j on rising edge, 2*j+1 on falling edge.
// CIC order 3, decimation 64, 24-bit signed output scaled to 24-bit (gain 64^3).
module pdm_frontend(input wire clk,rst,input wire [15:0] pdm_data,
 output wire pdm_clk,output reg sample_tick,output wire signed [23:0] pcm [0:31]);
 reg [1:0] phase;
 assign pdm_clk = phase[1];
 reg [5:0] dec_count;
 reg signed [31:0] integ1[0:31],integ2[0:31],integ3[0:31];
 reg signed [31:0] comb1z[0:31],comb2z[0:31],comb3z[0:31];
 reg signed [23:0] output_pcm[0:31];
 genvar g;
 generate for(g=0;g<32;g=g+1) begin: outputs
  assign pcm[g]=output_pcm[g];
 end endgenerate
 integer i;
 reg [31:0] bits;
 reg signed [31:0] d1,d2,d3;
 always @(posedge clk) begin
  if(rst) begin
   phase<=0; dec_count<=0; sample_tick<=0;bits<=0;
   for(i=0;i<32;i=i+1) begin
    integ1[i]<=0;integ2[i]<=0;integ3[i]<=0;
    comb1z[i]<=0;comb2z[i]<=0;comb3z[i]<=0;output_pcm[i]<=0;
   end
  end else begin
   phase<=phase+1'b1;
   sample_tick<=0;
   // Sample even channels halfway through PDM high, odd halfway through low.
   if(phase==2'd2) for(i=0;i<16;i=i+1) bits[2*i]<=pdm_data[i];
   if(phase==2'd0) begin
    for(i=0;i<16;i=i+1) bits[2*i+1]<=pdm_data[i];
    for(i=0;i<32;i=i+1) begin
     integ1[i]<=integ1[i]+(bits[i] ? 32'sd1 : -32'sd1);
     integ2[i]<=integ2[i]+integ1[i];
     integ3[i]<=integ3[i]+integ2[i];
    end
    if(dec_count==6'd63) begin
     dec_count<=0;sample_tick<=1;
     for(i=0;i<32;i=i+1) begin
      d1=integ3[i]-comb1z[i];
      d2=d1-comb2z[i];
      d3=d2-comb3z[i];
      comb1z[i]<=integ3[i];comb2z[i]<=d1;comb3z[i]<=d2;
      output_pcm[i]<=d3 <<< 5; // CIC max amplitude 2^18, scaled to signed 24-bit
     end
    end else dec_count<=dec_count+1'b1;
   end
  end
 end
endmodule
`default_nettype wire
