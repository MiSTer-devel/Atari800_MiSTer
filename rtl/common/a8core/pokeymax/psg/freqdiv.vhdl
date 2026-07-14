---------------------------------------------------------------------------
-- (c) 2020 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY PSG_freqdiv IS
GENERIC
(
	bits : in integer
);
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	ENABLE : IN STD_LOGIC;

	SYNC_RESET : IN STD_LOGIC := '0';
	
	BIT_OUT : OUT STD_LOGIC;
	
	THRESHOLD : IN UNSIGNED(bits-1 downto 0)
);
END PSG_freqdiv;

ARCHITECTURE vhdl OF PSG_freqdiv IS
	signal count_reg: unsigned(bits-1 downto 0);
	signal count_next: unsigned(bits-1 downto 0);
BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			count_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			count_reg <= count_next;
		end if;
	end process;
	
	-- next state
	process(count_reg,enable,threshold,sync_reset)
		variable count_inc : unsigned(bits-1 downto 0);
	begin
		count_next <= count_reg;
		bit_out <= '0';
		if (enable = '1') then
			count_inc := count_reg+to_unsigned(1,bits);
			if (count_inc>=threshold) then
				count_next <= (others=>'0');
				bit_out <= '1';
			else
				count_next <= count_inc;
			end if;
		end if;

		if (sync_reset='1') then
			count_next <= (others=>'0');
		end if;
	end process;	
		
END vhdl;
