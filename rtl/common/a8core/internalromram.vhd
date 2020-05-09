LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;
USE ieee.math_real.log2;
USE ieee.math_real.ceil;

ENTITY internalromram IS
	GENERIC
	(
		internal_rom : integer := 1;  
		internal_ram : integer := 16384 
	);
	PORT(
		clock   : IN STD_LOGIC;      --system clock
		reset_n : IN STD_LOGIC;      --asynchronous reset

		ROM_ADDR : in STD_LOGIC_VECTOR(21 downto 0);
		ROM_WR_ENABLE : in std_logic;
		ROM_DATA_IN : in STD_LOGIC_VECTOR(7 downto 0);
		ROM_REQUEST_COMPLETE : out STD_LOGIC;
		ROM_REQUEST : in std_logic;
		ROM_DATA : out std_logic_vector(7 downto 0);

		RAM_ADDR : in STD_LOGIC_VECTOR(18 downto 0);
		RAM_WR_ENABLE : in std_logic;
		RAM_DATA_IN : in STD_LOGIC_VECTOR(7 downto 0);
		RAM_REQUEST_COMPLETE : out STD_LOGIC;
		RAM_REQUEST : in std_logic;
		RAM_DATA : out std_logic_vector(7 downto 0)
	);
END internalromram;

architecture vhdl of internalromram is
	signal ram_request_reg : std_logic;
	signal ram_request_next : std_logic;
	
	signal RAM1_DATA,RAM2_DATA : std_logic_vector(7 downto 0);
	signal ram1_sel, ram2_sel : std_logic;
	signal ramwe_temp : std_logic;

begin

process(clock,reset_n)
begin
	if (reset_n ='0') then
		ram_request_reg <= '0';
	elsif rising_edge(clock) then
		ram_request_reg <= ram_request_next;
	end if;
end process;

ROM_DATA <= (others=>'1');
ROM_REQUEST_COMPLETE <= '1';

gen_internal_ram: if internal_ram > 0 generate
	constant ADDRESS_WIDTH : integer := integer(ceil(log2(real(internal_ram))));
begin
	ramwe_temp <= RAM_WR_ENABLE and ram_request;
	ramint1 : entity work.generic_ram_infer
	generic map	(
		ADDRESS_WIDTH => ADDRESS_WIDTH,
		SPACE => internal_ram,
		DATA_WIDTH =>8
	)
	PORT MAP (
		clock => clock,
		address => ram_addr(ADDRESS_WIDTH-1 downto 0),
		data => ram_data_in,
		we => ramwe_temp,
		q => ram_data
	);
	ram_request_next <= ram_request and not(RAM_WR_ENABLE);
	ram_request_complete <= ramwe_temp or ram_request_reg;
end generate;

gen_no_internal_ram : if internal_ram=0 generate
	ram_request_complete <='1';
	ram_data <= (others=>'1');
end generate;
        
end vhdl;
