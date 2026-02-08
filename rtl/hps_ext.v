//
// hps_ext for Atari800, based on Atari ST one
//
// Copyright (c) 2026 Wojciech Mostowski
// Copyright (c) 2020 Alexey Melnikov
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
///////////////////////////////////////////////////////////////////////

module hps_ext
(
	input             clk_sys,
	inout      [35:0] EXT_BUS,
	
	output reg        set_freezer,
	output reg        set_reset,
	output reg        set_pause,
	output reg        set_reset_rnmi,
	output reg  [7:0] cart1_select,
	output reg  [7:0] cart2_select,
	input      [15:0] atari_status1
);

assign EXT_BUS[15:0] = io_dout;
wire [15:0] io_din = EXT_BUS[31:16];
assign EXT_BUS[32] = dout_en;
wire io_strobe = EXT_BUS[33];
wire io_enable = EXT_BUS[34];

localparam EXT_CMD_MIN     = A800_GET_REGISTER;
localparam EXT_CMD_MAX     = A800_SET_REGISTER;

localparam A800_GET_REGISTER = 8;
localparam A800_SET_REGISTER = 9;

// Writing
localparam REG_CART1_SELECT = 1;
localparam REG_CART2_SELECT = 2;
localparam REG_RESET = 3;
localparam REG_PAUSE = 4;
localparam REG_FREEZER = 5;
localparam REG_RESET_RNMI = 6;

// Reading
localparam REG_ATARI_STATUS1 = 1;

reg [15:0] io_dout;
reg        dout_en = 0;
reg  [9:0] byte_cnt;

always@(posedge clk_sys) begin
	reg [15:0] cmd;

	if(~io_enable) begin
		dout_en <= 0;
		io_dout <= 0;
		byte_cnt <= 0;
	end
	else if(io_strobe) begin

		io_dout <= 0;
		if(~&byte_cnt) byte_cnt <= byte_cnt + 1'd1;

		if(byte_cnt == 0) begin
			cmd <= io_din;
			dout_en <= (io_din >= EXT_CMD_MIN && io_din <= EXT_CMD_MAX);
		end else begin
			case(cmd)

				A800_SET_REGISTER:
					case(io_din[15:8])
						REG_CART1_SELECT: cart1_select <= io_din[7:0];
						REG_CART2_SELECT: cart2_select <= io_din[7:0];
						REG_RESET: set_reset <= |io_din[7:0];
						REG_PAUSE: set_pause <= |io_din[7:0];
						REG_FREEZER: set_freezer <= |io_din[7:0];
						REG_RESET_RNMI: set_reset_rnmi <= |io_din[7:0];
					endcase

				A800_GET_REGISTER:
					case(io_din[15:8])
						REG_ATARI_STATUS1: io_dout <= atari_status1;
					endcase
			endcase
		end
	end
end

endmodule
