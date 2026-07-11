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

ENTITY PSG_volume_profile IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	
	CHANNEL_1A : IN STD_LOGIC_VECTOR(4 downto 0);
	CHANNEL_1B : IN STD_LOGIC_VECTOR(4 downto 0);
	CHANNEL_1C : IN STD_LOGIC_VECTOR(4 downto 0);
	CHANNEL_1_CHANGED : IN STD_LOGIC;
	CHANNEL_2A : IN STD_LOGIC_VECTOR(4 downto 0);
	CHANNEL_2B : IN STD_LOGIC_VECTOR(4 downto 0);
	CHANNEL_2C : IN STD_LOGIC_VECTOR(4 downto 0);
	CHANNEL_2_CHANGED : IN STD_LOGIC;

	CHANNEL_MASK_1 : IN STD_LOGIC_VECTOR(5 downto 0); --1ABC/2ABC
	CHANNEL_MASK_2 : IN STD_LOGIC_VECTOR(5 downto 0); 

	AUDIO_OUT_1 : OUT UNSIGNED(15 downto 0);
	AUDIO_OUT_2 : OUT UNSIGNED(15 downto 0);

	PROFILE_ADDR : OUT std_logic_vector(4 downto 0);
	PROFILE_REQUEST : OUT std_logic;
	PROFILE_READY : IN std_logic;
	PROFILE_DATA : IN std_logic_vector(15 downto 0)
);
END PSG_volume_profile;

ARCHITECTURE vhdl OF PSG_volume_profile IS
	signal acc_reg: unsigned(17 downto 0);
	signal acc_next: unsigned(17 downto 0);
	
	signal vol_1_reg: unsigned(15 downto 0);
	signal vol_1_next: unsigned(15 downto 0);
	signal vol_2_reg: unsigned(15 downto 0);
	signal vol_2_next: unsigned(15 downto 0);

	signal state_reg : std_logic_vector(2 downto 0);
	signal state_next : std_logic_vector(2 downto 0);
	constant state_idle : std_logic_vector(2 downto 0) := "000";
	constant state_update1_request : std_logic_vector(2 downto 0) := "001";
	constant state_update1_wait : std_logic_vector(2 downto 0) := "010";
	constant state_update1_done : std_logic_vector(2 downto 0) := "011";
	constant state_update2_request : std_logic_vector(2 downto 0) := "100";
	constant state_update2_wait : std_logic_vector(2 downto 0) := "101";
	constant state_update2_done : std_logic_vector(2 downto 0) := "110";

	signal channelsel_reg: std_logic_vector(5 downto 0);
	signal channelsel_next: std_logic_vector(5 downto 0);
	signal mask: std_logic_vector(5 downto 0);

	signal ready : std_logic;
	signal store : std_logic;
	signal request : std_logic;

	signal volume : unsigned(15 downto 0);
	signal channel_mux : std_logic_vector(4 downto 0);

	signal outputdev_mux : std_logic;

