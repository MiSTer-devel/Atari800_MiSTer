---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.ALL;

ENTITY cpu IS
PORT 
(
	CLK,RESET,ENABLE : IN STD_logic;
	DI : IN std_logic_vector(7 downto 0);
	IRQ_n   : in  std_logic;
	NMI_n   : in  std_logic;
	MEMORY_READY : in std_logic;
	THROTTLE : in std_logic;
	RDY : in std_logic;
	DO : OUT std_logic_vector(7 downto 0);
	A : OUT std_logic_vector(15 downto 0);
	R_W_n : OUT std_logic;
	CPU_FETCH : out std_logic
);
END cpu;

architecture vhdl of cpu is
	signal CPU_ENABLE: std_logic; -- Apply Antic HALT and throttle
	signal addr : std_logic_vector(23 downto 0);
	signal cpu_do : std_logic_vector(7 downto 0);
	signal cpu_di : std_logic_vector(7 downto 0);
	signal cpu_rwn : std_logic;
	
BEGIN
	CPU_ENABLE <= ENABLE and MEMORY_READY and THROTTLE;
	DO <= cpu_do;
	R_W_n <= cpu_rwn;

	cpu_di <= cpu_do when cpu_rwn='0' else DI;
	
	cpu : work.T65
	port map
	(
		Mode  => "00",
		Res_n => not RESET,
		Enable => CPU_ENABLE,
		Clk => CLK,
		Rdy => RDY,
		Abort_n => '1',
		IRQ_n => IRQ_n,
		NMI_n => NMI_n,
		SO_n => '1',
		R_W_n => cpu_rwn,
		A => addr,
		DI => cpu_di,
		DO => cpu_do
	);	
	
	A <= addr(15 downto 0);
		
	CPU_FETCH <= ENABLE and THROTTLE;

END vhdl;
