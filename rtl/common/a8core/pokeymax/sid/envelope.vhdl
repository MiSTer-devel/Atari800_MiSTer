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

ENTITY SID_envelope IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	ENABLE : IN STD_LOGIC;

	TAPMATCH : IN STD_LOGIC;

	ATTACK : IN STD_LOGIC_VECTOR(3 downto 0);
	SUSTAIN : IN STD_LOGIC_VECTOR(3 downto 0);
	DECAY : IN STD_LOGIC_VECTOR(3 downto 0);
	RELEASE_IN : IN STD_LOGIC_VECTOR(3 downto 0);

	GATE : IN STD_LOGIC;
	
	ENVELOPE : OUT STD_LOGIC_VECTOR(7 downto 0);

	delay_lfsr : OUT std_logic_vector(14 downto 0);
	tapkey : OUT std_logic_vector(3 downto 0)
);
END SID_envelope;

ARCHITECTURE vhdl OF SID_envelope IS
	signal envelope_reg: unsigned(7 downto 0);
	signal envelope_next:unsigned(7 downto 0);

	signal delay_lfsr_reg : std_logic_vector(14 downto 0);
	signal delay_lfsr_next : std_logic_vector(14 downto 0);

	signal expdelay_lfsr_reg : std_logic_vector(4 downto 0);
	signal expdelay_lfsr_next : std_logic_vector(4 downto 0);

	signal exptapmatch_reg : std_logic_vector(2 downto 0);
	signal exptapmatch_next : std_logic_vector(2 downto 0);

	signal tapkey_next : std_logic_vector(3 downto 0);
	signal tapkey_reg : std_logic_vector(3 downto 0);
	signal tapkey_del1_next : std_logic_vector(3 downto 0);
	signal tapkey_del1_reg : std_logic_vector(3 downto 0);
	signal tapkey_del2_next : std_logic_vector(3 downto 0);
	signal tapkey_del2_reg : std_logic_vector(3 downto 0);
	signal tapkey_del3_next : std_logic_vector(3 downto 0);
	signal tapkey_del3_reg : std_logic_vector(3 downto 0);

	signal exptap : std_logic_vector(2 downto 0);
	signal exptapmatching : std_logic;

	signal state_reg : std_logic_vector(1 downto 0);
	signal state_next : std_logic_vector(1 downto 0);
	constant state_attack : std_logic_vector(1 downto 0) := "00";
	constant state_decay : std_logic_vector(1 downto 0) := "10";
	constant state_release : std_logic_vector(1 downto 0) := "11";

	signal count_state_reg : std_logic_vector(1 downto 0);
	signal count_state_next : std_logic_vector(1 downto 0);
	constant count_state_up : std_logic_vector(1 downto 0) := "00";
	constant count_state_down : std_logic_vector(1 downto 0) := "10";
	constant count_state_stopped : std_logic_vector(1 downto 0) := "11";

	signal gate_changed : std_logic;
	signal hold_counter : std_logic;

	signal gatedel : std_logic;
	signal gateshift_reg : std_logic_vector(1 downto 0);
	signal gateshift_next : std_logic_vector(1 downto 0);

	signal r0_next : std_logic;
	signal r0_reg : std_logic;

	signal adrmux_next : std_logic_vector(1 downto 0);
	signal adrmux_reg : std_logic_vector(1 downto 0);
	signal adrmux_del1_next : std_logic_vector(1 downto 0);
	signal adrmux_del1_reg : std_logic_vector(1 downto 0);
	signal adrmux_del2_next : std_logic_vector(1 downto 0);
	signal adrmux_del2_reg : std_logic_vector(1 downto 0);

	signal attack_del1_reg : std_logic_vector(3 downto 0);
	signal attack_del2_reg : std_logic_vector(3 downto 0);
	signal attack_del3_reg : std_logic_vector(3 downto 0);
	signal attack_del1_next : std_logic_vector(3 downto 0);
	signal attack_del2_next : std_logic_vector(3 downto 0);
	signal attack_del3_next : std_logic_vector(3 downto 0);
	signal attack_delayed : std_logic_vector(3 downto 0);

	signal decay_del1_reg : std_logic_vector(3 downto 0);
	signal decay_del2_reg : std_logic_vector(3 downto 0);
	signal decay_del3_reg : std_logic_vector(3 downto 0);
	signal decay_del1_next : std_logic_vector(3 downto 0);
	signal decay_del2_next : std_logic_vector(3 downto 0);
	signal decay_del3_next : std_logic_vector(3 downto 0);
	signal decay_delayed : std_logic_vector(3 downto 0);

	signal release_del1_reg : std_logic_vector(3 downto 0);
	signal release_del2_reg : std_logic_vector(3 downto 0);
	signal release_del3_reg : std_logic_vector(3 downto 0);
	signal release_del1_next : std_logic_vector(3 downto 0);
	signal release_del2_next : std_logic_vector(3 downto 0);
	signal release_del3_next : std_logic_vector(3 downto 0);
	signal release_delayed : std_logic_vector(3 downto 0);

	signal sustain_del1_reg : std_logic_vector(3 downto 0);
	signal sustain_del2_reg : std_logic_vector(3 downto 0);
	signal sustain_del3_reg : std_logic_vector(3 downto 0);
	signal sustain_del1_next : std_logic_vector(3 downto 0);
	signal sustain_del2_next : std_logic_vector(3 downto 0);
	signal sustain_del3_next : std_logic_vector(3 downto 0);
	signal sustain_delayed : std_logic_vector(3 downto 0);

BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			envelope_reg <= (others=>'0');
			delay_lfsr_reg <= (others=>'1');
			expdelay_lfsr_reg <= (others=>'1');
			exptapmatch_reg <= (others=>'0');
			state_reg <= state_release;
			count_state_reg <= count_state_stopped;
			tapkey_reg <= (others=>'0');
			tapkey_del1_reg <= (others=>'0');
			tapkey_del2_reg <= (others=>'0');
			tapkey_del3_reg <= (others=>'0');
			gateshift_reg <= (others=>'0');
			r0_reg <= '0';
			adrmux_reg <= (others=>'0');
			adrmux_del1_reg <= (others=>'0');
			adrmux_del2_reg <= (others=>'0');

			attack_del1_reg <= (others=>'0');
			attack_del2_reg <= (others=>'0');
			attack_del3_reg <= (others=>'0');

			decay_del1_reg <= (others=>'0');
			decay_del2_reg <= (others=>'0');
			decay_del3_reg <= (others=>'0');

			release_del1_reg <= (others=>'0');
			release_del2_reg <= (others=>'0');
			release_del3_reg <= (others=>'0');

			sustain_del1_reg <= (others=>'0');
			sustain_del2_reg <= (others=>'0');
			sustain_del3_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			envelope_reg <= envelope_next;
			delay_lfsr_reg <= delay_lfsr_next;
			expdelay_lfsr_reg <= expdelay_lfsr_next;
			exptapmatch_reg <= exptapmatch_next;
			state_reg <= state_next;
			count_state_reg <= count_state_next;
			tapkey_reg <= tapkey_next;
			tapkey_del1_reg <= tapkey_del1_next;
			tapkey_del2_reg <= tapkey_del2_next;
			tapkey_del3_reg <= tapkey_del3_next;
			gateshift_reg <= gateshift_next;
			r0_reg <= r0_next;
			adrmux_reg <= adrmux_next;
			adrmux_del1_reg <= adrmux_del1_next;
			adrmux_del2_reg <= adrmux_del2_next;

			attack_del1_reg <= attack_del1_next;
			attack_del2_reg <= attack_del2_next;
			attack_del3_reg <= attack_del3_next;

			decay_del1_reg <= decay_del1_next;
			decay_del2_reg <= decay_del2_next;
			decay_del3_reg <= decay_del3_next;

			release_del1_reg <= release_del1_next;
			release_del2_reg <= release_del2_next;
			release_del3_reg <= release_del3_next;

			sustain_del1_reg <= sustain_del1_next;
			sustain_del2_reg <= sustain_del2_next;
			sustain_del3_reg <= sustain_del3_next;
		end if;
	end process;

	process(gateshift_reg,gate,enable)
	begin
		gateshift_next <= gateshift_reg;
		if (enable='1') then
			gateshift_next(1) <= gate;
			gateshift_next(0) <= gateshift_reg(1);
		end if;
	end process;
	gatedel <= gateshift_reg(0);

	process(attack_del1_reg,attack_del2_reg,attack_del3_reg,attack,enable)
	begin
		attack_del1_next <= attack_del1_reg;
		attack_del2_next <= attack_del2_reg;
		attack_del3_next <= attack_del3_reg;
		if (enable='1') then
			attack_del1_next <= attack;
			attack_del2_next <= attack_del1_reg;
			attack_del3_next <= attack_del2_reg;
		end if;
	end process;
	attack_delayed <= attack_del3_reg;

	process(decay_del1_reg,decay_del2_reg,decay_del3_reg,decay,enable)
	begin
		decay_del1_next <= decay_del1_reg;
		decay_del2_next <= decay_del2_reg;
		decay_del3_next <= decay_del3_reg;
		if (enable='1') then
			decay_del1_next <= decay;
			decay_del2_next <= decay_del1_reg;
			decay_del3_next <= decay_del2_reg;
		end if;
	end process;
	decay_delayed <= decay_del3_reg;

	process(release_del1_reg,release_del2_reg,release_del3_reg,release_in,enable)
	begin
		release_del1_next <= release_del1_reg;
		release_del2_next <= release_del2_reg;
		release_del3_next <= release_del3_reg;
		if (enable='1') then
			release_del1_next <= release_in;
			release_del2_next <= release_del1_reg;
			release_del3_next <= release_del2_reg;
		end if;
	end process;
	release_delayed <= release_del3_reg;

	process(sustain_del1_reg,sustain_del2_reg,sustain_del3_reg,sustain,enable)
	begin
		sustain_del1_next <= sustain_del1_reg;
		sustain_del2_next <= sustain_del2_reg;
		sustain_del3_next <= sustain_del3_reg;
		if (enable='1') then
			sustain_del1_next <= sustain;
			sustain_del2_next <= sustain_del1_reg;
			sustain_del3_next <= sustain_del2_reg;
		end if;
	end process;
	sustain_delayed <= sustain_del2_reg;

	-- next state
	--VALUE  	ATTACK RATE	DECAY/RELEASE RATE
	--	Time/Cycle	Time/Cycle
	--- ------------------------------------------
	-- 0	  2 ms		  6 ms
	-- 1	  8 ms		 24 ms
	-- 2	 16 ms		 48 ms
	-- 3	 24 ms		 72 ms
	-- 4	 38 ms		114 ms
	-- 5	 56 ms		168 ms
	-- 6	 68 ms		204 ms
	-- 7	 80 ms		240 ms
	-- 8	100 ms		300 ms
	-- 9	240 ms		750 ms
	--10	500 ms		1.5 s
	--11	800 ms		2.4 s
	--12	  1 s		  3 s
	--13	  3 s		  9 s
	--14	  5 s		 15 s
	--15	  8 s		 24 s
	--
	--
	--
	--ref1: https://www.codebase64.org/doku.php?id=base:classic_hard-restart_and_about_adsr_in_generally
	--ref2: https://sourceforge.net/p/sidplay-residfp/wiki/SID%20internals%20-%20Envelope%20Overview/
	-- up:linear, down: exponential approx
	process(envelope_reg,enable,tapmatch,count_state_reg,exptapmatch_reg,exptap,exptapmatching,gatedel,gate_changed,hold_counter,r0_reg)
		variable no_delay : std_logic;
		variable delay_match : std_logic;
	begin
		count_state_next <= count_state_reg;
		envelope_next <= envelope_reg;
		exptapmatch_next <= exptapmatch_reg;

		exptapmatching <= '0';

		r0_next <= r0_reg;

		if (enable='1') then
			no_delay := nor_reduce(exptapmatch_reg);
			delay_match := '0';
			if (exptapmatch_reg = exptap) then
				delay_match := '1';
			end if;
			case count_state_reg is
				when count_state_up =>
					r0_next <= '1';
					if (exptapmatching='1') then -- and hold_counter='0') then
						envelope_next <= envelope_reg+1;
						if (envelope_reg=x"fe") then
							count_state_next <= count_state_down;
						end if;
					end if;
				when count_state_down =>
					r0_next <= '0';
					if (exptapmatching='1' and hold_counter='0') then
						envelope_next <= envelope_reg-1;
						if (envelope_reg=x"01") then
							count_state_next <= count_state_stopped;
						end if;
					end if;
				when others=>
			end case;

			exptapmatching <= (tapmatch and (no_delay or r0_reg)) or (delay_match and not(no_delay));

			if (gate_changed='1') then
				if (gatedel='1') then
					count_state_next <= count_state_up;
				else
					count_state_next <= count_state_down;
				end if;
			end if;

			case envelope_reg is
				when x"00" =>
					exptapmatch_next  <= "000";
				when x"06" =>
					exptapmatch_next  <= "101";
				when x"0e" =>
					exptapmatch_next  <= "100";
				when x"1a" =>
					exptapmatch_next  <= "011";
				when x"36" =>
					exptapmatch_next  <= "010";
				when x"5d" =>
					exptapmatch_next  <= "001";
				when x"ff" => 
					exptapmatch_next  <= "000";
				when others =>
			end case;
		end if;
	end process;

	process(
		enable,
		tapkey_reg,tapkey_del1_reg,tapkey_del2_reg,tapkey_del3_reg,
		attack_delayed,decay_delayed,release_delayed,
		adrmux_reg
	)
	begin
		tapkey_next <= tapkey_reg;
		tapkey_del1_next <= tapkey_del1_reg;
		tapkey_del2_next <= tapkey_del2_reg;
		tapkey_del3_next <= tapkey_del3_reg;
		if (enable='1') then
			tapkey_del1_next <= tapkey_reg;
			tapkey_del2_next <= tapkey_del1_reg;
			tapkey_del3_next <= tapkey_del2_reg;
			case adrmux_reg is
			when "00" =>
				tapkey_next <= attack_delayed;
			when "01" =>
				tapkey_next <= decay_delayed;
			when "10" =>
				tapkey_next <= release_delayed;
			when others =>
				tapkey_next <= (others=>'0');
			end case;
		end if;
	end process;

	process(enable,state_reg,envelope_reg,gatedel,tapmatch,sustain_delayed,adrmux_reg,adrmux_del1_reg,adrmux_del2_reg)
		variable envelope_over_sustain : std_logic;
	begin
		state_next <= state_reg;
		gate_changed <= '0';
		hold_counter <= '0';

		adrmux_next <= adrmux_reg;
		adrmux_del1_next <= adrmux_del1_reg;
		adrmux_del2_next <= adrmux_del2_reg;

		envelope_over_sustain := '0';
		if (unsigned(envelope_reg) > unsigned(sustain_delayed&sustain_delayed)) then
			envelope_over_sustain := '1';
		end if;

		if (enable='1') then
			adrmux_del1_next <= adrmux_reg;
			adrmux_del2_next <= adrmux_del1_reg;
			case state_reg is
				when state_attack =>
					adrmux_next <= "00";
					if (and_reduce(std_logic_vector(envelope_reg))='1') then
						state_next <= state_decay;
					end if;
					if (gatedel='0') then
						state_next <= state_release;
						--state_next <= state_decay;
						gate_changed <= '1';
					end if;
				when state_decay =>
					adrmux_next <= "01";
					if (envelope_over_sustain='0') then
						hold_counter <= '1';
					end if;
					if (gatedel='0') then
						state_next <= state_release;
						gate_changed <= '1';
					end if;
				when state_release =>
					adrmux_next <= "10";
					if (gatedel='1') then
						adrmux_next <= "01";
						state_next <= state_attack;
						gate_changed <= '1';
					end if;
				when others=>
					state_next <= state_release;
			end case;
		end if;
	end process;

	process(delay_lfsr_reg,tapmatch,enable)
	begin
		delay_lfsr_next <= delay_lfsr_reg;
		if (enable='1') then
			if (tapmatch='1') then
				delay_lfsr_next <= (others=>'1');
			else
				delay_lfsr_next(0) <= delay_lfsr_reg(14) xor delay_lfsr_reg(13);
				delay_lfsr_next(14 downto 1) <= delay_lfsr_reg(13 downto 0);
			end if;
		end if;
	end process;

	process(expdelay_lfsr_reg,exptapmatching,tapmatch,enable)
	begin
		expdelay_lfsr_next <= expdelay_lfsr_reg;
		if (enable='1') then
			if (exptapmatching='1') then
				expdelay_lfsr_next <= "11111";
			else
				if (tapmatch='1') then
					expdelay_lfsr_next(0) <= expdelay_lfsr_reg(4) xor expdelay_lfsr_reg(2);
					expdelay_lfsr_next(4 downto 1) <= expdelay_lfsr_reg(3 downto 0);
				end if;
			end if;
		end if;
	end process;

	process(expdelay_lfsr_reg)
	begin
		exptap <= (others=>'0');

		case expdelay_lfsr_reg is
		when "11100" => --2
			exptap <= "001";
		when "10001" => --4
			exptap <= "010";
		when "11011" => --8
			exptap <= "011";
		when "01000" => --16
			exptap <= "100";
		when "01111" =>  --30
			exptap <= "101";
		when others=>
			exptap <= "000";
		end case;
	end process;

		
	-- output
	envelope <= std_logic_vector(envelope_reg);
	delay_lfsr <= delay_lfsr_reg;
	tapkey <= tapkey_reg;
		
END vhdl;
