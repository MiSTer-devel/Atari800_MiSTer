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
USE ieee.math_real.ceil;
USE ieee.math_real.log2;

-- TODO - review this whole scheme
-- Massively overcomplex and turbo doesn't even work with it right now!
ENTITY shared_enable IS
GENERIC
(
	cycle_length : integer := 16 -- or 32...
);
PORT 
( 
	CLK : IN STD_LOGIC;	
	RESET_N : IN STD_LOGIC;
	ANTIC_REFRESH : IN STD_LOGIC;
	MEMORY_READY_CPU : IN STD_LOGIC;          -- during memory wait states keep CPU awake
	MEMORY_READY_ANTIC : IN STD_LOGIC;          -- during memory wait states keep CPU awake
	PAUSE_6502 : in std_logic;
	THROTTLE_COUNT_6502 : in std_logic_vector(5 downto 0);

	ANTIC_ENABLE_179 : OUT STD_LOGIC;  -- always about 1.79MHz to keep sound the same - 1 cycle early
	oldcpu_enable : OUT STD_LOGIC;     -- always about 1.79MHz to keep sound the same - 1 cycle only, when memory is ready...
	CPU_ENABLE_OUT : OUT STD_LOGIC    -- for compatibility run at 1.79MHz, for speed run as fast as we can
	
	-- antic DMA runs 1 cycle after 'enable', so ANTIC_ENABLE is delayed by cycle_length-1 cycles vs CPU_ENABLE (when in 1.79MHz mode)
);
END shared_enable;

ARCHITECTURE vhdl OF shared_enable IS
	component enable_divider IS
	generic(COUNT : natural := 1);
	PORT 
	( 
		CLK : IN STD_LOGIC;
		RESET_N : IN STD_LOGIC;
		ENABLE_IN : IN STD_LOGIC;
		
		ENABLE_OUT : OUT STD_LOGIC
	);
	END component;
	
	component delay_line IS
	generic(COUNT : natural := 1);
	PORT 
	( 
		CLK : IN STD_LOGIC;
		SYNC_RESET : IN STD_LOGIC;
		DATA_IN : IN STD_LOGIC;
		ENABLE : IN STD_LOGIC;
		RESET_N : IN STD_LOGIC;
		
		DATA_OUT : OUT STD_LOGIC
	);
	END component;		
	
	signal enable_179 : std_logic;
	signal enable_179_early : std_logic;
	signal cpu_enable : std_logic;
	
	signal cpu_extra_enable_next : std_logic;
	signal cpu_extra_enable_reg : std_logic;
	
	signal speed_shift_next : std_logic_vector(cycle_length-1 downto 0);
	signal speed_shift_reg : std_logic_vector(cycle_length-1 downto 0);	
	
	signal oldcycle_go : std_logic;
	signal oldcycle_state_next : std_logic_vector(2 downto 0);
	signal oldcycle_state_reg : std_logic_vector(2 downto 0);
	constant oldcycle_state_idle : std_logic_vector(2 downto 0) := "000";
	constant oldcycle_state_first_cycle_in_progress : std_logic_vector(2 downto 0) := "001";
	constant oldcycle_state_cycle_in_progress : std_logic_vector(2 downto 0) := "010";
	constant oldcycle_state_will_start_when_memory_free : std_logic_vector(2 downto 0) := "011";
	constant oldcycle_state_delayed : std_logic_vector(2 downto 0) := "100";
	
	signal memory_ready : std_logic;
	signal skip_cycle : std_logic;

	constant cycle_length_bits: integer := integer(ceil(log2(real(cycle_length))));
