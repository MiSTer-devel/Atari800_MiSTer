---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.all;

ENTITY pokey_mixer IS
PORT 
( 
	CLK : IN STD_LOGIC;

	CHANNEL_0 : IN STD_LOGIC_VECTOR(3 downto 0);
	CHANNEL_1 : IN STD_LOGIC_VECTOR(3 downto 0);
	CHANNEL_2 : IN STD_LOGIC_VECTOR(3 downto 0);
	CHANNEL_3 : IN STD_LOGIC_VECTOR(3 downto 0);
	
	GTIA_SOUND : IN STD_LOGIC;
	SIO_AUDIO : IN STD_LOGIC_VECTOR(7 downto 0);

	COVOX_CHANNEL_0 : IN STD_LOGIC_VECTOR(7 downto 0);
	COVOX_CHANNEL_1 : IN STD_LOGIC_VECTOR(7 downto 0);
	
	VOLUME_OUT_NEXT : OUT STD_LOGIC_vector(15 downto 0)
);
END pokey_mixer;

ARCHITECTURE vhdl OF pokey_mixer IS

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

signal volume_sum_next : std_logic_vector(15 downto 0);
signal volume_sum_reg : std_logic_vector(15 downto 0);

BEGIN

process(clk)
begin
	if (clk'event and clk='1') then
		VOLUME_SUM_REG <= VOLUME_SUM_NEXT;
	END IF;
END PROCESS;

	-- next state
	process (channel_0,channel_1,channel_2,channel_3,covox_CHANNEL_0,covox_channel_1,gtia_sound,sio_audio)
		variable channel0_en_long : unsigned(5 downto 0);
		variable channel1_en_long : unsigned(5 downto 0);
		variable channel2_en_long : unsigned(5 downto 0);
		variable channel3_en_long : unsigned(5 downto 0);
		variable channels_long : unsigned(16 downto 0);
		variable gtia_sound_long : unsigned(16 downto 0);
		variable sio_audio_long : unsigned(16 downto 0);
		variable covox_0_long : unsigned(16 downto 0);
		variable covox_1_long : unsigned(16 downto 0);
		
		variable volume_int_sum : unsigned(16 downto 0);
	begin
		channel0_en_long := (others=>'0');
		channel1_en_long := (others=>'0');
		channel2_en_long := (others=>'0');
		channel3_en_long := (others=>'0');
		-- Bits 14 downto 0 can also be filled in with gtia_sound
		-- without harm to amplify GTIA sound further
		gtia_sound_long := (15 => gtia_sound, others=>'0');

		channel0_en_long(3 downto 0) := unsigned(channel_0);
		channel1_en_long(3 downto 0) := unsigned(channel_1);
		channel2_en_long(3 downto 0) := unsigned(channel_2);
		channel3_en_long(3 downto 0) := unsigned(channel_3);

		channels_long := "0" & pokeyvolume((channel0_en_long + channel1_en_long) + (channel2_en_long + channel3_en_long));
		sio_audio_long := unsigned("0" & sio_audio & sio_audio);
		covox_0_long := unsigned("0" & covox_channel_0 & covox_channel_0);
		covox_1_long := unsigned("0" & covox_channel_1 & covox_channel_1);

		volume_int_sum := channels_long + ((gtia_sound_long + sio_audio_long) + (covox_0_long + covox_1_long));

		-- Alternatively remove - X"8000" and make the MiSTer audio unsigned (top 800 & 5200 .sv files)
		volume_sum_next <= std_logic_vector(volume_int_sum(16 downto 1) - X"8000");
		
	end process;
	

	-- output
	volume_out_next <= volume_sum_reg; 

END vhdl;
