`default_nettype none
// SPI mode 0: 8-bit opcode (0x02 write, 0x03 read), 16-bit BE address, 32-bit BE data.
// Single word transactions; deassert CS between commands. SCK <= 2MHz recommended.
module spi_regs(
 input wire clk, rst, sck, cs_n, mosi,
 output wire miso,
 output reg [31:0] enable_mask,
 output wire [31:0] delays [0:31],
 output wire [31:0] gains [0:31],
 output reg [31:0] ctrl, mode, out_gain,
 output reg commit,
 input wire [31:0] frame_count,
 input wire [31:0] levels [0:31],
 input wire [31:0] error_flags
);
 reg [31:0] delay_shadow[0:31],gain_shadow[0:31];
 reg [31:0] delay_active[0:31],gain_active[0:31];
 genvar g;
 generate for(g=0;g<32;g=g+1) begin: connect
 assign delays[g]=delay_active[g];assign gains[g]=gain_active[g];
 end endgenerate
 reg [5:0] bitpos;
 reg [7:0] opcode;
 reg [15:0] address;
 reg [31:0] payload;
 reg [31:0] rdword;
 reg [31:0] rdshift;
 reg [15:0] wraddr_spi;
 reg [31:0] wrdata_spi;
 reg wr_toggle_spi;
 reg [2:0] wr_sync;
 reg [31:0] status;
 integer i;
 function automatic [31:0] read_reg(input [15:0] addr);
 begin
 case(addr)
  16'h0000:read_reg=32'hBF320001;
  16'h0004:read_reg=ctrl;
  16'h0008:read_reg=status;
  16'h000c:read_reg=32'd48000;
  16'h0010:read_reg=mode;
  16'h0014:read_reg=32'd0;
  16'h0018:read_reg=32'd0;
  16'h001c:read_reg=out_gain;
  16'h0020:read_reg=enable_mask;
  16'h0024:read_reg=32'd0;
  16'h0028:read_reg=frame_count;
  16'h002c:read_reg=error_flags;
  default:begin
   if(addr>=16'h0100 && addr<=16'h017c && addr[1:0]==0) read_reg=delay_shadow[(addr-16'h0100)>>2];
   else if(addr>=16'h0200 && addr<=16'h027c && addr[1:0]==0) read_reg=gain_shadow[(addr-16'h0200)>>2];
   else if(addr>=16'h0300 && addr<=16'h037c && addr[1:0]==0) read_reg=levels[(addr-16'h0300)>>2];
   else read_reg=32'd0;
  end
 endcase
 end endfunction
 // SPI shift domain: capture command, address, then data. Read shifts MSB first.
 always @(posedge sck or posedge cs_n) begin
  if(cs_n) begin bitpos<=0;opcode<=0;address<=0;payload<=0;rdshift<=0;end
  else begin
   if(bitpos<8) opcode<={opcode[6:0],mosi};
   else if(bitpos<24) begin
    address<={address[14:0],mosi};
    if(bitpos==23) rdshift<=read_reg({address[14:0],mosi});
   end else if(bitpos<56) begin
    payload<={payload[30:0],mosi};
    if(bitpos==55 && opcode==8'h02) begin
     wraddr_spi<=address;wrdata_spi<={payload[30:0],mosi};
     wr_toggle_spi<=~wr_toggle_spi;
    end
    rdshift<={rdshift[30:0],1'b0};
   end
   if(bitpos<56) bitpos<=bitpos+1'b1;
  end
 end
 assign miso = (!cs_n && opcode==8'h03 && bitpos>=24 && bitpos<56) ? rdshift[31] : 1'b0;
 always @(posedge clk) begin
  if(rst) begin
   wr_sync<=0;enable_mask<=32'hffffffff;ctrl<=0;mode<=0;out_gain<=32'h00008000;
   commit<=0;status<=32'd1;
   for(i=0;i<32;i=i+1) begin
    delay_shadow[i]<=0;delay_active[i]<=0;
    gain_shadow[i]<=32'h00008000;gain_active[i]<=32'h00008000;
   end
  end else begin
   wr_sync<={wr_sync[1:0],wr_toggle_spi};commit<=0;
   if(wr_sync[2]^wr_sync[1]) begin
    case(wraddr_spi)
     16'h0004:ctrl<=wrdata_spi;
     16'h0010:mode<=wrdata_spi;
     16'h001c:out_gain<=wrdata_spi;
     16'h0020:enable_mask<=wrdata_spi;
     16'h0024:if(wrdata_spi[0]) commit<=1;
     default:begin
      if(wraddr_spi>=16'h0100 && wraddr_spi<=16'h017c && wraddr_spi[1:0]==0)
       delay_shadow[(wraddr_spi-16'h0100)>>2]<=wrdata_spi;
      if(wraddr_spi>=16'h0200 && wraddr_spi<=16'h027c && wraddr_spi[1:0]==0)
       gain_shadow[(wraddr_spi-16'h0200)>>2]<=wrdata_spi;
     end
    endcase
   end
   if(commit) for(i=0;i<32;i=i+1) begin
    delay_active[i]<=delay_shadow[i];gain_active[i]<=gain_shadow[i];
   end
  end
 end
endmodule
`default_nettype wire
