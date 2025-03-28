--  PBI bios rom emulation for the MiSTer Atari 800 core
--  Copyright (C) 2025 Wojciech Mostowski <wojciech.mostowski@gmail.com>
--
--  Based on cart_logic.vhd work by:
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
use IEEE.STD_LOGIC_ARITH.ALL;
--use IEEE.NUMERIC_STD.ALL;

library work;

entity PBIROM is
	Port (
		clk: in std_logic;
		clk_enable: in std_logic;
		reset_n: in std_logic;
		a: in std_logic_vector (10 downto 0);
		rw: in std_logic;
		data_in: in std_logic_vector(7 downto 0);
		d1xx: in std_logic;
		d8xx: in std_logic;
		pbi_rom_address: out std_logic_vector(12 downto 0);
		pbi_rom_address_enable: out std_logic;
		data_out: out std_logic_vector(7 downto 0);
		data_out_enable: out std_logic
	);	
end PBIROM;

architecture vhdl of PBIROM is

signal pbi_rom_bank: std_logic_vector(12 downto 11) := (others => '0');
signal pbi_rom_enable: std_logic := '0';
type small_ram is array(0 to 253) of std_logic_vector(7 downto 0);
signal pbi_ram: small_ram;

begin

process(a, rw, d1xx)
begin
	data_out_enable <= '0';
	data_out <= x"ff";

	if (d1xx = '1') and (rw = '1') then
		data_out_enable <= '1';
		if (a(7 downto 0) = x"FF") then
			-- read out PDVI register
			data_out <= x"00";
		elsif (a(7 downto 0) /= x"FE") then
			-- read out from D100-D1FD small RAM
			data_out <= pbi_ram(conv_integer(unsigned(a(7 downto 0))));
		end if;
	end if;
end process;

process(clk)
begin
	if rising_edge(clk) then
		if (reset_n = '0') then
			pbi_rom_bank <= (others => '0');
			pbi_rom_enable <= '0';
		else
			if (clk_enable = '1') and (d1xx = '1') and (rw = '0') then
				case a(7 downto 0) is
					when x"FF" =>
						-- This PBI is ID 0
						pbi_rom_enable <= data_in(0);
						-- TODO should the bank be reset to 0 every time
						-- we select the ROM? Probably yes
						if (data_in(0) = '1') then
							pbi_rom_bank <= (others => '0');						
						end if;
					when x"FE" =>
						pbi_rom_bank <= data_in(1 downto 0);
					when others => 
						pbi_ram(conv_integer(unsigned(a(7 downto 0)))) <= data_in;
				end case;
			end if;
		end if;
	end if;
end process;

process(a, rw, d8xx, pbi_rom_enable, pbi_rom_bank)
begin
	pbi_rom_address <= pbi_rom_bank & a(10 downto 0);
	pbi_rom_address_enable <= d8xx and rw and pbi_rom_enable;
end process;

end vhdl;
