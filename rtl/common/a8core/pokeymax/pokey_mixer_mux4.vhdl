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

ENTITY pokey_mixer_mux4 IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

	CHANNEL_0 : IN unsigned(5 downto 0);
	CHANNEL_1 : IN unsigned(5 downto 0);
	CHANNEL_2 : IN unsigned(5 downto 0);
	CHANNEL_3 : IN unsigned(5 downto 0);
	
	VOLUME_OUT_0 : OUT unsigned(15 downto 0);
	VOLUME_OUT_1 : OUT unsigned(15 downto 0);
	VOLUME_OUT_2 : OUT unsigned(15 downto 0);
	VOLUME_OUT_3 : OUT unsigned(15 downto 0);

	SATURATE : IN STD_LOGIC
	
);
END pokey_mixer_mux4;

ARCHITECTURE vhdl OF pokey_mixer_mux4 IS

signal CHANNEL_STATE_NEXT : STD_LOGIC_VECTOR(2 downto 0);
signal CHANNEL_STATE_REG : STD_LOGIC_VECTOR(2 downto 0);
constant CHANNEL_STATE_WAIT0 : STD_LOGIC_VECTOR(2 downto 0) := "000";
constant CHANNEL_STATE_WAIT1 : STD_LOGIC_VECTOR(2 downto 0) := "001";
constant CHANNEL_STATE_WAIT2 : STD_LOGIC_VECTOR(2 downto 0) := "010";
constant CHANNEL_STATE_WAIT3 : STD_LOGIC_VECTOR(2 downto 0) := "011";
constant CHANNEL_STATE_REQUEST0 : STD_LOGIC_VECTOR(2 downto 0) := "100";
constant CHANNEL_STATE_REQUEST1 : STD_LOGIC_VECTOR(2 downto 0) := "101";
constant CHANNEL_STATE_REQUEST2 : STD_LOGIC_VECTOR(2 downto 0) := "110";
constant CHANNEL_STATE_REQUEST3 : STD_LOGIC_VECTOR(2 downto 0) := "111";

signal CHANNEL_DIRTY_NEXT : STD_LOGIC_VECTOR(3 downto 0);
signal CHANNEL_DIRTY_REG : STD_LOGIC_VECTOR(3 downto 0);
signal CHANNEL_CHANGED : STD_LOGIC_VECTOR(3 downto 0);

signal CHANNEL_IN_0_NEXT : unsigned(5 downto 0);
signal CHANNEL_IN_0_REG : unsigned(5 downto 0);
signal CHANNEL_IN_1_NEXT : unsigned(5 downto 0);
signal CHANNEL_IN_1_REG : unsigned(5 downto 0);
signal CHANNEL_IN_2_NEXT : unsigned(5 downto 0);
signal CHANNEL_IN_2_REG : unsigned(5 downto 0);
signal CHANNEL_IN_3_NEXT : unsigned(5 downto 0);
signal CHANNEL_IN_3_REG : unsigned(5 downto 0);

signal VOLUME_OUT_0_NEXT : unsigned(15 downto 0);
signal VOLUME_OUT_0_REG : unsigned(15 downto 0);
signal VOLUME_OUT_1_NEXT : unsigned(15 downto 0);
signal VOLUME_OUT_1_REG : unsigned(15 downto 0);
signal VOLUME_OUT_2_NEXT : unsigned(15 downto 0);
signal VOLUME_OUT_2_REG : unsigned(15 downto 0);
signal VOLUME_OUT_3_NEXT : unsigned(15 downto 0);
signal VOLUME_OUT_3_REG : unsigned(15 downto 0);

signal CHANNEL_MUX : STD_LOGIC_VECTOR(1 downto 0);
signal CHANNEL_SUM_OUT : unsigned(5 downto 0);
signal VOLUME_CURVE : unsigned(15 downto 0);

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

BEGIN

