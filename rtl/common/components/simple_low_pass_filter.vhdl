---------------------------------------------------------------------------
-- (c) 2018 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

--Filter appropriate for 1.8MHz to 44KHz downsampling of audio, to get rid of aliasing issues
--Use the capactor approach - i.e apply dQ/dT each instant, which is proportional to the difference between input voltage and current voltage
--Simpler than an FIR/IIR and the 2nd order performs well enough when simulated in Octave
--      distance = -level+val;
--       level = level + distance/16;

LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY simple_low_pass_filter IS
PORT 
( 
	CLK : IN STD_LOGIC;
	AUDIO_IN : IN STD_LOGIC_VECTOR(15 downto 0);
	SAMPLE_IN : IN STD_LOGIC; --1.8MHz
	AUDIO_OUT : OUT STD_LOGIC_VECTOR(15 downto 0) --Filtered to remove > 44KHz
);
END simple_low_pass_filter;

ARCHITECTURE vhdl OF simple_low_pass_filter IS
	signal accum_next  : std_logic_vector(20 downto 0);
	signal accum_reg  : std_logic_vector(20 downto 0) := (others=>'0');
	
	signal accum2_next  : std_logic_vector(20 downto 0);
	signal accum2_reg  : std_logic_vector(20 downto 0) := (others=>'0');
	
	signal adjust : signed(20 downto 0);
	signal adjust2 : signed(20 downto 0);
begin
	-- register
	process(clk)
	begin
		if (clk'event and clk='1') then						
			accum_reg <= accum_next;
			accum2_reg <= accum2_next;
		end if;
	end process;


	process(audio_in,accum_reg,sample_in,adjust)
	begin
		accum_next <= accum_reg;
		adjust <= resize(signed(audio_in&"0000"),21) - signed(accum_reg);

		if (sample_in = '1') then
			accum_next <= std_logic_vector(signed(accum_reg) + resize(adjust(20 downto 4),21)); --Add diff/16
		end if;
	end process;

	process(accum_reg ,accum2_reg,sample_in,adjust2)
	begin
		accum2_next <= accum2_reg;
		adjust2 <= signed(accum_reg) - signed(accum2_reg);

		if (sample_in = '1') then
			accum2_next <= std_logic_vector(signed(accum2_reg) + resize(adjust2(20 downto 3),21)); --Add diff/8
		end if;
	end process;

	audio_out <= accum2_reg(19 downto 4);

end vhdl;

