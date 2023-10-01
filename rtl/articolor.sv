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
			if(r_d[0] >= 238 && g_d[0] >= 238 && b_d[0] >= 238 && !r_in && !g_in && !b_in && !r_d[1] && !g_d[1] && !b_d[1]) begin
				mix <= {1'b1,n};
			end 
			else if(!r_d[0] && !g_d[0] && !b_d[0] && r_in >= 238 && g_in >= 238 && b_in >= 238 && r_d[1] >= 238 && g_d[1] >= 238 && b_d[1] >= 238) begin
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
				r_out <= 0;
				g_out <= 141;
				b_out <= 255;
			end
			else begin
				r_out <= 207;
				g_out <= 109;
				b_out <= 3;
			end
		end

		hbl_out <= hbl_in;
		vbl_out <= vbl_in;
		hs_out  <= hs_in;
		vs_out  <= vs_in;
	end
end

endmodule
