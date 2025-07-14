--  Cart bank switching and memory access core
--
--  Copyright (C) 2011-2014 Matthias Reichl <hias@horus.com>
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the Lesser GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;

entity CartLogic is
    Port (	clk: in std_logic;
		clk_enable: in std_logic;
		cart_mode: in std_logic_vector(7 downto 0);
		a: in std_logic_vector (12 downto 0);
		cctl_n: in std_logic;
		d_in: in std_logic_vector(7 downto 0);
		rw: in std_logic;
		s4_n: in std_logic;
		s5_n: in std_logic;
		--s4_n_out: out std_logic;
		--s5_n_out: out std_logic;
		rd4: out std_logic;
		rd5: out std_logic;
		cart_address: out std_logic_vector(20 downto 0);
		cart_address_enable: out boolean;
		cctl_dout: out std_logic_vector(7 downto 0);
		cctl_dout_enable: out std_logic_vector(2 downto 0);
		int_d_in : in std_logic_vector(7 downto 0);
		int_d_out : out std_logic_vector(7 downto 0);
		master : in std_logic;
		passthru : out std_logic;
		rtc_mode : out std_logic_vector(1 downto 0)
	);
		
end CartLogic;

architecture vhdl of CartLogic is

-- general cart configuration
signal cfg_bank: std_logic_vector(20 downto 13) := (others => '0');
signal cfg_enable: std_logic := '1';

subtype cart_mode_type is std_logic_vector(7 downto 0);
-- 8k modes
constant cart_mode_off:		cart_mode_type := "00000000";
constant cart_mode_8k:		cart_mode_type := "00000001";
constant cart_mode_atarimax1:	cart_mode_type := "00000010";
constant cart_mode_atarimax8:	cart_mode_type := "00000011";
constant cart_mode_oss_16k:	cart_mode_type := "00000100";
constant cart_mode_oss_8k:	cart_mode_type := "00000101";
constant cart_mode_oss_043M:	cart_mode_type := "00000110";
--constant cart_mode_oss_034M:	cart_mode_type := "00000111";

constant cart_mode_sdx64:	cart_mode_type := "00001000";
constant cart_mode_sdx128:	cart_mode_type := "00001001";
constant cart_mode_diamond64:	cart_mode_type := "00001010";
constant cart_mode_express64:	cart_mode_type := "00001011";

constant cart_mode_atrax_128:	cart_mode_type := "00001100";
constant cart_mode_williams_64:	cart_mode_type := "00001101";
constant cart_mode_williams_32:	cart_mode_type := "00001110";
constant cart_mode_williams_16:	cart_mode_type := "00001111";

constant cart_mode_atarimax8n:	cart_mode_type := "00010000";
constant cart_mode_dcart:	cart_mode_type := "00010001";
constant cart_mode_blizzard_4:	cart_mode_type := "00010010";
constant cart_mode_blizzard_32:	cart_mode_type := "00010011";
constant cart_mode_right_8k:	cart_mode_type := "00010100";
constant cart_mode_right_4k:	cart_mode_type := "00010101";
constant cart_mode_2k:		cart_mode_type := "00010110";
constant cart_mode_4k:		cart_mode_type := "00010111";

constant cart_mode_jatari_8:	cart_mode_type := "00011000";
constant cart_mode_jatari_16:	cart_mode_type := "00011001";
constant cart_mode_jatari_32:	cart_mode_type := "00011010";
constant cart_mode_jatari_64:	cart_mode_type := "00011011";
constant cart_mode_jatari_128:	cart_mode_type := "00011100";
constant cart_mode_jatari_256:	cart_mode_type := "00011101";
constant cart_mode_jatari_512:	cart_mode_type := "00011110";
constant cart_mode_jatari_1024:	cart_mode_type := "00011111";

-- 16k modes
--constant cart_mode_flexi:	cart_mode_type := "00100000";
constant cart_mode_16k:		cart_mode_type := "00100001";
constant cart_mode_megamax16:	cart_mode_type := "00100010";
constant cart_mode_blizzard_16:	cart_mode_type := "00100011";
constant cart_mode_sic_128:	cart_mode_type := "00100100";
constant cart_mode_sic_256:	cart_mode_type := "00100101";
constant cart_mode_sic_512:	cart_mode_type := "00100110";
constant cart_mode_sic_1024:	cart_mode_type := "00100111";

