`default_nettype none
module beamformer_top (
 input wire audio_clk_12m288, input wire rst_n,
 input wire [15:0] pdm_data, output wire pdm_clk,
 input wire spi_sck, spi_cs_n, spi_mosi, output wire spi_miso,
 output wire audio_bclk, audio_fs, audio_sd,
 output wire [3:0] debug
);
 wire rst = ~rst_n;
 wire [31:0] pcm_valid_unused;
 wire sample_tick;
 wire signed [23:0] pcm [0:31];
 wire [31:0] enable_mask;
 wire [31:0] delays [0:31];
 wire [31:0] gains [0:31];
 wire [31:0] ctrl, mode, out_gain;
 wire commit;
 wire signed [23:0] beam;
 wire beam_valid;
 wire [31:0] frame_count;
 wire [31:0] levels [0:31];
 wire [31:0] error_flags = 32'd0;
 pdm_frontend front(.clk(audio_clk_12m288),.rst(rst),.pdm_data(pdm_data),.pdm_clk(pdm_clk),.sample_tick(sample_tick),.pcm(pcm));
 spi_regs regs(.clk(audio_clk_12m288),.rst(rst),.sck(spi_sck),.cs_n(spi_cs_n),.mosi(spi_mosi),.miso(spi_miso),
 .enable_mask(enable_mask),.delays(delays),.gains(gains),.ctrl(ctrl),.mode(mode),.out_gain(out_gain),.commit(commit),
 .frame_count(frame_count),.levels(levels),.error_flags(error_flags));
 beam_core core(.clk(audio_clk_12m288),.rst(rst),.sample_tick(sample_tick),.pcm(pcm),.enable_mask(enable_mask),
 .delays(delays),.gains(gains),.ctrl(ctrl),.out_gain(out_gain),.beam(beam),.beam_valid(beam_valid),.levels(levels));
 audio_tx tx(.clk(audio_clk_12m288),.rst(rst),.mode_tdm(mode[1]),.sample(beam),.sample_valid(beam_valid),
 .bclk(audio_bclk),.fs(audio_fs),.sd(audio_sd),.frame_count(frame_count));
 assign debug = {mode[1], beam_valid, sample_tick, pdm_clk};
endmodule
`default_nettype wire
