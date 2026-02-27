---------------------------------------------------------------------------
-- (c) 2026 Wojciech Mostowski
---------------------------------------------------------------------------

LIBRARY ieee;

USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE IEEE.STD_LOGIC_MISC.all;

ENTITY tape_handler IS
PORT
(
	clk : in std_logic;
	reset_n : in std_logic;

	data_in : in std_logic_vector(31 downto 0);
	wr_en : in std_logic;

	fifo_reset : in std_logic;
	fifo_empty : out std_logic;
	fifo_full : out std_logic;

	fsk_active : out std_logic;
	pwm_active : out std_logic;
	fsk_out : out std_logic;
	pwm_out : out std_logic;
	pwm_invert : in std_logic;
	fsk_motor : in std_logic;
	pwm_motor : in std_logic;
	tape_sound_en : in std_logic;
	audio_out : out std_logic_vector(7 downto 0)
);
END tape_handler;

ARCHITECTURE vhdl OF tape_handler IS

signal fifo_queue_empty : std_logic;
signal fifo_req : std_logic;
signal fifo_data : std_logic_vector(31 downto 0);
signal pins_out_reg : std_logic_vector(1 downto 0);
signal pins_out_next : std_logic_vector(1 downto 0);
signal pwm_out_reg : std_logic;
signal pwm_out_next : std_logic;
signal active_reg : std_logic;
signal active_next : std_logic;
signal count_reg : unsigned(30 downto 0);
signal count_next : unsigned(30 downto 0);
signal pwm_bit : std_logic;
signal fsk_bit : std_logic;
signal fsk_act : std_logic;
signal pwm_act : std_logic;

-- These are based on the 28.636364 MHz core clock
-- 1 frequency 5327 Hz
-- 0 frequency 3995 Hz
-- base / carrier frequency 588 Hz
constant WAVE_LIMIT_0 : integer := 3583;
constant WAVE_LIMIT_1 : integer := 2687;
constant WAVE_LIMIT_B : integer := 24350;
signal wave_counter_0 : integer range 0 to WAVE_LIMIT_0;
signal wave_counter_1 : integer range 0 to WAVE_LIMIT_1;
signal wave_counter_b : integer range 0 to WAVE_LIMIT_B;
signal wave_0 : std_logic;
signal wave_1 : std_logic;
signal wave_b : std_logic;

begin

tape_transmit_fifo : work.fifo_tape
PORT MAP (clock => clk,data=>data_in(31 downto 0),rdreq=>fifo_req,wrreq=>wr_en,empty=>fifo_queue_empty,full=>fifo_full,q=>fifo_data,aclr=>fifo_reset);

process(clk, reset_n)
begin
	if (reset_n = '0') then
		pins_out_reg <= "01";
		pwm_out_reg <= '0';
		active_reg <= '0';
		count_reg <= (others => '0');
	elsif rising_edge(clk) then
		pins_out_reg <= pins_out_next;
		pwm_out_reg <= pwm_out_next;
		active_reg <= active_next;
		count_reg <= count_next;
	end if;
end process;

process(count_reg, pwm_out_reg, pins_out_reg, active_reg, fifo_req, fifo_data, fifo_queue_empty, fifo_reset)
begin

	fifo_req <= '0';
	count_next <= count_reg;
	pwm_out_next <= pwm_out_reg;
	pins_out_next <= pins_out_reg;
	active_next <= active_reg;

	if fifo_reset = '1' then
		count_next <= (others => '0');
		pwm_out_next <= '0';
		active_next <= '0';
		pins_out_next <= "01";
	else
		if or_reduce(std_logic_vector(count_reg)) = '0' then
			if fifo_queue_empty = '0' then
				if or_reduce(fifo_data(31 downto 2)) = '0' then
					-- special marker for (a) changing between fsk and pwm output, (b) setting active
					active_next <= fifo_data(0);
					pwm_out_next <= fifo_data(1);
					pins_out_next <= "01";
				else
					count_next <= unsigned(fifo_data(31 downto 1));
					if pwm_out_reg = '1' then
						pins_out_next(1) <= fifo_data(0);
					else
						pins_out_next(0) <= fifo_data(0);
					end if;
				end if;
				fifo_req <= '1';
			end if;
		else
			count_next <= count_reg - 1;
		end if;
	end if;
end process;

process(clk, reset_n)
begin
	if (reset_n = '0') then
		wave_counter_0 <= 0;
		wave_0 <= '0';
	elsif rising_edge(clk) then
		if wave_counter_0 = WAVE_LIMIT_0 then
			wave_counter_0 <= 0;
			wave_0 <= not(wave_0);
		else
			wave_counter_0 <= wave_counter_0 + 1;
		end if;
	end if;
end process;

process(clk, reset_n)
begin
	if (reset_n = '0') then
		wave_counter_1 <= 0;
		wave_1 <= '0';
	elsif rising_edge(clk) then
		if wave_counter_1 = WAVE_LIMIT_1 then
			wave_counter_1 <= 0;
			wave_1 <= not(wave_1);
		else
			wave_counter_1 <= wave_counter_1 + 1;
		end if;
	end if;
end process;

process(clk, reset_n)
begin
	if (reset_n = '0') then
		wave_counter_b <= 0;
		wave_b <= '0';
	elsif rising_edge(clk) then
		if wave_counter_b = WAVE_LIMIT_B then
			wave_counter_b <= 0;
			wave_b <= not(wave_b);
		else
			wave_counter_b <= wave_counter_b + 1;
		end if;
	end if;
end process;

fsk_bit <= pins_out_reg(0);
pwm_bit <= pins_out_reg(1) xor pwm_invert;
pwm_act <= active_reg and pwm_out_reg;
fsk_act <= active_reg and not(pwm_out_reg);

-- output
fsk_out <= fsk_bit;
pwm_out <= pwm_bit;
pwm_active <= pwm_act;
fsk_active <= fsk_act;
fifo_empty <= fifo_queue_empty;

audio_out <=
	x"00" when tape_sound_en = '0' else
	"00"&(wave_b and ((wave_0 and not(fsk_bit)) or (wave_1 and fsk_bit)))&(wave_b xor ((wave_0 and not(fsk_bit)) or (wave_1 and fsk_bit)))&"0000" when (fsk_act and fsk_motor) = '1' else
	"00"&pwm_bit&"00000" when (pwm_act and pwm_motor) = '1' else x"00";

end vhdl;