constant cart_mode_mega_16:	cart_mode_type := "00101000";
constant cart_mode_mega_32:	cart_mode_type := "00101001";
constant cart_mode_mega_64:	cart_mode_type := "00101010";
constant cart_mode_mega_128:	cart_mode_type := "00101011";
constant cart_mode_mega_256:	cart_mode_type := "00101100";
constant cart_mode_mega_512:	cart_mode_type := "00101101";
constant cart_mode_mega_1024:	cart_mode_type := "00101110";
constant cart_mode_mega_2048:	cart_mode_type := "00101111";

constant cart_mode_xegs_32:	cart_mode_type := "00110000";
constant cart_mode_xegs_64:	cart_mode_type := "00110001";
constant cart_mode_xegs_128:	cart_mode_type := "00110010";
constant cart_mode_xegs_256:	cart_mode_type := "00110011";
constant cart_mode_xegs_512:	cart_mode_type := "00110100";
constant cart_mode_xegs_1024:	cart_mode_type := "00110101";
constant cart_mode_xegs_64_2:	cart_mode_type := "00110110";

constant cart_mode_sxegs_32:	cart_mode_type := "00111000";
constant cart_mode_sxegs_64:	cart_mode_type := "00111001";
constant cart_mode_sxegs_128:	cart_mode_type := "00111010";
constant cart_mode_sxegs_256:	cart_mode_type := "00111011";
constant cart_mode_sxegs_512:	cart_mode_type := "00111100";
constant cart_mode_sxegs_1024:	cart_mode_type := "00111101";


constant cart_mode_xemulti_8:		cart_mode_type := "01101000";
constant cart_mode_xemulti_16:	cart_mode_type := "01101001";
constant cart_mode_xemulti_32:	cart_mode_type := "01101010";
constant cart_mode_xemulti_64:	cart_mode_type := "01101011";
constant cart_mode_xemulti_128:	cart_mode_type := "01101100";
constant cart_mode_xemulti_256:	cart_mode_type := "01101101";
constant cart_mode_xemulti_512:	cart_mode_type := "01101110";
constant cart_mode_xemulti_1024:	cart_mode_type := "01101111";

constant cart_mode_phoenix:			cart_mode_type := "01000000";
constant cart_mode_ast_32:				cart_mode_type := "01000001";
constant cart_mode_atrax_int_128:	cart_mode_type := "01000010";
constant cart_mode_atrax_sdx_64:		cart_mode_type := "01000011";
constant cart_mode_atrax_sdx_128:	cart_mode_type := "01000100";
constant cart_mode_turbosoft_64:		cart_mode_type := "01000101";
constant cart_mode_turbosoft_128:		cart_mode_type := "01000110";
constant cart_mode_ultracart_32:		cart_mode_type := "01000111";
constant cart_mode_dawli_32:			cart_mode_type := "01001000";
constant cart_mode_dawli_64:			cart_mode_type := "01001001";
constant cart_mode_jrc_lin_64:		cart_mode_type := "01001010";
constant cart_mode_jrc_int_64:		cart_mode_type := "01001011";
constant cart_mode_sdx_side2:			cart_mode_type := "01001100";
constant cart_mode_sdx_u1mb:			cart_mode_type := "01001101";

constant cart_mode_db_32:			cart_mode_type := "01110000";
constant cart_mode_corina_512:		cart_mode_type := "01110001";
constant cart_mode_corina_1024:		cart_mode_type := "01110010";
constant cart_mode_bounty_bob:		cart_mode_type := "01110011";

signal cart_mode_prev: cart_mode_type := cart_mode_off;

-- OSS cart emulation
signal oss_bank: std_logic_vector(2 downto 0) := "000";

-- for carts that can selectively enable 8xxx/axxx
signal cart_8xxx_enable: std_logic := '0';
signal cart_axxx_enable: std_logic := '1';
signal disable_rom: std_logic := '0'; -- for XEGS 8-15 bank cart
signal mirror_8a: std_logic := '0'; -- for the last EEPROM bank on Corina carts
signal cart_write_enable: std_logic := '0'; -- let's try making the SRAM part of the Corina cart work
signal cart_passthru: std_logic := '0';

