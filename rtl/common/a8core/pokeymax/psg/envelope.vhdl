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

ENTITY PSG_envelope IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	ENABLE : IN STD_LOGIC;

	STEP32 : IN STD_LOGIC;
	COUNT_RESET : IN STD_LOGIC;
	SHAPE : IN STD_LOGIC_VECTOR(3 downto 0);
	PERIOD : IN STD_LOGIC_VECTOR(15 downto 0);
	
	ENVELOPE : OUT STD_LOGIC_VECTOR(4 downto 0)
);
END PSG_envelope;

ARCHITECTURE vhdl OF PSG_envelope IS
	signal envelope_reg: std_logic_vector(4 downto 0);
	signal envelope_next: std_logic_vector(4 downto 0);

	signal count_reg: unsigned(5 downto 0);
	signal count_next: unsigned(5 downto 0);

	signal envelope_tick: std_logic;
BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			count_reg <= (others=>'0');
			envelope_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			count_reg <= count_next;
			envelope_reg <= envelope_next;
		end if;
	end process;

	envelope_ticker : entity work.PSG_freqdiv
	GENERIC MAP
	(
		bits => 16
	)
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => enable,

		SYNC_RESET => count_reset,
		
		BIT_OUT => envelope_tick,
		
		THRESHOLD => unsigned(PERIOD)
	);	
	
	-- next state
	process(count_reg,shape,envelope_reg,envelope_tick,count_reset)
		variable continue : std_logic;
		variable attack : std_logic;
		variable alternate : std_logic;
		variable hold : std_logic;

		variable tmprep : std_logic_vector(4 downto 0);
	begin
		count_next <= count_reg;
		envelope_next <= envelope_reg;

		continue := shape(3);
		attack := shape(2);
		alternate := shape(1);
		hold := shape(0);

		if (count_reset='1') then
			count_next <= (others=>'0');
		else
			if (envelope_tick='1') then
				count_next <= count_reg+1;
				if ((hold and count_reg(5))='1') then
					envelope_next <= (others=>alternate xor attack);
				else
					tmprep := (others=>(count_reg(5) and alternate) xnor attack);
					envelope_next <= std_logic_vector(count_reg(4 downto 0)) xor tmprep;
				end if;

				if (((hold or not(continue)) and count_reg(5))='1') then
					if (continue='0') then
						envelope_next <= (others=>'0');
					end if;
					count_next(5) <= '1';
				end if;
			end if;
		end if;

	end process;
		
	-- output
	envelope <= envelope_reg(4 downto 1)&(envelope_reg(0) and STEP32); 
		
END vhdl;
