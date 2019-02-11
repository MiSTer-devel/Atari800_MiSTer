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
	signal cpu_enable: std_logic; -- Apply Antic HALT and throttle

	-- Support for Peter's core (NMI patch applied)
	signal we : std_logic;
	signal nmi_pending_next : std_logic; -- NMI during RDY
	signal nmi_pending_reg : std_logic;
	signal nmi_n_adjusted : std_logic;
	signal nmi_n_reg : std_logic;
	signal nmi_edge : std_logic;

	signal addr : std_logic_vector(23 downto 0);
	signal cpu_do : std_logic_vector(7 downto 0);
	signal cpu_di : std_logic_vector(7 downto 0);
	signal cpu_rwn : std_logic;
BEGIN
	cpu_enable <= ENABLE and MEMORY_READY and THROTTLE;
	
	-- CPU designed by Peter W - as used in Chameleon
	cpu_6502_peter: work.cpu_65xx
	generic map
	(
		pipelineOpcode => false,
		pipelineAluMux => false,
		pipelineAluOut => false
	)
	port map (
		clk => clk,
		enable => (cpu_enable and (RDY or we)) or reset,
		halt => '0',
		reset=>reset,
		nmi_n=>nmi_n_adjusted,
		irq_n=>irq_n,
		d=>unsigned(di),
		std_logic_vector(q)=>do,
		std_logic_vector(addr)=>a,
		WE=>we
	);

	nmi_edge <= not(nmi_n) and nmi_n_reg;
	nmi_pending_next <= (nmi_edge and not(RDY or we)) or (nmi_pending_reg and not(RDY)) or (nmi_pending_reg and RDY and not(cpu_enable));
	nmi_n_adjusted <= not(nmi_pending_reg) and nmi_n;

	-- register
	process(clk,reset)
	begin
		if (RESET = '1') then
			nmi_pending_reg <= '0';
			nmi_n_reg <= '1';
		elsif rising_edge(clk) then
			nmi_pending_reg <= nmi_pending_next;
			nmi_n_reg <= nmi_n;
		end if;
	end process;	

	-- outputs
	r_w_n <= not(we);
	CPU_FETCH <= ENABLE and THROTTLE;

--	DO <= cpu_do;
--	R_W_n <= cpu_rwn;
--
--	cpu_di <= cpu_do when cpu_rwn='0' else DI;
--	
--	cpu : work.T65
--	port map
--	(
--		Mode  => "00",
--		Res_n => not RESET,
--		Enable => cpu_enable,
--		Clk => CLK,
--		Rdy => RDY,
--		Abort_n => '1',
--		IRQ_n => IRQ_n,
--		NMI_n => NMI_n,
--		SO_n => '1',
--		R_W_n => cpu_rwn,
--		A => addr,
--		DI => cpu_di,
--		DO => cpu_do
--	);	
--
--	A <= addr(15 downto 0);

END vhdl;
