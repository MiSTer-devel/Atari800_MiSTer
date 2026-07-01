---------------------------------------------------------------------------
-- (c) 2014 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.all;

ENTITY pokey_mixer_simple IS
PORT 
( 
	CLK : IN STD_LOGIC;
	ENABLE_179 : IN STD_LOGIC;

	CHANNEL_0 : IN STD_LOGIC_VECTOR(3 downto 0);
	CHANNEL_1 : IN STD_LOGIC_VECTOR(3 downto 0);
	CHANNEL_2 : IN STD_LOGIC_VECTOR(3 downto 0);
	CHANNEL_3 : IN STD_LOGIC_VECTOR(3 downto 0);

	VOLUME_OUT_L : OUT STD_LOGIC_vector(15 downto 0);
	VOLUME_OUT_R : OUT STD_LOGIC_vector(15 downto 0)
);
END pokey_mixer_simple;

ARCHITECTURE vhdl OF pokey_mixer_simple IS

-- This comes from PokeyMax(4) implementation
function pokeyvolume(x: unsigned(5 downto 0)) return unsigned is
begin
	case x is
		when "000000" => return x"0022";
		when "000001" => return x"0993";
		when "000010" => return x"135E";
		when "000011" => return x"1D9A";
		when "000100" => return x"2842";
		when "000101" => return x"3345";
		when "000110" => return x"3E84";
		when "000111" => return x"49E0";
		when "001000" => return x"5538";
		when "001001" => return x"606E";
		when "001010" => return x"6B69";
		when "001011" => return x"7612";
		when "001100" => return x"805A";
		when "001101" => return x"8A34";
		when "001110" => return x"9399";
		when "001111" => return x"9C84";
		when "010000" => return x"A4F4";
		when "010001" => return x"ACEA";
		when "010010" => return x"B468";
		when "010011" => return x"BB70";
		when "010100" => return x"C207";
		when "010101" => return x"C830";
		when "010110" => return x"CDEE";
		when "010111" => return x"D343";
		when "011000" => return x"D833";
		when "011001" => return x"DCC0";
		when "011010" => return x"E0EB";
		when "011011" => return x"E4B6";
		when "011100" => return x"E824";
		when "011101" => return x"EB36";
		when "011110" => return x"EDEF";
		when "011111" => return x"F053";
		when "100000" => return x"F265";
		when "100001" => return x"F42B";
		when "100010" => return x"F5AB";
		when "100011" => return x"F6E9";
		when "100100" => return x"F7EF";
		when "100101" => return x"F8C3";
		when "100110" => return x"F96D";
		when "100111" => return x"F9F4";
		when "101000" => return x"FA61";
		when "101001" => return x"FABB";
		when "101010" => return x"FB07";
		when "101011" => return x"FB4C";
		when "101100" => return x"FB8D";
		when "101101" => return x"FBCE";
		when "101110" => return x"FC11";
		when "101111" => return x"FC56";
		when "110000" => return x"FC9F";
		when "110001" => return x"FCEA";
		when "110010" => return x"FD37";
		when "110011" => return x"FD85";
		when "110100" => return x"FDD5";
		when "110101" => return x"FE28";
		when "110110" => return x"FE82";
		when "110111" => return x"FEE7";
		when "111000" => return x"FF5D";
		when "111001" => return x"FFEB";
		when others => return x"FFFF";
	end case;
end pokeyvolume;

signal VOLUME_OUT_L_NEXT : unsigned(15 downto 0);
signal VOLUME_OUT_L_REG : unsigned(15 downto 0);

signal VL : STD_LOGIC_VECTOR(15 downto 0);
signal VLS : STD_LOGIC_VECTOR(15 downto 0);

BEGIN

process(clk)
begin
	if rising_edge(clk) then
		VOLUME_OUT_L_REG <= VOLUME_OUT_L_NEXT;
	END IF;
END PROCESS;

process (channel_0,channel_1,channel_2,channel_3)
	variable channel0_long : unsigned(5 downto 0);
	variable channel1_long : unsigned(5 downto 0);
	variable channel2_long : unsigned(5 downto 0);
	variable channel3_long : unsigned(5 downto 0);
begin
	channel0_long := (others=>'0');
	channel1_long := (others=>'0');
	channel2_long := (others=>'0');
	channel3_long := (others=>'0');

	channel0_long(3 downto 0) := unsigned(channel_0);
	channel1_long(3 downto 0) := unsigned(channel_1);
	channel2_long(3 downto 0) := unsigned(channel_2);
	channel3_long(3 downto 0) := unsigned(channel_3);

	VOLUME_OUT_L_NEXT <= pokeyvolume((channel0_long + channel1_long) + (channel2_long + channel3_long));
end process;

-- low pass filter output
filter_left : entity work.simple_low_pass_filter
	port map (CLK => CLK,AUDIO_IN => VOLUME_OUT_L_REG,SAMPLE_IN => ENABLE_179,AUDIO_OUT => VL);

	-- Post divide 8, should be equivalent to the default PokeyMax settings...
	VLS <= not(VL(15))&not(VL(15))&not(VL(15))&not(VL(15))&VL(14 downto 3);

	-- output, full mono here
	VOLUME_OUT_L <= VLS;
	VOLUME_OUT_R <= VLS;

END vhdl;