signal access_8xxx: boolean;
signal access_axxx: boolean;

signal bb_bank_8x: std_logic_vector(1 downto 0) := "00";
signal bb_bank_9x: std_logic_vector(1 downto 0) := "00";

signal reset_n: std_logic := '1';

begin

access_8xxx <= ( s4_n = '0');
access_axxx <= ( s5_n = '0');

rtc_mode(0) <= '1' when cart_mode = cart_mode_sdx_u1mb else '0';
rtc_mode(1) <= '1' when cart_mode = cart_mode_sdx_side2 else '0';

passthru <= cart_passthru;

-- pass through s4/s5 if cart mode is off
--set_passthrough: process(s4_n, s5_n, cart_mode)
--begin
--	if (cart_mode = cart_mode_off) then
--		s4_n_out <= s4_n;
--		s5_n_out <= s5_n;
--	else
--		s4_n_out <= '1';
--		s5_n_out <= '1';
--	end if;
--end process set_passthrough;

int_d_out <= int_d_in(3) & int_d_in(7) & int_d_in(1) & int_d_in(0) & int_d_in(4) & int_d_in(2) & int_d_in(6) & int_d_in(5) when cart_mode = cart_mode_atrax_int_128 else
	     int_d_in(2) & int_d_in(3) & int_d_in(6) & int_d_in(7) & int_d_in(1) & int_d_in(5) & int_d_in(0) & int_d_in(4) when (cart_mode = cart_mode_atrax_sdx_64) or (cart_mode = cart_mode_atrax_sdx_128) else
	     int_d_in;

-- remember previous cartridge mode
set_cart_mode_prev: process(clk)
begin
	if rising_edge(clk) then
		cart_mode_prev <= cart_mode;
	end if;
end process set_cart_mode_prev;

-- generate reset if cartridge mode has changed
generate_reset: process(cart_mode, cart_mode_prev)
begin
	if (cart_mode = cart_mode_prev) then
		reset_n <= '1';
	else
		reset_n <= '0';
	end if;
end process generate_reset;

-- read back config registers
config_io: process(a, rw, cctl_n,
	cfg_bank,cfg_enable,
	cart_mode,
	cart_8xxx_enable, cart_axxx_enable,cart_passthru)
begin
	cctl_dout_enable <= "000";
	cctl_dout <= x"ff";

	if (cctl_n = '0') and (rw = '1') then
		-- sic register readback at $D500-$D51F
		if (cart_mode(7 downto 2) = "001001") and ((a(7 downto 5) = "000") or ((cart_mode = cart_mode_sic_1024) and (a(7 downto 6) = "00"))) then
			cctl_dout_enable(0) <= '1';
			-- bit 7 = 0 means flash is write protected
			cctl_dout <= "0" & (not cart_axxx_enable) & cart_8xxx_enable & cfg_bank(18 downto 14);
		end if;
		if (cart_mode = cart_mode_dcart) then
			cctl_dout_enable(1 downto 0) <= "11";
		end if;
		if (cart_mode = cart_mode_ast_32) then
			cctl_dout_enable(2 downto 0) <= "101";
		end if;
		if (cart_mode = cart_mode_sdx_side2) and (a(7 downto 0) = x"E1") then
			cctl_dout_enable(0) <= '1';
			cctl_dout <= (not cfg_enable) & (not cart_passthru) & cfg_bank(18 downto 13);			
		end if;
	end if;
end process config_io;

set_config: process(clk)
	variable bank_counter : integer range 0 to 127 := 0;
