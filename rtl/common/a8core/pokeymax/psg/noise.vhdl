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

ENTITY PSG_noise IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	ENABLE : IN STD_LOGIC;
	TICK : IN STD_LOGIC;
	
	BIT_OUT : OUT STD_LOGIC
);
END PSG_noise;

ARCHITECTURE vhdl OF PSG_noise IS
	signal shift_reg: std_logic_vector(16 downto 0);
	signal shift_next: std_logic_vector(16 downto 0);

	signal noise_reg : std_logic;
	signal noise_next : std_logic;
BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			shift_reg <= (others=>'0');
			noise_reg <= '0';
		elsif (clk'event and clk='1') then
			shift_reg <= shift_next;
			noise_reg <= noise_next;
		end if;
	end process;
	
	-- next state lfsr
	process(shift_reg,enable)
	begin
		shift_next <= shift_reg;
		if (enable = '1') then
			shift_next <= (shift_reg(3) xnor shift_reg(0))&shift_reg(16 downto 1);
		end if;
	end process;

	-- next state output
	process(shift_reg,noise_reg,tick)
	begin
		noise_next <= noise_reg;
		if (tick = '1') then
			noise_next <= shift_reg(0);
		end if;
	end process;
	
	-- output
	bit_out <= noise_reg;
		
END vhdl;
