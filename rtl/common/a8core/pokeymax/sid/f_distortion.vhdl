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

ENTITY SID_f_distortion IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

	STATE : IN SIGNED(17 downto 8); -- Voltage of filter, which should not impact F
	F_RAW : IN UNSIGNED(12 downto 0); -- Wanted F, scaled to same units as voltage of filter
	F_DISTORTED : OUT UNSIGNED(12 downto 0) --Result F
);
END SID_f_distortion;

ARCHITECTURE vhdl OF SID_f_distortion IS
	signal y1 : unsigned(12 downto 0);
	signal y1_reg : unsigned(12 downto 0);
	signal y2 : unsigned(12 downto 0);
	signal ych : unsigned(12 downto 0);
	signal yadj_next : unsigned(25 downto 0);
	signal yadj_reg : unsigned(25 downto 0);
	signal ychpos : unsigned(12 downto 0);
	signal f_distorted_next : unsigned(12 downto 0);
	signal STATE_next : SIGNED(17 downto 8);
	signal STATE_reg : SIGNED(17 downto 8);
	signal F_RAW_next : UNSIGNED(12 downto 0);
	signal F_RAW_reg : UNSIGNED(12 downto 0);
begin
	-- register
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			y1_reg <= (others=>'0');
			yadj_reg <= (others=>'0');
			state_reg <= (others=>'0');
			f_raw_reg <= (others=>'0');
		elsif (clk'event and clk='1') then						
			y1_reg <= y1;
			yadj_reg <= yadj_next;
			state_reg <= state_next;
			f_raw_reg <= f_raw_next;
		end if;
	end process;

	state_next <= state;
	f_raw_next <= f_raw;

 	process (state_reg,f_raw_reg, y1, y2, ych, ychpos, y1_reg, yadj_reg)
		type LOOKUP_TYPE is array (0 to 38) of unsigned(12 downto 0);
		variable lookup : LOOKUP_TYPE;

		variable pos: unsigned(18 downto 5);
	begin
		-- assumption: /home/markw/fpga/svn/jsidplay2-code/jsidplay2/src/main/java/builder/resid/residfp/Filter6581.java
		pos := (others=>'0');
		if (state_reg(17)='0') then
			pos := unsigned('0'&state_reg(16 downto 8)&"000"&"0") + resize('0'&f_raw_reg,14);
		end if;
		if (pos(18 downto 12) > to_unsigned(37,6)) then
			pos(18) := '0';
			pos(17 downto 12) := to_unsigned(37,6);
			pos(11 downto 5) := (others=>'1');
		end if;

		-- replace with piecewise interp. Takes a mul unit but saves lookup space.
		lookup := (
		"0000001000100","0000001000101","0000001000110","0000001001000","0000001001011","0000001001111","0000001010110","0000001100000","0000001110000","0000010001000","0000010101011","0000011100000","0000100101111","0000110100001","0001001000101","0001100101001","0010001011000","0010111010111","0011110011010","0100110000111","0101101110011","0110100110111","0111010110110","0111111100110","1000011001001","1000101101110","1000111100001","1001000101111","1001001100100","1001010001000","1001010100000","1001010101111","1001010111010","1001011000001","1001011000101","1001011001000","1001011001010","1001011001011","1001011001100");

		ychpos <= resize(pos(11 downto 5)&"00000",13);
		y1 <= lookup(to_integer(pos(17 downto 12)));
		y2 <= lookup(to_integer(pos(17 downto 12))+1);

		ych <= y2-y1;

		yadj_next <= ych * ychpos;

		f_distorted_next <= y1_reg + resize(yadj_reg(25 downto 12),13);
        end process;

	-- output
	f_distorted <= f_distorted_next;
end vhdl;


