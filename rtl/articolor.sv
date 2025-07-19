//============================================================================
//
//  articolor.sv
//  Copyright (C) 2023 Alexey Melnikov
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module articolor
(
	input clk,
	input ce_pix,
	
	input enable,
	input colorset,

	input  [7:0] r_in,  g_in,  b_in,
	input        hbl_in, vbl_in, hs_in, vs_in,

	output reg [7:0] r_out, g_out, b_out,
	output reg       hbl_out, vbl_out, hs_out, vs_out
);

always @(posedge clk) begin
	reg [7:0] r_d[2],g_d[2],b_d[2];
	reg [1:0] mix;
	reg [1:0] hbl,vbl,hs,vs;
	reg n;
	
	if(ce_pix) begin
		n <= ~n;
		if(~hs_out & hs_in) n <= 0;

		mix <= 0;
		if(enable) begin
			if(r_d[0] >= 10 && r_d[0] == g_d[0] && g_d[0] == b_d[0] && !r_in && !g_in && !b_in && !r_d[1] && !g_d[1] && !b_d[1]) begin
				mix <= {1'b1,n};
			end 
			else if(!r_d[0] && !g_d[0] && !b_d[0] && r_in >= 10 && r_in == g_in && g_in == b_in && r_d[1] == r_in && g_d[1] == g_in && b_d[1] == b_in) begin
				mix <= {1'b1,~n};
			end
		end

		r_d[0] <= r_in;
		g_d[0] <= g_in;
		b_d[0] <= b_in;
		hbl[0] <= hbl_in;
		vbl[0] <= vbl_in;
		hs[0]  <= hs_in;
		vs[0]  <= vs_in;

		r_d[1] <= r_d[0];
		g_d[1] <= g_d[0];
		b_d[1] <= b_d[0];
		hbl[1] <= hbl[0];
		vbl[1] <= vbl[0];
		hs[1]  <= hs[0];
		vs[1]  <= vs[0];

		r_out  <= r_d[1];
		g_out  <= g_d[1];
		b_out  <= b_d[1];
		hbl_out<= hbl[1];
		vbl_out<= vbl[1];
		hs_out <= hs[1];
		vs_out <= vs[1];

		if(mix[1]) begin
			if(mix[0]) begin
				// This is more general and may work with colors other than B/W
				if (colorset) begin
					// PAL
					r_out <= 0;
					g_out <= (unsigned'(g_d[0] | g_d[1]) * 141) >> 8;
					b_out <= (unsigned'(b_d[0] | b_d[1]) * 255) >> 8;
				end
				else begin
					// NTSC
					r_out <= (unsigned'(r_d[0] | r_d[1]) * 134) >> 8;
					g_out <= (unsigned'(g_d[0] | g_d[1]) * 248) >> 8;
					b_out <= (unsigned'(b_d[0] | b_d[1]) * 113) >> 8;
				end
				// This is only for PAL and Atari palette
				//r_out <= 0;
				//case (r_d[0] | r_d[1])
				//	8'h11 : begin g_out <= 9; b_out <= 17; end
				//	8'h22 : begin g_out <= 19; b_out <= 34; end
				//	8'h33 : begin g_out <= 28; b_out <= 51; end
				//	8'h44 : begin g_out <= 38; b_out <= 68; end
				//	8'h55 : begin g_out <= 47; b_out <= 85; end
				//	8'h66 : begin g_out <= 56; b_out <= 102; end
				//	8'h77 : begin g_out <= 66; b_out <= 119; end
				//	8'h88 : begin g_out <= 75; b_out <= 136; end
				//	8'h99 : begin g_out <= 85; b_out <= 153; end
				//	8'haa : begin g_out <= 94; b_out <= 170; end
				//	8'hbb : begin g_out <= 103; b_out <= 187; end
				//	8'hcc : begin g_out <= 113; b_out <= 204; end
				//	8'hdd : begin g_out <= 122; b_out <= 221; end
				//	8'hee : begin g_out <= 132; b_out <= 238; end
				//	8'hff : begin g_out <= 141; b_out <= 255; end
				//	default: ;
				//endcase
			end
			else begin
				// This is more general and may work with colors other than B/W
				if (colorset) begin
					// PAL
					r_out <= (unsigned'(r_d[0] | r_d[1]) * 207) >> 8;
					g_out <= (unsigned'(g_d[0] | g_d[1]) * 109) >> 8;
					b_out <= (unsigned'(b_d[0] | b_d[1]) * 3) >> 8;
				end
				else begin
					// NTSC
					r_out <= (unsigned'(r_d[0] | r_d[1]) * 255) >> 8;
					g_out <= (unsigned'(g_d[0] | g_d[1]) * 133) >> 8;
					b_out <= (unsigned'(b_d[0] | b_d[1]) * 250) >> 8;
				end

				// This is only for PAL and Atari palette
				//b_out <= 2;
				//case (r_d[0] | r_d[1])
				//	8'h11 : begin r_out <= 14; g_out <= 7; b_out <= 0; end
				//	8'h22 : begin r_out <= 28; g_out <= 15; b_out <= 0; end
				//	8'h33 : begin r_out <= 41; g_out <= 22; b_out <= 1; end
				//	8'h44 : begin r_out <= 55; g_out <= 29; b_out <= 1; end
				//	8'h55 : begin r_out <= 69; g_out <= 36; b_out <= 1; end
				//	8'h66 : begin r_out <= 83; g_out <= 44; b_out <= 1; end
				//	8'h77 : begin r_out <= 97; g_out <= 51; b_out <= 1; end
				//	8'h88 : begin r_out <= 110; g_out <= 58; end
				//	8'h99 : begin r_out <= 124; g_out <= 65; end
				//	8'haa : begin r_out <= 138; g_out <= 73; end
				//	8'hbb : begin r_out <= 152; g_out <= 80; end
				//	8'hcc : begin r_out <= 166; g_out <= 87; end
				//	8'hdd : begin r_out <= 179; g_out <= 94; b_out <= 3; end
				//	8'hee : begin r_out <= 193; g_out <= 102; b_out <= 3; end
				//	8'hff : begin r_out <= 207; g_out <= 109; b_out <= 3; end
				//	default: ;
				//endcase
			end
		end

		hbl_out <= hbl_in;
		vbl_out <= vbl_in;
		hs_out  <= hs_in;
		vs_out  <= vs_in;
	end
end

endmodule
