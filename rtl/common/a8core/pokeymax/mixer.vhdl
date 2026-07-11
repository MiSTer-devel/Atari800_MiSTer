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
use work.AudioTypes.all;

LIBRARY work;

ENTITY mixer IS 
PORT
(
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

	ENABLE_CYCLE : IN STD_LOGIC;

	DETECT_RIGHT : IN STD_LOGIC;
	POST_DIVIDE : IN STD_LOGIC_VECTOR(7 downto 0);
	FANCY_ENABLE : IN STD_LOGIC;
	B_CH0_EN : IN STD_LOGIC_VECTOR(3 downto 0);	
	B_CH1_EN : IN STD_LOGIC_VECTOR(3 downto 0);	

	L_CH0 : IN SIGNED(15 downto 0);
	L_CH1 : IN SIGNED(15 downto 0);
	L_CH2 : IN SIGNED(15 downto 0);
	L_CH3 : IN SIGNED(15 downto 0);
	L_CH4 : IN SIGNED(15 downto 0);
	R_CH0 : IN SIGNED(15 downto 0);
	R_CH1 : IN SIGNED(15 downto 0);
	R_CH2 : IN SIGNED(15 downto 0);
	R_CH3 : IN SIGNED(15 downto 0);
	R_CH4 : IN SIGNED(15 downto 0);
	B_CH0 : IN SIGNED(15 downto 0);
	B_CH1 : IN SIGNED(15 downto 0);

	MUTE_CHANNEL : IN STD_LOGIC;

	S_AUDIO : OUT SIGNED(15 downto 0);
	S_LEFT : OUT STD_LOGIC;
	S_RIGHT : OUT STD_LOGIC;
	S_CHANNEL : OUT UNSIGNED(2 downto 0);

	AUDIO_0_SIGNED : out signed(15 downto 0);
	AUDIO_1_SIGNED : out signed(15 downto 0);
	AUDIO_2_SIGNED : out signed(15 downto 0);
	AUDIO_3_SIGNED : out signed(15 downto 0)
);
END mixer;		
		
ARCHITECTURE vhdl OF mixer IS


	-- DETECT RIGHT PLAYING
	signal RIGHT_PLAYING_RECENTLY : std_logic;
	signal RIGHT_NEXT : std_logic;
	signal RIGHT_REG : std_logic;
	signal RIGHT_PLAYING_COUNT_NEXT : unsigned(23 downto 0);
	signal RIGHT_PLAYING_COUNT_REG : unsigned(23 downto 0);
	signal RIGHT_SNAP_REG : signed(19 downto 8);
	signal RIGHT_SNAP_NEXT : signed(19 downto 8);

	-- sums
	signal audio0_reg : signed(15 downto 0);
	signal audio0_next : signed(15 downto 0);
	signal audio1_reg : signed(15 downto 0);
	signal audio1_next : signed(15 downto 0);
	signal audio2_reg : signed(15 downto 0);
	signal audio2_next : signed(15 downto 0);
	signal audio3_reg : signed(15 downto 0);
	signal audio3_next : signed(15 downto 0);

	signal acc_reg : signed(19 downto 0);
	signal acc_next : signed(19 downto 0);

	-- Pipeline register: holds divided value between state_divide and state_clear
	signal divided_reg  : signed(19 downto 0);
	signal divided_next : signed(19 downto 0);

	signal out_ch_reg : std_logic_vector(1 downto 0);
	signal out_ch_next : std_logic_vector(1 downto 0);
	
	signal state_reg : unsigned(3 downto 0);
	signal state_next : unsigned(3 downto 0);
	constant state_CH0    : unsigned(3 downto 0) := "0000";
	constant state_CH1    : unsigned(3 downto 0) := "0001";
	constant state_CH2    : unsigned(3 downto 0) := "0010";
	constant state_CH3    : unsigned(3 downto 0) := "0011";
	constant state_CH4    : unsigned(3 downto 0) := "0100";
	constant state_BCH0   : unsigned(3 downto 0) := "0101";
	constant state_BCH1   : unsigned(3 downto 0) := "0110";
	constant state_divide : unsigned(3 downto 0) := "0111";  -- divide
	constant state_clear  : unsigned(3 downto 0) := "1000";  -- saturate + write output

	signal channelsel : std_logic_vector(3 downto 0);
	signal include_in_output : std_logic_vector(3 downto 0);
	signal left_on_right : std_logic;
	
	signal volume : signed(15 downto 0);
	signal out_left_enable : std_logic;
	signal out_right_enable : std_logic;
	signal saturated : signed(15 downto 0);
	
	signal write : std_logic;

