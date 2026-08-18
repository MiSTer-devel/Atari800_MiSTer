LIBRARY ieee;

USE ieee.std_logic_1164.ALL;

-- This module (tightly) squeezes out 512K of RAM from the Cyclone V BRAM blocks, to be used by VBXE

ENTITY large_bram IS
   PORT
   (
      clk:      IN std_logic;
      reset_n:    IN std_logic := '1';
      data:       IN std_logic_vector(7 DOWNTO 0);
      address:    IN std_logic_vector(18 downto 0);
      req:        IN std_logic;
      we:         IN std_logic;
      ready:      OUT std_logic;
      q:          OUT std_logic_vector(7 DOWNTO 0)
   );
END large_bram;

ARCHITECTURE rtl OF large_bram IS

SIGNAL data_out_low : std_logic_vector(2 downto 0);
SIGNAL data_out_high : std_logic_vector(4 downto 0);

SIGNAL request_reg : std_logic;
SIGNAL request_next : std_logic;

BEGIN

low_bits: entity work.spram
generic map(addr_width => 19, data_width => 3, mem_depth => 8192)
port map (clock => clk, address => address, data => data(2 downto 0), wren => we, q => data_out_low);

high_bits: entity work.spram
generic map(addr_width => 19, data_width => 5, mem_depth => 2048)
port map (clock => clk,	address => address, data => data(7 downto 3), wren => we, q => data_out_high);

q <= data_out_high & data_out_low;

request_next <= req;
ready <= request_reg;

process(clk, reset_n)
begin
	if reset_n = '0' then
      request_reg <= '0';
	elsif rising_edge(clk) then
      request_reg <= request_next;
   end if;
end process;

END rtl;
