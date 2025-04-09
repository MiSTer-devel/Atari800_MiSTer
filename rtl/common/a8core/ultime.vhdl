library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DS1305Redux is
port (
	clk : in std_logic;
	reset_n : in std_logic;
	data_in: in std_logic_vector(7 downto 0);
	wr_en: in std_logic;
	data_out: out std_logic_vector(7 downto 0)
	--reset_init: in std_logic; -- from hps_io / MiSTer core init
	-- also init input from hps_io
);
end DS1305Redux;

architecture vhdl of DS1305Redux is

type memory_type is array(0 to 127) of std_logic_vector(7 downto 0);

signal spi_in_reg: std_logic;
signal spi_clk_reg: std_logic;
signal spi_en_reg: std_logic;

signal spi_in_next: std_logic;
signal spi_clk_next: std_logic;
signal spi_en_next: std_logic;

signal spi_clk_old : std_logic;
signal spi_en_old : std_logic;

signal spi_out: std_logic;
signal spi_addr: std_logic_vector(6 downto 0);
signal spi_addr_count: std_logic_vector(2 downto 0);
signal spi_addr_ready: std_logic;
signal data_count: std_logic_vector(2 downto 0);
signal spi_write: std_logic;

signal memory: memory_type; -- The actual clock needs separate space and process
signal write_protect : std_logic;

begin

data_out <= "0000" & spi_out & "000";
write_protect <= memory(15)(6);

process(wr_en, data_in, spi_en_reg, spi_clk_reg, spi_in_reg)
begin
	spi_en_next <= spi_en_reg;
	spi_clk_next <= spi_clk_reg;
	spi_in_next <= spi_in_reg;
	if wr_en = '1' then
		spi_en_next <= data_in(0);
		spi_clk_next <= data_in(1);
		spi_in_next <= data_in(2);
	end if;
end process;

process(clk, reset_n)
begin
	if (reset_n = '0') then
		spi_en_reg <= '0';
		spi_clk_reg <= '0';
		spi_in_reg <= '0';
	elsif rising_edge(clk) then
		spi_en_reg <= spi_en_next;
		spi_clk_reg <= spi_clk_next;
		spi_in_reg <= spi_in_next;
	end if;
end process;

process(clk, reset_n)
begin
	if (reset_n = '0') then
		spi_addr_ready <= '0';
		spi_write <= '0';
		spi_out <= '1';
		spi_en_old <= '0';
		spi_clk_old <= '0';
	elsif rising_edge(clk) then
		spi_en_old <= spi_en_reg;
		spi_clk_old <= spi_clk_reg;
		if (spi_en_reg = '1') then
			if spi_en_old = '0' then
				spi_addr_count <= "111";
				data_count <= "111";
				spi_addr_ready <= '0';
				spi_out <= '1';
				spi_write <= '0';
			elsif (spi_clk_old = '0') and (spi_clk_reg = '1') then
				if spi_addr_ready = '0' then
					if spi_addr_count = "111" then
						spi_write <= spi_in_reg;
					else
						spi_addr(to_integer(unsigned(spi_addr_count))) <= spi_in_reg;
					end if;
					if spi_addr_count = "000" then
						spi_addr_ready <= '1'; -- set data_count here?
					else
						spi_addr_count <= std_logic_vector(unsigned(spi_addr_count)-1);
					end if;
				else
					if (spi_write = '1') then
						if ((write_protect = '0') or (spi_addr = "0001111") or (spi_addr(6 downto 5) /= "00")) then
							memory(to_integer(unsigned(spi_addr)))(to_integer(unsigned(data_count))) <= spi_in_reg;
						end if;
					else
						if spi_addr = "0010000" then -- 0x10 status register, all 0 (no interrupts here)
							spi_out <= '0';
						else
							spi_out <= memory(to_integer(unsigned(spi_addr)))(to_integer(unsigned(data_count)));
						end if;
					end if;
					if (data_count = "000") then
						if spi_addr = "0011111" then -- 0x1F?
							spi_addr <= "0000000";
						elsif spi_addr = "1111111" then -- 0x7F?
							spi_addr <= "0100000"; -- 0x20
						else
							spi_addr <= std_logic_vector(unsigned(spi_addr)+1);
						end if;
					end if;
					data_count <= std_logic_vector(unsigned(data_count)-1);
				end if;
			end if;
		end if;
	end if;

end process;

end vhdl;