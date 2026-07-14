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
use IEEE.STD_LOGIC_MISC.all;

ENTITY SID_envelope_tapmatch IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

	DELAY_LFSR1 : IN STD_LOGIC_VECTOR(14 downto 0);
	DELAY_LFSR2 : IN STD_LOGIC_VECTOR(14 downto 0);
	DELAY_LFSR3 : IN STD_LOGIC_VECTOR(14 downto 0);

	TAPKEY1 : IN STD_LOGIC_VECTOR(3 downto 0);
	TAPKEY2 : IN STD_LOGIC_VECTOR(3 downto 0);
	TAPKEY3 : IN STD_LOGIC_VECTOR(3 downto 0);

	TAPMATCHES : OUT STD_LOGIC_VECTOR(2 downto 0)
);
END SID_envelope_tapmatch;

ARCHITECTURE vhdl OF SID_envelope_tapmatch IS
	signal tapmatches_reg : std_logic_vector(2 downto 0);
	signal tapmatches_next : std_logic_vector(2 downto 0);

	signal state_reg : std_logic_vector(1 downto 0);
	signal state_next : std_logic_vector(1 downto 0);

	signal delay_lfsr_sel : std_logic_vector(14 downto 0);
	signal tapkey_sel : std_logic_vector(3 downto 0);

	signal tapmatch : std_logic;
BEGIN
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			tapmatches_reg <= (others=>'0');
			state_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			tapmatches_reg <= tapmatches_next;
			state_reg <= state_next;
		end if;
	end process;

	process(
		tapkey1,tapkey2,tapkey3,
		delay_lfsr1,delay_lfsr2,delay_lfsr3,
		state_reg,
		tapmatches_reg,
		tapmatch
		)
	begin
		tapmatches_next <= tapmatches_reg;
		state_next <= state_reg;

		delay_lfsr_sel <= (others=>'0');
		tapkey_sel <= (others=>'0');

		case state_reg is
			when "00" =>
				state_next <= "01";
				tapmatches_next(0) <= tapmatch;
				delay_lfsr_sel <= delay_lfsr1;
				tapkey_sel <= tapkey1;
			when "01" =>
				state_next <= "10";
				tapmatches_next(1) <= tapmatch;
				delay_lfsr_sel <= delay_lfsr2;
				tapkey_sel <= tapkey2;
			when others =>
				state_next <= "00";
				tapmatches_next(2) <= tapmatch;
				delay_lfsr_sel <= delay_lfsr3;
				tapkey_sel <= tapkey3;
		end case;
	end process;

	process(tapkey_sel, delay_lfsr_sel)
		variable tomatch : std_logic_Vector(14 downto 0);
	begin
		tapmatch <= '0';
		tomatch := (others=>'0');

		case tapkey_sel is
		when "0000" =>
			tomatch := "111111100000000"; --8
		when "0001" =>
			tomatch := "000000000000110"; --31
		when "0010" =>
			tomatch := "000000000111100"; --62
		when "0011" =>
			tomatch := "000001100110000"; --94
		when "0100" => 
			tomatch := "010000011000000"; --148
		when "0101" =>
			tomatch := "110011101010101"; --219
		when "0110" =>
			tomatch := "011100000000000"; --266
		when "0111" =>
			tomatch := "101000000001110"; --312
		when "1000" => 
			tomatch := "001001000010010"; --391
		when "1001" =>
			tomatch := "000001000100010"; --976
		when "1010" =>
			tomatch := "001100001001000"; --1953
		when "1011" =>
			tomatch := "101100110111000"; --3125
		when "1100" =>
			tomatch := "011100001000000"; --3906
		when "1101" =>
			tomatch := "111011111100010"; --11719
		when "1110" =>
			tomatch := "111011000100101"; --19531
		when "1111" =>
			tomatch := "000101010010011"; --31250
		when others=>
		end case;

		
		if (tomatch = delay_lfsr_sel) then
			tapmatch <= '1';
		end if;
	end process;

	TAPMATCHES <= tapmatches_reg;
end vhdl;