--	function logvolume(x: std_logic_vector(4 downto 0)) return unsigned is
--	begin
--		case x is
--	when "00000" => return "0000000000000000";
--        when "00001" => return "0000000000011100";
--        when "00010" => return "0000000000111101";
--        when "00011" => return "0000000001100110";
--        when "00100" => return "0000000010011001";
--        when "00101" => return "0000000011010111";
--        when "00110" => return "0000000100100011";
--        when "00111" => return "0000000110000000";
--        when "01000" => return "0000000111110001";
--        when "01001" => return "0000001001111101";
--        when "01010" => return "0000001100100111";
--        when "01011" => return "0000001111111000";
--        when "01100" => return "0000010011111000";
--        when "01101" => return "0000011000110001";
--        when "01110" => return "0000011110110001";
--        when "01111" => return "0000100110000111";
--        when "10000" => return "0000101111000111";
--        when "10001" => return "0000111010001000";
--        when "10010" => return "0001000111101000";
--        when "10011" => return "0001011000001010";
--        when "10100" => return "0001101100011001";
--        when "10101" => return "0010000101001100";
--        when "10110" => return "0010100011100011";
--        when "10111" => return "0011001000101111";
--        when "11000" => return "0011110110010010";
--        when "11001" => return "0100101110000100";
--        when "11010" => return "0101110010011000";
--        when "11011" => return "0111000110000011";
--        when "11100" => return "1000101100100001";
--        when "11101" => return "1010101010000001";
--        when "11110" => return "1101000011101111";
--        when "11111" => return "1111111111111111";
--		end case;
--	end logvolume;	
BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			vol_1_reg <= (others=>'0');
			vol_2_reg <= (others=>'0');
			channelsel_reg <= "100000";
			acc_reg <= (others=>'0');
			state_reg <= state_idle;
		elsif (clk'event and clk='1') then
			vol_1_reg <= vol_1_next;
			vol_2_reg <= vol_2_next;
			channelsel_reg <= channelsel_next;
			acc_reg <= acc_next;
			state_reg <= state_next;
		end if;
	end process;
	
	-- next state
	-- channel in->compute->result->store->add
	process(state_reg, acc_reg, channelsel_reg, ready, volume,channel_mask_1,channel_mask_2, mask, channel_1_changed,channel_2_changed)
		variable start : std_logic;
		variable inc : std_logic;
		variable active : std_logic;
		variable last : std_logic;
	begin
		state_next <= state_reg;
		acc_next <= acc_reg;
		channelsel_next <= channelsel_reg;
		outputdev_mux <= '0';

		start := '0';
		inc := '0';
		active := or_reduce(mask and channelsel_reg);
		last := channelsel_reg(0);

		request <= '0';
		store <= '0';

		case state_reg is
			when state_idle =>
				if ((channel_1_changed or channel_2_changed)='1') then
					state_next <= state_update1_request;
					start := '1';
				end if;
			when state_update1_request =>
				request <= active;
				inc := not(active);
				if (active='1') then
					state_next <= state_update1_wait;
				else 
					if (last='1') then
						state_next <= state_update1_done;
					end if;
				end if;
			when state_update1_wait =>
				inc := ready;
				request <= not(ready);
				if (ready='1') then
					if (last='1') then
						state_next <= state_update1_done;
					else
						state_next <= state_update1_request;
					end if;
				end if;
			when state_update1_done =>
				state_next <= state_update2_request;
				store <= '1';
				start := '1';
			when state_update2_request =>
				outputdev_mux <= '1';
				request <= active;
				inc := not(active);
				if (active='1') then
					state_next <= state_update2_wait;
				else 
					if (last='1') then
						state_next <= state_update2_done;
					end if;
				end if;
			when state_update2_wait =>
				outputdev_mux <= '1';
				inc := ready;
				request <= not(ready);
				if (ready='1') then
					if (last='1') then
						state_next <= state_update2_done;
					else
						state_next <= state_update2_request;
					end if;
				end if;
			when state_update2_done =>
				outputdev_mux <= '1';
				state_next <= state_idle;
				store <= '1';
			when others=>
				state_next <= state_idle;
		end case;

		if (start='1') then
			acc_next <= (others=>'0');
			channelsel_next <= "100000";
		end if;

		if (inc='1') then
			channelsel_next <= "0"&channelsel_reg(5 downto 1);
		end if;

		if (ready='1') then
			acc_next <= acc_reg + resize(volume,17);
		end if;

	end process;	

	process(outputdev_mux,vol_1_reg,vol_2_reg,store,acc_reg,channel_mask_1,channel_mask_2)
	begin
		mask <= (others=>'0');
		vol_1_next <= vol_1_reg;
		vol_2_next <= vol_2_reg;

		if (outputdev_mux='1') then
			mask <= channel_mask_1;
			if (store='1') then
				vol_1_next <= acc_reg(17 downto 2);
			end if;
		else
			mask <= channel_mask_2;
			if (store='1') then
				vol_2_next <= acc_reg(17 downto 2);
			end if;
		end if;
	end process;

	process(channelsel_reg,channel_1a,channel_1b,channel_1c,channel_2a,channel_2b,channel_2c)
	begin
		channel_mux <= (others=>'0');

		case channelsel_reg is
		when "100000" =>
			channel_mux <= channel_1a;
		when "010000" =>
			channel_mux <= channel_1b;
		when "001000" =>
			channel_mux <= channel_1c;
		when "000100" =>
			channel_mux <= channel_2a;
		when "000010" =>
			channel_mux <= channel_2b;
		when "000001" =>
			channel_mux <= channel_2c;
		when others=>
		end case;
	end process;

	-- there is this vol table array recorded from the device, best to make use of that I think once I have flash support working		
	-- for now, lets use log of each channel then sum
	-- + I'd like to review that table in octave to understand what is going on...
	-- from octave based on datasheet only: sqrt(2)^i/sqrt(2)^15;
	volume <= unsigned(profile_data);
	ready <= profile_ready;
		
	-- output
	AUDIO_OUT_1 <= vol_1_reg;
	AUDIO_OUT_2 <= vol_2_reg;

	PROFILE_ADDR <= channel_mux;
	PROFILE_REQUEST <= request;
		
END vhdl;
