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

ENTITY gtia_priority_store IS
PORT 
( 
	CLK : in std_logic;
	colour_enable : in std_logic;

	PRIOR : in std_logic_vector(7 downto 0);
	P0 : in std_logic;
	P1 : in std_logic;
	P2	: in std_logic;
	P3 : in std_logic;
	PF0 : in std_logic;
	PF1 : in std_logic;
	PF2 : in std_logic;
	PF3 : in std_logic;
	BK : in std_logic;
	
	PRIOR_OUT : out std_logic_vector(4 downto 0);
	P0_OUT : out std_logic;
	P1_OUT : out std_logic;
	P2_OUT : out std_logic;
	P3_OUT : out std_logic;
	PF0_OUT : out std_logic;
	PF1_OUT : out std_logic;
	PF2_OUT : out std_logic;
	PF3_OUT : out std_logic;
	BK_OUT : out std_logic
);
END gtia_priority_store;

ARCHITECTURE vhdl OF gtia_priority_store IS
	
	signal SPRIOR_next : std_logic_vector(4 downto 0);
	signal SP0_next : std_logic;
	signal SP1_next : std_logic;
	signal SP2_next : std_logic;
	signal SP3_next : std_logic;	
	signal SF0_next : std_logic;
	signal SF1_next : std_logic;
	signal SF2_next : std_logic;
	signal SF3_next : std_logic;	
	signal SB_next : std_logic;

	signal SPRIOR_reg : std_logic_vector(4 downto 0);
	signal SP0_reg : std_logic;
	signal SP1_reg : std_logic;
	signal SP2_reg : std_logic;
	signal SP3_reg : std_logic;	
	signal SF0_reg : std_logic;
	signal SF1_reg : std_logic;
	signal SF2_reg : std_logic;
	signal SF3_reg : std_logic;	
	signal SB_reg : std_logic;
begin

	-- register
	process(clk)
	begin
		if rising_edge(clk) then
			SPRIOR_reg <= SPRIOR_next;
			SP0_reg <= SP0_next;
			SP1_reg <= SP1_next;
			SP2_reg <= SP2_next;
			SP3_reg <= SP3_next;
		
			SF0_reg <= SF0_next;
			SF1_reg <= SF1_next;
			SF2_reg <= SF2_next;
			SF3_reg <= SF3_next;
		
			SB_reg <= SB_next;
		end if;
	end process;
	
	-- need to register this to get same position as GTIA modes - i.e. two colour clocks after AN data received
	process(colour_enable,SPRIOR_reg,SP0_reg,SP1_reg,SP2_reg,SP3_reg,SF0_reg,SF1_reg,SF2_reg,SF3_reg,SB_reg,PRIOR,P0,P1,P2,P3,PF0,PF1,PF2,PF3,BK)
	begin
		SPRIOR_next <= SPRIOR_reg;

		SP0_next <= SP0_reg;
		SP1_next <= SP1_reg;
		SP2_next <= SP2_reg;
		SP3_next <= SP3_reg;
		
		SF0_next <= SF0_reg;
		SF1_next <= SF1_reg;
		SF2_next <= SF2_reg;
		SF3_next <= SF3_reg;
		
		SB_next <= SB_reg;
		
		if (colour_enable = '1') then	
			SPRIOR_next <= PRIOR(5) & PRIOR(3 downto 0);

			SP0_next <= P0;
			SP1_next <= P1;
			SP2_next <= P2;
			SP3_next <= P3;
			
			SF0_next <= PF0;
			SF1_next <= PF1;
			SF2_next <= PF2;
			SF3_next <= PF3;
			
			SB_next <= BK;	
		end if;
	end process;
		
	-- output
	PRIOR_OUT <= SPRIOR_reg;
	P0_OUT <= SP0_reg;
	P1_OUT <= SP1_reg;
	P2_OUT <= SP2_reg;
	P3_OUT <= SP3_reg;
	PF0_OUT <= SF0_reg;
	PF1_OUT <= SF1_reg;
	PF2_OUT <= SF2_reg;
	PF3_OUT <= SF3_reg;
	BK_OUT <= SB_reg;

end vhdl;