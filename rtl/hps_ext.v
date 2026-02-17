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
	output reg        set_option_force,
	output reg        set_drive_led,
	output reg        set_xex_loader_mode,
	output reg  [7:0] cart1_select,
	output reg  [7:0] cart2_select,
	input      [15:0] atari_status1,
	input      [15:0] atari_status2,
	
	// Pokey SIO bridge
	output reg  [4:0] uart_addr,
	output reg        uart_enable,
	output reg        uart_wr,
	output reg  [7:0] uart_data_write,
	input      [15:0] uart_data_read
);

assign EXT_BUS[15:0] = io_dout;
wire [15:0] io_din = EXT_BUS[31:16];
assign EXT_BUS[32] = dout_en;
wire io_strobe = EXT_BUS[33];
wire io_enable = EXT_BUS[34];

localparam EXT_CMD_MIN     = A800_SIO_TX_STATUS;
localparam EXT_CMD_MAX     = A800_SET_REGISTER;

localparam A800_SIO_TX_STATUS = 3;
localparam A800_SIO_RX = 4;
localparam A800_SIO_RX_STATUS = 5;
localparam A800_SIO_GETDIV = 6;
localparam A800_SIO_ERROR = 7;

localparam A800_GET_REGISTER = 8;
localparam A800_SET_REGISTER = 9;

// Writing
localparam REG_CART1_SELECT = 1;
localparam REG_CART2_SELECT = 2;
localparam REG_RESET = 3;
localparam REG_PAUSE = 4;
localparam REG_FREEZER = 5;
localparam REG_RESET_RNMI = 6;
localparam REG_OPTION_FORCE = 7;
localparam REG_DRIVE_LED = 8;
localparam REG_XEX_LOADER_MODE = 9;

// SIO part
localparam REG_SIO_TX = 10;
localparam REG_SIO_SETDIV = 11;

// General reading for side effect free registers
localparam REG_ATARI_STATUS1 = 1;
localparam REG_ATARI_STATUS2 = 2;

reg [15:0] io_dout;
reg        dout_en = 0;
reg  [9:0] byte_cnt;

always@(posedge clk_sys) begin
	reg [15:0] cmd;

	uart_enable <= 0;
	uart_wr <= 0;

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
			if(io_din >= A800_SIO_TX_STATUS && io_din <= A800_SIO_ERROR) begin
				uart_enable <= 1;
				case(io_din)
					A800_SIO_TX_STATUS: uart_addr <= 5'h1;
					A800_SIO_RX: uart_addr <= 5'h2;
					A800_SIO_RX_STATUS: uart_addr <= 5'h3;
					A800_SIO_GETDIV: uart_addr <= 5'h4;
					A800_SIO_ERROR: uart_addr <= 5'h5;
				endcase
			end
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
						REG_OPTION_FORCE: set_option_force <= |io_din[7:0];
						REG_DRIVE_LED: set_drive_led <= |io_din[7:0];
						REG_XEX_LOADER_MODE: set_xex_loader_mode <= |io_din[7:0];
						REG_SIO_TX, REG_SIO_SETDIV:
							begin
								uart_data_write <= io_din[7:0];
								uart_wr <= 1;
								if(io_din[15:8] == REG_SIO_SETDIV)
									uart_addr <= 5'h4;
								else
									uart_addr <= 5'h0;
							end
					endcase

				A800_GET_REGISTER:
					case(io_din[15:8])
						REG_ATARI_STATUS1: io_dout <= atari_status1;
						REG_ATARI_STATUS2: io_dout <= atari_status2;
					endcase

				A800_SIO_TX_STATUS, A800_SIO_RX, A800_SIO_RX_STATUS, A800_SIO_GETDIV, A800_SIO_ERROR:
					io_dout <= uart_data_read;

			endcase
		end
	end
end

endmodule