begin
	if rising_edge(clk) then
		if (reset_n = '0') then
			cfg_bank <= (others => '0');
			bank_counter := 0;
			cfg_enable <= '1';
			oss_bank <= "001";
			cart_8xxx_enable <= '0';
			cart_axxx_enable <= '1';
			disable_rom <= '0';
			mirror_8a <= '0';
			cart_write_enable <= '0';
			bb_bank_8x <= "00";
			bb_bank_9x <= "00";
			cart_passthru <= '0';

			-- cart specific initialization
			case cart_mode is
			when cart_mode_atarimax8 =>
				cfg_bank <= x"7F"; -- startup in last bank
			when cart_mode_oss_043M =>
				oss_bank <= "000";
			when cart_mode_jrc_int_64 => 
				cfg_bank <= "00000111";
			when others => null;
			end case;
		else
			if (clk_enable = '1') then 
			 if (cctl_n = '0') then
				if (rw = '0') then
					-- modes using data lines to switch banks
					
					-- (s)xegs bank select
					if (cart_mode(7 downto 4) = cart_mode_xegs_32(7 downto 4)) then
						-- sxegs disable via bit 7
						if (cart_mode(3) = '1') then
							cfg_enable <= not d_in(7);
						end if;
						if (cart_mode = cart_mode_xegs_64_2) then
							-- mark the rom to float (unconnected)
							disable_rom <= not d_in(3);
						end if;

						case cart_mode is
						when cart_mode_xegs_32 | cart_mode_sxegs_32 =>
							cfg_bank(14 downto 13) <= d_in(1 downto 0);
						when cart_mode_xegs_64 | cart_mode_sxegs_64 | cart_mode_xegs_64_2 =>
							cfg_bank(15 downto 13) <= d_in(2 downto 0);
						when cart_mode_xegs_128 | cart_mode_sxegs_128 =>
							cfg_bank(16 downto 13) <= d_in(3 downto 0);
						when cart_mode_xegs_256 | cart_mode_sxegs_256 =>
							cfg_bank(17 downto 13) <= d_in(4 downto 0);
						when cart_mode_xegs_512 | cart_mode_sxegs_512 =>
							cfg_bank(18 downto 13) <= d_in(5 downto 0);
						when cart_mode_xegs_1024 | cart_mode_sxegs_1024 =>
							cfg_bank(19 downto 13) <= d_in(6 downto 0);
						when others =>
							null;
						end case;
					end if;
					-- megacart bank select
					if (cart_mode(7 downto 3) = cart_mode_mega_32(7 downto 3)) then
						-- disable via bit 7
						cfg_enable <= not d_in(7);
						case cart_mode is
						when cart_mode_mega_32 =>
							cfg_bank(14 downto 14) <= d_in(0 downto 0);
						when cart_mode_mega_64 =>
							cfg_bank(15 downto 14) <= d_in(1 downto 0);
						when cart_mode_mega_128 =>
							cfg_bank(16 downto 14) <= d_in(2 downto 0);
						when cart_mode_mega_256 =>
							cfg_bank(17 downto 14) <= d_in(3 downto 0);
						when cart_mode_mega_512 =>
							cfg_bank(18 downto 14) <= d_in(4 downto 0);
						when cart_mode_mega_1024 =>
							cfg_bank(19 downto 14) <= d_in(5 downto 0);
						when cart_mode_mega_2048 =>
							cfg_bank(20 downto 14) <= d_in(6 downto 0);
						when others =>
							null;
						end case;
					end if;
					
					-- atrax 128
					if (cart_mode = cart_mode_atrax_128) or (cart_mode = cart_mode_atrax_int_128) then
						cfg_enable <= not d_in(7);
						cfg_bank(16 downto 13) <= d_in(3 downto 0);
					end if;

					if ((cart_mode = cart_mode_jrc_lin_64) or (cart_mode = cart_mode_jrc_int_64)) and (a(7) = '0') then
						cfg_enable <= not d_in(7);
						if (cart_mode = cart_mode_jrc_int_64) then
							cfg_bank(15 downto 13) <= not(d_in(4)) & not(d_in(5)) & not(d_in(6));
						else 
							cfg_bank(15 downto 13) <= d_in(6 downto 4);
						end if;
					end if;

					-- Corina
					if ((cart_mode = cart_mode_corina_512) or (cart_mode = cart_mode_corina_1024)) and (a(7 downto 0) = x"00") then
					   if d_in(7) = '1' then
							cfg_enable <= '0';
						else
							if d_in(6 downto 5) /= "11" then
								cart_write_enable <= '0';
								cfg_enable <= '1';
								cfg_bank(19 downto 14) <= d_in(5 downto 0);
								mirror_8a <= d_in(6); -- EEPROM access in the last 8K block
								-- try to imitate the SRAM
								if (d_in(6) = '1') or ((d_in(5) = '1') and (cart_mode = cart_mode_corina_512)) then
									cart_write_enable <= '1';
								end if;
							end if;
						end if;
					end if;
					
					-- sic
					if (cart_mode(7 downto 2) = "001001") and ((a(7 downto 5) = "000")  or ((cart_mode = cart_mode_sic_1024) and (a(7 downto 6) = "00"))) then
						cart_8xxx_enable <= d_in(5);
						cart_axxx_enable <= not d_in(6);
						case cart_mode is
						when cart_mode_sic_128 =>
							cfg_bank(16 downto 14) <= d_in(2 downto 0);
						when cart_mode_sic_256 =>
							cfg_bank(17 downto 14) <= d_in(3 downto 0);
						when cart_mode_sic_512 =>
							cfg_bank(18 downto 14) <= d_in(4 downto 0);
						when cart_mode_sic_1024 =>
							cfg_bank(19 downto 14) <= d_in(7)&d_in(4 downto 0);
						when others =>
							null;
						end case;
					end if;

					-- XE multicart
					if (cart_mode(7 downto 3) = "01101") then
						cart_8xxx_enable <= d_in(7) and d_in(0);
						cart_axxx_enable <= '1';
						case cart_mode is
						when cart_mode_xemulti_16 =>
							cfg_bank(13) <= d_in(0);
						when cart_mode_xemulti_32 =>
							cfg_bank(14 downto 13) <= d_in(1 downto 0);
						when cart_mode_xemulti_64 =>
							cfg_bank(15 downto 13) <= d_in(2 downto 0);
						when cart_mode_xemulti_128 =>
							cfg_bank(16 downto 13) <= d_in(3 downto 0);
						when cart_mode_xemulti_256 =>
							cfg_bank(17 downto 13) <= d_in(4 downto 0);
						when cart_mode_xemulti_512 =>
							cfg_bank(18 downto 13) <= d_in(5 downto 0);
						when cart_mode_xemulti_1024 =>
							cfg_bank(19 downto 13) <= d_in(6 downto 0);
						when others =>
							null;
						end case;
					end if;

					-- dcart & j(atari)cart
					if (cart_mode(7 downto 3) = "00011") or (cart_mode = cart_mode_dcart) then
						cfg_enable <= not a(7);
						case cart_mode is
						when cart_mode_jatari_16 =>
							cfg_bank(13) <= a(0);
						when cart_mode_jatari_32 =>
							cfg_bank(14 downto 13) <= a(1 downto 0);
						when cart_mode_jatari_64 =>
							cfg_bank(15 downto 13) <= a(2 downto 0);
						when cart_mode_jatari_128 =>
							cfg_bank(16 downto 13) <= a(3 downto 0);
						when cart_mode_jatari_256 =>
							cfg_bank(17 downto 13) <= a(4 downto 0);
						when cart_mode_jatari_512 | cart_mode_dcart =>
							cfg_bank(18 downto 13) <= a(5 downto 0);
						when cart_mode_jatari_1024 =>
							cfg_bank(19 downto 13) <= a(6 downto 0);
						when others =>
							null;
						end case;
					end if;

					-- ast 32
					if (cart_mode = cart_mode_ast_32) then
						cfg_enable <= '0';
						bank_counter := bank_counter + 1;
						cfg_bank(19 downto 13) <= std_logic_vector(to_unsigned(bank_counter,7));
					end if;

					if ((cart_mode = cart_mode_sdx_u1mb) and (a(7 downto 0) = x"E0")) or ((cart_mode = cart_mode_sdx_side2) and (a(7 downto 0) = x"E1"))then
						cfg_enable <= not(d_in(7));
						cart_passthru <= d_in(7) and not(d_in(6));
						cfg_bank(18 downto 13) <= d_in(5 downto 0);
					end if;

				end if; -- rw = 0

				-- cart config using addresses, ignore read/write
				case cart_mode is
				-- blizzard 16 / 4, phoenix
				when cart_mode_blizzard_16 | cart_mode_blizzard_4 | cart_mode_phoenix =>
					cfg_enable <= '0';
				-- ultracart 32
				when cart_mode_ultracart_32 =>
					bank_counter := bank_counter + 1;
				 	if (bank_counter = 4) then
						cfg_enable <= '0';
						bank_counter := 127;
					else
						cfg_enable <= '1';
						cfg_bank(14 downto 13) <= std_logic_vector(to_unsigned(bank_counter,2));
					end if;
				-- adawliah 32/64
				when cart_mode_dawli_32 =>
					bank_counter := bank_counter + 1;
					cfg_bank(14 downto 13) <= std_logic_vector(to_unsigned(bank_counter,2));
				when cart_mode_dawli_64 =>
					bank_counter := bank_counter + 1;
					cfg_bank(15 downto 13) <= std_logic_vector(to_unsigned(bank_counter,3));
				-- blizzard 32
				when cart_mode_blizzard_32 =>
				 	if (bank_counter = 3) then
						cfg_enable <= '0';
					else
						bank_counter := bank_counter + 1;
						cfg_bank(14 downto 13) <= std_logic_vector(to_unsigned(bank_counter,2));
					end if;
				when cart_mode_db_32 =>
					cfg_bank(14 downto 13) <= a(1 downto 0);
				when cart_mode_oss_043M =>
					if a(3) = '1' then
						-- disable everything
						oss_bank <= "111";
					else
						case a(1 downto 0) is
						when "10" =>
							-- lower bank floats
							oss_bank <= "110";
						-- valid bank from 0 to 5 (3 never used)
						when "01" =>
							-- unuseful banks that are AND-ed
							-- #4 & #5 - firmware is responsible for prepping these
							oss_bank <= "10" & a(2);
						when "00" =>
							-- banks 0 or 1
							oss_bank <= "00" & a(2);
						when "11" =>
							-- bank 2
							oss_bank <= "010";
						end case;
					end if;
				when cart_mode_oss_16k | cart_mode_oss_8k =>
					oss_bank(1 downto 0) <= a(0) & NOT a(3);
				when cart_mode_turbosoft_64 =>
						cfg_bank(15 downto 13) <= a(2 downto 0);
						cfg_enable <= not(a(4));
				when cart_mode_turbosoft_128 =>
						cfg_bank(16 downto 13) <= a(3 downto 0);
						cfg_enable <= not(a(4));
				when cart_mode_atarimax1 =>
					-- D500-D50F: set bank, enable
					if (a(7 downto 4) = x"0") then
						cfg_bank(16 downto 13) <= a(3 downto 0);
						cfg_enable <= '1';
					end if;
					-- D510-D51F: disable
					if (a(7 downto 4) = x"1") then
						cfg_enable <= '0';
					end if;
				when cart_mode_atarimax8 | cart_mode_atarimax8n =>
					-- D500-D57F: set bank, enable
					if (a(7) = '0') then
						cfg_bank(19 downto 13) <= a(6 downto 0);
						cfg_enable <= '1';
					else
					-- D580-D5FF: disable
						cfg_enable <= '0';
					end if;
				when cart_mode_megamax16 =>
					-- D500-D57F: set 16k bank, enable
					if (a(7) = '0') then
						cfg_bank(20 downto 14) <= a(6 downto 0);
						cfg_enable <= '1';
					else
						cfg_enable <= '0';
					end if;
				when cart_mode_williams_64 | cart_mode_williams_32 | cart_mode_williams_16 =>
					if (a(7 downto 4) = x"0") then
						cfg_enable <= not a(3) ;
						if ((cart_mode = cart_mode_williams_16) and (a(2 downto 1) = "00")) then
							cfg_bank(13) <= a(0);
						end if;
						if ((cart_mode = cart_mode_williams_32) and (a(2) = '0')) then
							cfg_bank(14 downto 13) <= a(1 downto 0);
						end if;
						if (cart_mode = cart_mode_williams_64) then
							cfg_bank(15 downto 13) <= a(2 downto 0);
						end if;
					end if;
					when cart_mode_sdx64 | cart_mode_atrax_sdx_64 =>
					-- enable the other cartridge - not a(2) and a(3)
					if (a(7 downto 4) = x"E") then
						cart_passthru <= not(a(2)) and a(3);
						cfg_enable <= not a(3);
						cfg_bank(15 downto 13) <= not a(2 downto 0);
					end if;
				when cart_mode_sdx128 | cart_mode_atrax_sdx_128 =>
					-- enable the other cartridge - not a(2) and a(3)
					if (a(7 downto 5) = "111") then
						cart_passthru <= not(a(2)) and a(3);
						cfg_enable <= not a(3);
						cfg_bank(16 downto 13) <= not a(4) & not a(2 downto 0);
					end if;				
				when cart_mode_diamond64 =>
					if (a(7 downto 4) = x"D") then
						cfg_enable <= not a(3);
						cfg_bank(15 downto 13) <= not a(2 downto 0);
					end if;
				when cart_mode_express64 =>
					if (a(7 downto 4) = x"7") then
						cfg_enable <= not a(3);
						cfg_bank(15 downto 13) <= not a(2 downto 0);
					end if;
				when others => null;
				end case;
			 end if;
			 if (cart_mode = cart_mode_bounty_bob) and (s4_n = '0') then
              case a is
                 when "0111111110110" => bb_bank_8x <= "00";
                 when "0111111110111" => bb_bank_8x <= "01";
                 when "0111111111000" => bb_bank_8x <= "10";
                 when "0111111111001" => bb_bank_8x <= "11";
                 when "1111111110110" => bb_bank_9x <= "00";
                 when "1111111110111" => bb_bank_9x <= "01";
                 when "1111111111000" => bb_bank_9x <= "10";
                 when "1111111111001" => bb_bank_9x <= "11";
                 when others => null;
              end case;
			 end if;
			end if;
		end if;
	end if;