BEGIN
-- DETECT IF RIGHT CHANNEL PLAYING
-- TODO: into another entity
process(clk,reset_n)
begin
	if (reset_n='0') then
		RIGHT_REG <= '0';
		RIGHT_SNAP_REG <= (others=>'0');
		RIGHT_PLAYING_COUNT_REG <= (others=>'0');
		audio0_reg <= (others=>'0');
		audio1_reg <= (others=>'0');
		audio2_reg <= (others=>'0');
		audio3_reg <= (others=>'0');
		acc_reg <= (others=>'0');
		out_ch_reg <= (others=>'0');
		divided_reg <= (others=>'0');
		state_reg <= state_CH0;
	elsif (clk'event and clk='1') then
		RIGHT_REG <= RIGHT_NEXT;
		RIGHT_SNAP_REG <= RIGHT_SNAP_NEXT;
		RIGHT_PLAYING_COUNT_REG <= RIGHT_PLAYING_COUNT_NEXT;
		audio0_reg <= audio0_next;
		audio1_reg <= audio1_next;
		audio2_reg <= audio2_next;
		audio3_reg <= audio3_next;
		acc_reg <= acc_next;
		out_ch_reg <= out_ch_next;
		divided_reg <= divided_next;
		state_reg <= state_next;
	end if;
end process;

process(RIGHT_NEXT,RIGHT_REG,ENABLE_CYCLE,RIGHT_PLAYING_RECENTLY,RIGHT_PLAYING_COUNT_REG)
begin
	RIGHT_PLAYING_COUNT_NEXT <= RIGHT_PLAYING_COUNT_REG;

	if (ENABLE_CYCLE='1' and RIGHT_PLAYING_RECENTLY='1') then
		RIGHT_PLAYING_COUNT_NEXT <= RIGHT_PLAYING_COUNT_REG-1;
	end if;

	if (RIGHT_NEXT/=RIGHT_REG) then
		RIGHT_PLAYING_COUNT_NEXT <= (others=>'1');
	end if;
end process;
RIGHT_PLAYING_RECENTLY <= or_reduce(std_logic_vector(RIGHT_PLAYING_COUNT_REG));


	process(state_reg,RIGHT_REG,RIGHT_SNAP_REG,RIGHT_SNAP_NEXT,out_ch_reg,acc_reg,volume,divided_reg,
	POST_DIVIDE,SATURATED,include_in_output,enable_cycle,mute_channel)
		variable postdivide  : std_logic_vector(1 downto 0);
		variable presaturate : signed(19 downto 0);
		variable addAcc      : std_logic;
		variable clearAcc    : std_logic;
	begin
		state_next        <= state_reg;
		out_ch_next       <= out_ch_reg;
		acc_next          <= acc_reg;
		RIGHT_NEXT        <= RIGHT_REG;
		RIGHT_SNAP_NEXT <= RIGHT_SNAP_REG;
		divided_next      <= divided_reg;

		write      <= '0';
		channelsel <= (others=>'0');
		saturated  <= (others=>'0');
		addAcc     := '0';
		clearAcc   := '0';
		postdivide := "00";

		case out_ch_reg is 
		when "00" =>
			postdivide := POST_DIVIDE(1 downto 0);
			addAcc     := include_in_output(0);
		when "01" =>
			postdivide := POST_DIVIDE(3 downto 2);
			addAcc     := include_in_output(1);
		when "10" =>
			postdivide := POST_DIVIDE(5 downto 4);
			addAcc     := include_in_output(2);
		when "11" =>
			postdivide := POST_DIVIDE(7 downto 6);
			addAcc     := include_in_output(3);
		when others =>
		end case;

		case state_reg is
			when state_CH0 =>
				channelsel <= x"0";					
				state_next <= state_CH1;				
			when state_CH1 =>
				channelsel <= x"1";
				state_next <= state_CH2;
			when state_CH2 =>
				channelsel <= x"2";
				state_next <= state_CH3;	
			when state_CH3 =>
				channelsel <= x"3";
				state_next <= state_CH4;
			when state_CH4 =>
				channelsel <= x"4";
				state_next <= state_BCH0;
			when state_BCH0 =>
				channelsel <= x"6";
				state_next <= state_BCH1;
				-- NEEDS DOING WITHOUT BCH* mixed, since those plays on all channels!!
				if out_ch_reg(0) = '1' then        -- right pass: acc_reg = clean right sum
					RIGHT_SNAP_NEXT <= acc_reg(19 downto 8);
					RIGHT_NEXT <= or_reduce(std_logic_vector(acc_reg(19 downto 8) xor RIGHT_SNAP_REG));
				end if;
			when state_BCH1 =>
				channelsel <= x"7";
				state_next <= state_divide;

			when state_divide =>
				-- Divide accumulator only. DC removal has been extracted to dc_blocker.
				-- Result registered into divided_reg, accumulator cleared.
				case postdivide is
					when "00" => presaturate := resize(acc_reg(19 downto 0), 20);
					when "01" => presaturate := resize(acc_reg(19 downto 1), 20);
					when "10" => presaturate := resize(acc_reg(19 downto 2), 20);
					when "11" => presaturate := resize(acc_reg(19 downto 3), 20);
					when others => presaturate := acc_reg;
				end case;

				divided_next <= presaturate;
				clearAcc     := '1';
				state_next   <= state_clear;

			when state_clear =>
				-- Saturate the registered divided value and write to output.
				-- Critical path: just the saturation check + mux
				write       <= '1';
				out_ch_next <= std_logic_vector(unsigned(out_ch_reg)+1);
				state_next  <= state_CH0;
				addAcc := '0';

			when others =>
				state_next <= state_CH0;
		end case;

		channelsel(3) <= out_ch_reg(0);

		-- Saturation reads from the pipeline register, so only the
		-- saturation check itself is on the state_clear critical path
		if divided_reg(19 downto 15) /= "00000" and
		   divided_reg(19 downto 15) /= "11111" then
			saturated(14 downto 0) <= (others => not divided_reg(19));
			saturated(15)          <= divided_reg(19);
		else
			saturated <= divided_reg(15 downto 0);
		end if;

		-- Accumulator update: clear takes priority over add
		if clearAcc = '1' then
			acc_next <= (others=>'0');
		elsif addAcc = '1' and mute_channel='0' then
			acc_next <= acc_reg + resize(volume, 20);
		end if;

	end process;		

	process(state_reg,channelsel,
		L_CH0,L_CH1,L_CH2,L_CH3,L_CH4,
		R_CH0,R_CH1,R_CH2,R_CH3,R_CH4,
		B_CH0,B_CH1,
		B_CH0_EN,B_CH1_EN
		)
	begin
		volume <= (others=>'0');
		out_left_enable <= not(channelsel(3));
		out_right_enable <= channelsel(3);

			--left
		include_in_output(0) <= not(channelsel(3)); 
		include_in_output(2) <= not(channelsel(3));
			--right
		include_in_output(1) <= channelsel(3);
		include_in_output(3) <= channelsel(3);
		case channelsel is
		when x"0" =>
		        volume <= L_CH0;
		when x"1" =>
		        volume <= L_CH1;
		when x"2" =>
		        volume <= L_CH2;
		when x"3" =>
		        volume <= L_CH3;
		when x"4" =>
		        volume <= L_CH4;
		when x"8" =>
		        volume <= R_CH0;
		when x"9" =>
			volume <= R_CH1;
		when x"a" =>
			volume <= R_CH2;
		when x"b" =>
			volume <= R_CH3;
		when x"c" =>
			volume <= R_CH4;
		when x"6"|x"e" =>
			include_in_output <= B_CH0_EN;
		        volume <= B_CH0;
			out_left_enable <= '1';
			out_right_enable <= '1';
		when x"7"|x"f" =>
			include_in_output <= B_CH1_EN;
		        volume <= B_CH1;
			out_left_enable <= '1';
			out_right_enable <= '1';
		when others =>
			out_left_enable <= '0';
			out_right_enable <= '0';
		end case;
	end process;
	
	left_on_right <= not(FANCY_ENABLE) or (not(RIGHT_PLAYING_RECENTLY) AND DETECT_RIGHT);		

	process(write,saturated,out_ch_reg,left_on_right,audio0_reg,audio1_reg,audio2_reg,audio3_reg)
		variable out_ch_adj : std_logic_vector(2 downto 0);
		variable wr : std_logic_vector(3 downto 0);
	begin
		audio0_next <= audio0_reg;
		audio1_next <= audio1_reg;
		audio2_next <= audio2_reg;
		audio3_next <= audio3_reg;

		out_ch_adj(1 downto 0) := out_ch_reg;
		out_ch_adj(2) := left_on_right;
		
		wr := (others=>'0');
		case out_ch_adj is 	
		when "000" => 
			wr(0) := write;
		when "001" => 
			wr(1) := write;
		when "010" => 
			wr(2) := write;
		when "011" => 
			wr(3) := write;
		when "100" => 
			wr(0) := write;
			wr(1) := write;
		when "110" => 
			wr(2) := write;
			wr(3) := write;
		when others =>
			-- 101 -> write to right, dropped since we are playing ONLY left on right
			-- 111 -> write to right, dropped since we are playing ONLY left on right
			-- Deliberate! We accumulate right still for the right detect logic but do not output it
		end case;

		if (wr(0)='1') then
			audio0_next <= saturated;
		end if;
		if (wr(1)='1') then
			audio1_next <= saturated;
		end if;
		if (wr(2)='1') then
			audio2_next <= saturated;
		end if;
		if (wr(3)='1') then
			audio3_next <= saturated;
		end if;
	end process;	
	
-- output
	S_AUDIO <= VOLUME;
	S_LEFT <= out_left_enable;
	S_RIGHT <= out_right_enable;
	S_CHANNEL <= unsigned(CHANNELSEL(2 downto 0));

	AUDIO_0_SIGNED <= audio0_reg;
	AUDIO_1_SIGNED <= audio1_reg;
	AUDIO_2_SIGNED <= audio2_reg;
	AUDIO_3_SIGNED <= audio3_reg;
end vhdl;
