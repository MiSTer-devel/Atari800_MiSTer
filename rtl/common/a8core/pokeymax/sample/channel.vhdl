--------------------------------------------------------------------------
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

ENTITY sample_channel IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	ENABLE : IN STD_LOGIC;

	syncreset : in std_logic;
	start_addr : IN std_logic_vector(15 downto 0);
	len : IN std_logic_vector(15 downto 0);
	period : IN std_logic_vector(11 downto 0);
	
	twocycles : in std_logic;
	
	addr : OUT STD_LOGIC_VECTOR(16 downto 0);
	irq : OUT STD_LOGIC;
	req : OUT STD_LOGIC
);
END sample_channel;

ARCHITECTURE vhdl OF sample_channel IS
	signal pointer_reg : unsigned(16 downto 0);
	signal pointer_next : unsigned(16 downto 0);
	signal remaining_reg : unsigned(15 downto 0);
	signal remaining_next : unsigned(15 downto 0);
	signal periodpos_reg : unsigned(11 downto 0);
	signal periodpos_next : unsigned(11 downto 0);
	signal req_reg : std_logic;
	signal req_next : std_logic;
	signal irq_reg : std_logic;
	signal irq_next : std_logic;
	signal resetpending_reg : std_logic;
	signal resetpending_next : std_logic;
	
BEGIN
	-- register
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			pointer_reg <= (others=>'0');
			remaining_reg <= (others=>'0');
			periodpos_reg <= (others=>'0');
			req_reg <= '0';
			irq_reg <= '0';
			resetpending_reg <= '0';
		elsif (clk'event and clk='1') then
			pointer_reg <= pointer_next;
			remaining_reg <= remaining_next;
			periodpos_reg <= periodpos_next;
			req_reg <= req_next;
			irq_reg <= irq_next;
			resetpending_reg <= resetpending_next;
		end if;
	end process;

	process(start_addr, len, period,
		pointer_reg, remaining_reg, periodpos_reg, resetpending_reg,
		enable,
		syncreset,
		twocycles
		)
	variable change : unsigned(16 downto 0);
	variable endperiod : std_logic;
	variable endsample : std_logic;
	variable nextsample : std_logic;
	begin
		pointer_next <= pointer_reg;
		remaining_next <= remaining_reg;
		periodpos_next <= periodpos_reg;
		resetpending_next <= resetpending_reg or syncreset;
		irq_next <= '0';
		req_next <= '0';

		nextsample := '0';

		endperiod := not(or_reduce(std_logic_vector(periodpos_reg(periodpos_reg'left downto 1))));
		endsample := not(or_reduce(std_logic_vector(remaining_reg(remaining_reg'left downto 1))));
	
		if (enable='1') then
			periodpos_next <= periodpos_reg-1;
			resetpending_next <='0';

			if (endperiod='1') then
				if (twocycles='1') then
					change:=to_unsigned(1,17);
				else
					change:=to_unsigned(2,17);
				end if;
				pointer_next <= pointer_reg+change;				
				remaining_next <= remaining_reg-1;				
				periodpos_next <= unsigned(period);				
				req_next <= '1';	

				nextsample := endsample;
			end if;

			if (resetpending_reg='1') then
				nextsample := '1';
			end if;

			if (nextsample='1') then
				irq_next <= '1';
				pointer_next <= unsigned(start_addr)&'0';
				remaining_next <= unsigned(len);
				periodpos_next <= unsigned(period);
				req_next <= '1';	
			end if;
		end if;
	end process;

	addr <= std_logic_vector(pointer_next);

	req <= req_reg;
	irq <= irq_reg;
	
end vhdl;

