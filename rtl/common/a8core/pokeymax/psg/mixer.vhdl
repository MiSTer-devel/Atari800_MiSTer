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

ENTITY PSG_mixer IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	ENABLE : IN STD_LOGIC;
	
	NOISE : IN STD_LOGIC;
	CHANNEL : IN STD_LOGIC;
	
	NOISE_OFF : IN STD_LOGIC;
	TONE_OFF : IN STD_LOGIC;
	
	BIT_OUT : OUT STD_LOGIC
);
END PSG_mixer;

ARCHITECTURE vhdl OF PSG_mixer IS
	signal bit_reg: std_logic;
	signal bit_next: std_logic;
	signal tone_reg: std_logic;
	signal tone_next: std_logic;
BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			bit_reg <= '0';
			tone_reg <= '0';
		elsif (clk'event and clk='1') then
			bit_reg <= bit_next;
			tone_reg <= tone_next;
		end if;
	end process;
	
	-- next state
	process(tone_reg,bit_reg,enable,noise,channel,noise_off,tone_off)
		variable tone_comp : std_logic;
	begin
		tone_next <= tone_reg;
		bit_next <= bit_reg;
		
		if (enable = '1') then
			tone_comp := tone_reg xor channel;

			tone_next <= tone_comp;

			bit_next <= (noise or noise_off) and (tone_reg or tone_off);
		end if;
	end process;	
		
	-- output
	bit_out <= bit_reg;
		
END vhdl;
