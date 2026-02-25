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

	data_in : in std_logic_vector(31 downto 0); -- to fifo data
	wr_en : in std_logic; -- to fifo wrreq

	fifo_reset : in std_logic;
	fifo_empty : out std_logic;
	fifo_full : out std_logic;
	fifo_count : out std_logic_vector(7 downto 0);

	active : out std_logic; -- enabled externally and motor running
	fsk_out : out std_logic; -- fsk bit transmit out
	pwm_out : out std_logic; -- pwm bit transmit out
	pwm_invert : in std_logic;
	fsk_motor : in std_logic;
	pwm_motor : in std_logic
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
signal motor_on : std_logic;

begin

tape_transmit_fifo : work.fifo_tape
PORT MAP (clock => clk,data=>data_in(31 downto 0),rdreq=>fifo_req,wrreq=>wr_en,empty=>fifo_queue_empty,full=>fifo_full,q=>fifo_data,usedw=>fifo_count,aclr=>fifo_reset);

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

process(count_reg, pwm_out_reg, pins_out_reg, active_reg, fifo_req, fifo_data, fifo_queue_empty, motor_on, fifo_reset)
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

motor_on <= (pwm_out_reg and pwm_motor) or (not(pwm_out_reg) and fsk_motor);

-- output
fsk_out <= pins_out_reg(0);
pwm_out <= pins_out_reg(1) xor pwm_invert;
active <= active_reg and motor_on;
fifo_empty <= fifo_queue_empty;

end vhdl;