begin
	-- instantiate some clock calcs
	enable_179_clock_div : enable_divider
		generic map (COUNT=>cycle_length)
		port map(clk=>clk,reset_n=>reset_n,enable_in=>'1',enable_out=>enable_179);
		
	process(THROTTLE_COUNT_6502, speed_shift_reg, enable_179)
		variable speed_shift : std_logic;
		variable speed_shift_temp : std_logic_vector(cycle_length-1 downto 0);
	begin

		if (enable_179 = '1') then -- synchronize
			speed_shift_temp(cycle_length-1 downto 1) := (others=>'0');
			speed_shift_temp(0) := '1';
		else
			speed_shift_temp := speed_shift_reg;
		end if;

		speed_shift_next(cycle_length-1 downto 1) <= speed_shift_temp(cycle_length-2 downto 0);
		
		speed_shift := '0';
		
		for i in 0 to cycle_length_bits loop
			speed_shift := speed_shift or (speed_shift_temp(cycle_length/(2**i)-1) and throttle_count_6502(i));
		end loop;

		speed_shift_next(0) <= speed_shift;
	end process;

	delay_line_phase : delay_line
		generic map (COUNT=>cycle_length-1)
		port map(clk=>clk,sync_reset=>'0',reset_n=>reset_n,data_in=>enable_179, enable=>'1', data_out=>enable_179_early);	

	-- registers
	process(clk,reset_n)
	begin
		if (reset_n = '0') then
			cpu_extra_enable_reg <= '0';
			oldcycle_state_reg <= oldcycle_state_idle;
			speed_shift_reg <= (others=>'0');
		elsif (clk'event and clk='1') then										
			cpu_extra_enable_reg <= cpu_extra_enable_next;
			oldcycle_state_reg <= oldcycle_state_next;
			speed_shift_reg <= speed_shift_next;
		end if;
	end process;
	
	-- next state
	memory_ready <= memory_ready_cpu or memory_ready_antic;
	skip_cycle <= pause_6502 or antic_refresh;

	cpu_enable <= (speed_shift_reg(0) or cpu_extra_enable_reg or enable_179) and not(skip_cycle);
	cpu_extra_enable_next <= cpu_enable and not(memory_ready);

	process(oldcycle_state_reg,enable_179,memory_ready,skip_cycle,cpu_enable)
	begin
		oldcycle_go <= '0';
		oldcycle_state_next <= oldcycle_state_reg;

		case (oldcycle_state_reg) is
		when oldcycle_state_idle =>
			if (enable_179 = '1') then
				if (skip_cycle = '1') then
					oldcycle_go <= '1';
				else
					if (memory_ready = '1') then
						oldcycle_go <= '1';
					else
						oldcycle_state_next <= oldcycle_state_first_cycle_in_progress;
					end if;
				end if;
			else
				if (cpu_enable = '1' and memory_ready='0') then
					oldcycle_state_next <= oldcycle_state_cycle_in_progress;
				end if;
			end if;
		when oldcycle_state_first_cycle_in_progress =>
			if (memory_ready = '1') then
				oldcycle_go <= '1';
				oldcycle_state_next <= oldcycle_state_idle;
			end if;
		when oldcycle_state_cycle_in_progress =>
			if (enable_179 = '1') then
				if (memory_ready = '1') then
					oldcycle_state_next <= oldcycle_state_delayed;
				else
					oldcycle_state_next <= oldcycle_state_will_start_when_memory_free;
				end if;
			else
				if (memory_ready = '1') then
					oldcycle_state_next <= oldcycle_state_idle;
				end if;
			end if;
		when oldcycle_state_will_start_when_memory_free =>
			if (memory_ready = '1') then
				oldcycle_state_next <= oldcycle_state_delayed;
			end if;
		when oldcycle_state_delayed =>
			oldcycle_state_next <= oldcycle_state_idle;
			if (skip_cycle = '1') then
				oldcycle_go <= '1';
			else
				if (memory_ready = '1') then
					oldcycle_go <= '1';
				else
					oldcycle_state_next <= oldcycle_state_first_cycle_in_progress;
				end if;
			end if;
		when others=>
			oldcycle_state_next <= oldcycle_state_idle;
		end case;

	end process;
	
	-- output
	oldcpu_enable <= oldcycle_go;
	ANTIC_ENABLE_179 <= enable_179_early;
	
	CPU_ENABLE_OUT <= cpu_enable; -- run at 25MHz

end vhdl;