process(clk,reset_n)
begin
	if (reset_n='0') then
		CHANNEL_STATE_REG <= CHANNEL_STATE_WAIT0;
		CHANNEL_DIRTY_REG <= (others=>'1');

		CHANNEL_IN_0_REG <= (others=>'0');
		CHANNEL_IN_1_REG <= (others=>'0');
		CHANNEL_IN_2_REG <= (others=>'0');
		CHANNEL_IN_3_REG <= (others=>'0');

		VOLUME_OUT_0_REG <= (others=>'0');
		VOLUME_OUT_1_REG <= (others=>'0');
		VOLUME_OUT_2_REG <= (others=>'0');
		VOLUME_OUT_3_REG <= (others=>'0');
	elsif (clk'event and clk='1') then
		CHANNEL_STATE_REG <= CHANNEL_STATE_NEXT;
		CHANNEL_DIRTY_REG <= CHANNEL_DIRTY_NEXT;

		CHANNEL_IN_0_REG <= CHANNEL_IN_0_NEXT;
		CHANNEL_IN_1_REG <= CHANNEL_IN_1_NEXT;
		CHANNEL_IN_2_REG <= CHANNEL_IN_2_NEXT;
		CHANNEL_IN_3_REG <= CHANNEL_IN_3_NEXT;

		VOLUME_OUT_0_REG <= VOLUME_OUT_0_NEXT;
		VOLUME_OUT_1_REG <= VOLUME_OUT_1_NEXT;
		VOLUME_OUT_2_REG <= VOLUME_OUT_2_NEXT;
		VOLUME_OUT_3_REG <= VOLUME_OUT_3_NEXT;
	END IF;
END PROCESS;

process(
	CHANNEL_IN_0_REG,CHANNEL_IN_1_REG,CHANNEL_IN_2_REG,CHANNEL_IN_3_REG,
	CHANNEL_0,CHANNEL_1,CHANNEL_2,CHANNEL_3
)
begin
	CHANNEL_IN_0_NEXT <= CHANNEL_0;
	CHANNEL_IN_1_NEXT <= CHANNEL_1;
	CHANNEL_IN_2_NEXT <= CHANNEL_2;
	CHANNEL_IN_3_NEXT <= CHANNEL_3;

	CHANNEL_CHANGED(0) <= '0';
	if (CHANNEL_0 /= CHANNEL_IN_0_REG) then
		CHANNEL_CHANGED(0) <= '1';
	end if;
	CHANNEL_CHANGED(1) <= '0';
	if (CHANNEL_1 /= CHANNEL_IN_1_REG) then
		CHANNEL_CHANGED(1) <= '1';
	end if;
	CHANNEL_CHANGED(2) <= '0';
	if (CHANNEL_2 /= CHANNEL_IN_2_REG) then
		CHANNEL_CHANGED(2) <= '1';
	end if;
	CHANNEL_CHANGED(3) <= '0';
	if (CHANNEL_3 /= CHANNEL_IN_3_REG) then
		CHANNEL_CHANGED(3) <= '1';
	end if;
end process;

process(channel_state_reg,CHANNEL_DIRTY_REG,CHANNEL_CHANGED)
begin
	CHANNEL_STATE_NEXT <= CHANNEL_STATE_REG;
	CHANNEL_DIRTY_NEXT <= CHANNEL_DIRTY_REG or channel_changed;

	CHANNEL_MUX <= (others=>'0');

	case CHANNEL_STATE_REG is 
		when CHANNEL_STATE_WAIT0 =>
			if (CHANNEL_DIRTY_REG(0)='1') then
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_REQUEST0;
			else
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT1;
			end if;
		when CHANNEL_STATE_WAIT1 =>
			if (CHANNEL_DIRTY_REG(1)='1') then
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_REQUEST1;
			else
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT2;
			end if;
		when CHANNEL_STATE_WAIT2 =>
			if (CHANNEL_DIRTY_REG(2)='1') then
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_REQUEST2;
			else
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT3;
			end if;
		when CHANNEL_STATE_WAIT3 =>
			if (CHANNEL_DIRTY_REG(3)='1') then
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_REQUEST3;
			else
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT0;
			end if;
		when CHANNEL_STATE_REQUEST0 =>
			CHANNEL_MUX <= "00";
			CHANNEL_DIRTY_NEXT(0) <= '0';
			CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT1;
		when CHANNEL_STATE_REQUEST1 =>
			CHANNEL_MUX <= "01";
			CHANNEL_DIRTY_NEXT(1) <= '0';
			CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT2;
		when CHANNEL_STATE_REQUEST2 =>
			CHANNEL_MUX <= "10";
			CHANNEL_DIRTY_NEXT(2) <= '0';
			CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT3;
		when CHANNEL_STATE_REQUEST3 =>
			CHANNEL_MUX <= "11";
			CHANNEL_DIRTY_NEXT(3) <= '0';
			CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT0;
		when OTHERS =>
			CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT0;
	end case;
end process;

-- mux input
PROCESS(CHANNEL_0,CHANNEL_1,CHANNEL_2,CHANNEL_3,CHANNEL_MUX)	
	variable channel_sum : unsigned(5 downto 0);
BEGIN
	channel_sum := (OTHERS=>'0');

	case channel_mux is
	when "00" => -- 0
	     	channel_sum := CHANNEL_0;
	when "01" => -- 1
	     	channel_sum := CHANNEL_1;
	when "10" => -- 2
		channel_sum := CHANNEL_2;
   --when "0000001" => -- 3
	when others =>
		channel_sum := CHANNEL_3;
	end case;
	
	channel_sum_out <= channel_sum;

END PROCESS;

VOLUME_CURVE <= pokeyvolume(CHANNEL_SUM_OUT) when saturate = '0' else CHANNEL_SUM_OUT&"0000000000";

-- mux output
PROCESS(
	VOLUME_CURVE,
	VOLUME_OUT_0_REG,
	VOLUME_OUT_1_REG,
	VOLUME_OUT_2_REG,
	VOLUME_OUT_3_REG,
	CHANNEL_MUX
)
BEGIN
	VOLUME_OUT_0_NEXT <= VOLUME_OUT_0_REG;
	VOLUME_OUT_1_NEXT <= VOLUME_OUT_1_REG;
	VOLUME_OUT_2_NEXT <= VOLUME_OUT_2_REG;
	VOLUME_OUT_3_NEXT <= VOLUME_OUT_3_REG;

	case channel_mux is
	when "00" => -- 0
		VOLUME_OUT_0_NEXT <= VOLUME_CURVE;
	when "01" => -- 1
		VOLUME_OUT_1_NEXT <= VOLUME_CURVE;
	when "10" => -- 2
		VOLUME_OUT_2_NEXT <= VOLUME_CURVE;
	when others=>     -- 3
		VOLUME_OUT_3_NEXT <= VOLUME_CURVE;		
	end case;
END PROCESS;

-- output
VOLUME_OUT_0 <= VOLUME_OUT_0_REG;
VOLUME_OUT_1 <= VOLUME_OUT_1_REG;
VOLUME_OUT_2 <= VOLUME_OUT_2_REG;
VOLUME_OUT_3 <= VOLUME_OUT_3_REG;

END vhdl;