end process set_config;

access_cart_data: process(a, rw, access_8xxx, access_axxx,
	cfg_bank, cfg_enable,
	cart_mode,
	oss_bank,
	cart_8xxx_enable, cart_axxx_enable,
	disable_rom,mirror_8a,bb_bank_8x,bb_bank_9x,cart_write_enable,
	master)

variable bool_rd4: boolean;
variable bool_rd5: boolean;
begin
	cart_address <= cfg_bank & a(12 downto 0);
	
	if (cart_mode = cart_mode_atrax_int_128) then
		cart_address <= cfg_bank & a(3) & a(11) & a(10) & a(12) & a(9) & a(2) & a(1) & a(0) & a(8) & a(7) & a(6) & a(5) & a(4);
	end if;
	if (cart_mode = cart_mode_atrax_sdx_64) or (cart_mode = cart_mode_atrax_sdx_128) then
		cart_address(15 downto 0) <= a(3) & a(4) & a(5) & a(2) & cfg_bank(14) & cfg_bank(15) & cfg_bank(13) & a(6) & a(1) & a(0) & a(7) & a(8) & a(9) & a(12) & a(11) & a(10);
	end if;
	bool_rd4 := false;
	bool_rd5 := (cfg_enable = '1');
	cart_address_enable <= (cfg_enable = '1') and access_axxx;

	if (cart_mode(5) = '1') then	-- default for 16k carts
		bool_rd4 := (cfg_enable = '1');
		cart_address_enable <= (cfg_enable = '1') and (access_8xxx or access_axxx) and (disable_rom = '0');
	end if;

	case cart_mode is
	when cart_mode_2k =>
		cart_address(12 downto 11) <= "00";
		cart_address_enable <= (a(12 downto 11) = "11");
	when cart_mode_4k =>
		cart_address(12) <= '0';
		cart_address_enable <= (a(12) = '1');
	when cart_mode_blizzard_4 =>
		cart_address(12) <= '0';
	when cart_mode_right_4k =>
		bool_rd5 := false;
		bool_rd4 := true;
		cart_address(12) <= '0';
		cart_address_enable <= access_8xxx and (a(12) = '1');
	when cart_mode_right_8k =>
		bool_rd5 := false;
		bool_rd4 := true;
		cart_address_enable <= access_8xxx;
	when cart_mode_ast_32 =>
		cart_address <= "000000" & cfg_bank(19 downto 13) & a(7 downto 0);
	when cart_mode_16k | cart_mode_megamax16 | cart_mode_blizzard_16 =>
		if (access_8xxx) then
			cart_address(13) <= '0';
		else
			cart_address(13) <= '1';
		end if;
	when cart_mode_oss_043M =>
		if (oss_bank = "111") then
			bool_rd5 := false;
			cart_address_enable <= false;
		else
			if (a(12) = '1') then
				-- always bank 3
				cart_address(13 downto 12) <= "11";
			else
				if (oss_bank(2 downto 1) = "11") then
					-- ROM disconnected
					cart_address_enable <= false;
				else
					cart_address(14 downto 12) <= oss_bank;
				end if;
			end if;
		end if;
	when cart_mode_oss_16k | cart_mode_oss_8k =>
		if (oss_bank(1 downto 0) = "00") then
			bool_rd5 := false;
			cart_address_enable <= false;
		else
			if (cart_mode = cart_mode_oss_16k) then
				cart_address(13) <= oss_bank(1) and (not a(12));
			end if;
			cart_address(12) <= oss_bank(0) and (not a(12));
		end if;
	when cart_mode_xegs_32 | cart_mode_sxegs_32 | cart_mode_db_32 =>
		if (access_axxx) then
			cart_address(14 downto 13) <= (others => '1');
		end if;
	when cart_mode_xegs_64 | cart_mode_sxegs_64 | cart_mode_xegs_64_2 =>
		if (access_axxx) then
			cart_address(15 downto 13) <= (others => '1');
		end if;
	when cart_mode_xegs_128 | cart_mode_sxegs_128 =>
		if (access_axxx) then
			cart_address(16 downto 13) <= (others => '1');
		end if;
	when cart_mode_xegs_256 | cart_mode_sxegs_256 =>
		if (access_axxx) then
			cart_address(17 downto 13) <= (others => '1');
		end if;
	when cart_mode_xegs_512 | cart_mode_sxegs_512 =>
		if (access_axxx) then
			cart_address(18 downto 13) <= (others => '1');
		end if;
	when cart_mode_xegs_1024 | cart_mode_sxegs_1024 =>
		if (access_axxx) then
			cart_address(19 downto 13) <= (others => '1');
		end if;
	when cart_mode_mega_16 | cart_mode_mega_32 | cart_mode_mega_64 | cart_mode_mega_128 |
	     cart_mode_mega_256 | cart_mode_mega_512 | cart_mode_mega_1024 | cart_mode_mega_2048 =>
		if (access_8xxx) then
			cart_address(13) <= '0';
		else
			cart_address(13) <= '1';
		end if;
	when cart_mode_corina_512 | cart_mode_corina_1024 =>
		cart_address(13) <= '0';
		if(mirror_8a = '0' and access_axxx) then
			cart_address(13) <= '1';
		end if;
	when cart_mode_sic_128 | cart_mode_sic_256 | cart_mode_sic_512 | cart_mode_sic_1024 |
	     cart_mode_xemulti_16 | cart_mode_xemulti_32 | cart_mode_xemulti_64 | cart_mode_xemulti_128 |
	     cart_mode_xemulti_256 | cart_mode_xemulti_512 | cart_mode_xemulti_1024 =>
		bool_rd4 := (cfg_enable = '1') and (cart_8xxx_enable = '1');
		bool_rd5 := (cfg_enable = '1') and (cart_axxx_enable = '1');
		cart_address_enable <= (access_8xxx and (cfg_enable = '1') and (cart_8xxx_enable = '1'))
				or
			     (access_axxx and (cfg_enable = '1') and (cart_axxx_enable = '1'));
		if (access_8xxx) then
			cart_address(13) <= '0';
		else
			-- either on sic! or xe multicart and cart_8xxx_enable
			if (cart_mode(7 downto 3) /= "01101") or (cart_8xxx_enable = '1') then
				cart_address(13) <= '1';
			end if;
		end if;
	when cart_mode_bounty_bob =>
		if access_axxx then
			cart_address(15 downto 13) <= "100";
		else
			if a(12) = '1' then
				cart_address(14 downto 12) <= '1' & bb_bank_9x;
			else
				cart_address(14 downto 12) <= '0' & bb_bank_8x;
			end if;
		end if;
	when cart_mode_off =>
		bool_rd4 := false;
		bool_rd5 := false;
		cart_address_enable <= false;
	when others =>
		null;
	end case;

	if (master = '0') then
		cart_address(20) <= '1';
	end if;
	
	if (bool_rd4) then
		rd4 <= '1';
	else
		rd4 <= '0';
	end if;

	if (bool_rd5) then
		rd5 <= '1';
	else
		rd5 <= '0';
	end if;

	-- disable writes
	if  (rw = '0' and cart_write_enable = '0') then
		cart_address_enable <= false;
	end if;

end process access_cart_data;

end vhdl;
