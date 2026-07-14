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

ENTITY SID_amplitudeModulator IS
PORT 
( 
	WAVE_A : IN STD_LOGIC_VECTOR(11 downto 0);
	ENVELOPE_A : IN STD_LOGIC_VECTOR(7 downto 0);
	WAVE_B : IN STD_LOGIC_VECTOR(11 downto 0);
	ENVELOPE_B : IN STD_LOGIC_VECTOR(7 downto 0);
	WAVE_C : IN STD_LOGIC_VECTOR(11 downto 0);
	ENVELOPE_C : IN STD_LOGIC_VECTOR(7 downto 0);
	CHANNEL_D : IN SIGNED(15 downto 0);

	CHANNEL_MUX_SEL : IN STD_LOGIC_VECTOR(2 downto 0);
	
	MODULATED : OUT SIGNED(15 downto 0)
);
END SID_amplitudeModulator;

ARCHITECTURE vhdl OF SID_amplitudeModulator IS
	signal WAVE : STD_LOGIC_VECTOR(11 downto 0);
	signal ENVELOPE : STD_LOGIC_VECTOR(7 downto 0);
	signal CHANNEL_ABC : SIGNED(15 downto 0);
BEGIN
        process(
		wave_a,envelope_a,wave_b,envelope_b,wave_c,envelope_c,
		channel_d,
		channel_mux_sel,
		channel_abc)
	begin
		MODULATED <= (others=>'0');
		envelope <= (others=>'0');
		wave <= (others=>'0');
		case channel_mux_sel is
		when "001" =>
			wave <= wave_a;
			envelope <= envelope_a;
			MODULATED <= channel_abc;
		when "010" =>
			wave <= wave_b;
			envelope <= envelope_b;
			MODULATED <= channel_abc;
		when "011" =>
			wave <= wave_c;
			envelope <= envelope_c;
			MODULATED <= channel_abc;
		when "100" =>
			MODULATED <= channel_d;
		when others =>
		end case;
	end process;

	process(wave,envelope)
		variable multres : signed(26 downto 0);
	begin
		multres := signed("0"&envelope)*(signed(resize(unsigned(wave),18))-2048);
		channel_abc <= multres(19 downto 4);
	end process;	
		
END vhdl;
