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
	
	PROFILE_ADDR : OUT std_logic_vector(5 downto 0);
	PROFILE_REQUEST : OUT std_logic;
	PROFILE_READY : IN std_logic;
	PROFILE_DATA : IN std_logic_vector(15 downto 0)
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

-- takes a few cycles for each channel
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

process(channel_state_reg,profile_ready,CHANNEL_DIRTY_REG,CHANNEL_CHANGED)
begin
	CHANNEL_STATE_NEXT <= CHANNEL_STATE_REG;
	CHANNEL_DIRTY_NEXT <= CHANNEL_DIRTY_REG or channel_changed;

	CHANNEL_MUX <= (others=>'0');
	PROFILE_REQUEST <= '0';

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
			PROFILE_REQUEST <= '1';
			CHANNEL_DIRTY_NEXT(0) <= not(profile_ready);
			if (profile_ready='1') then
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT1;
			end if;
		when CHANNEL_STATE_REQUEST1 =>
			CHANNEL_MUX <= "01";
			PROFILE_REQUEST <= '1';
			CHANNEL_DIRTY_NEXT(1) <= not(profile_ready);
			if (profile_ready='1') then
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT2;
			end if;
		when CHANNEL_STATE_REQUEST2 =>
			CHANNEL_MUX <= "10";
			PROFILE_REQUEST <= '1';
			CHANNEL_DIRTY_NEXT(2) <= not(profile_ready);
			if (profile_ready='1') then
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT3;
			end if;
		when CHANNEL_STATE_REQUEST3 =>
			CHANNEL_MUX <= "11";
			PROFILE_REQUEST <= '1';
			CHANNEL_DIRTY_NEXT(3) <= not(profile_ready);
			if (profile_ready='1') then
				CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT0;
			end if;
		when OTHERS =>
			CHANNEL_STATE_NEXT <= CHANNEL_STATE_WAIT0;
	end case;
end process;

-- mux input
PROCESS(
	CHANNEL_0,CHANNEL_1,CHANNEL_2,CHANNEL_3,
	CHANNEL_MUX
	)
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

-- mux output
PROCESS(
	PROFILE_DATA,
	PROFILE_READY,
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

	if (profile_ready='1') then
		case channel_mux is
		when "00" => -- 0
			VOLUME_OUT_0_NEXT <= unsigned(PROFILE_DATA);
		when "01" => -- 1
			VOLUME_OUT_1_NEXT <= unsigned(PROFILE_DATA);
		when "10" => -- 2
			VOLUME_OUT_2_NEXT <= unsigned(PROFILE_DATA);
		when others=>     -- 3
			VOLUME_OUT_3_NEXT <= unsigned(PROFILE_DATA);
		end case;
	end if;
END PROCESS;

-- output
	VOLUME_OUT_0 <= VOLUME_OUT_0_REG;
	VOLUME_OUT_1 <= VOLUME_OUT_1_REG;
	VOLUME_OUT_2 <= VOLUME_OUT_2_REG;
	VOLUME_OUT_3 <= VOLUME_OUT_3_REG;

	PROFILE_ADDR <= std_logic_vector(CHANNEL_SUM_OUT);
END vhdl;

