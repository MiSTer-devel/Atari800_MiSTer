library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DS1305Redux is
port (
	clk : in std_logic;
	reset_n : in std_logic;
	data_in: in std_logic_vector(7 downto 0);
	wr_en: in std_logic;
	data_out: out std_logic_vector(7 downto 0);
	rtc_in: in std_logic_vector(64 downto 0)
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

signal memory: memory_type;
signal write_protect : std_logic;

type clock_type is array(0 to 6) of std_logic_vector(7 downto 0);
signal rt_clock: clock_type;
signal seconds_tick : std_logic;
signal clock_update_flip : std_logic;
signal clock_update_flip_old : std_logic;
signal rtc_in_set_old: std_logic;

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
	variable clock_updated : boolean;
begin
	if (reset_n = '0') then
		spi_addr_ready <= '0';
		spi_write <= '0';
		spi_out <= '1';
		spi_en_old <= '0';
		spi_clk_old <= '0';
		clock_updated := false;
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
						spi_addr_ready <= '1';
					else
						spi_addr_count <= std_logic_vector(unsigned(spi_addr_count)-1);
					end if;
				else
					if (spi_write = '1') then
						-- To write either the protection has to be lifted, or we write to the config register
						-- or to RAM
						if ((write_protect = '0') or (spi_addr = "0001111") or (spi_addr(6 downto 5) /= "00")) then
							memory(to_integer(unsigned(spi_addr)))(to_integer(unsigned(data_count))) <= spi_in_reg;
							if spi_addr(6 downto 3) = "0000" then
								clock_updated := true;
							end if;
						end if;
					else
						if spi_addr = "0010000" then -- 0x10 status register, all 0 (no interrupts here)
							spi_out <= '0';
						elsif spi_addr(6 downto 3) = "0000" then
							spi_out <= rt_clock(to_integer(unsigned(spi_addr)))(to_integer(unsigned(data_count)));
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
		else
			if spi_en_old = '1' then
				if clock_updated then
					clock_updated := false;
					clock_update_flip <= not(clock_update_flip);
				end if;
			end if;
		end if;
	end if;

end process;

process(clk)
	variable clk_counter : integer := 0;
begin
	if rising_edge(clk) then
		seconds_tick <= '0';
		if clk_counter = 28636364 then
			seconds_tick <= '1';
			clk_counter := 0;
		else
			clk_counter := clk_counter + 1;
		end if;
	end if;
end process;

process(clk)
	variable update_minutes : boolean;
	variable update_hours : boolean;
	variable update_day : boolean;
	variable update_month : boolean;
	variable update_year : boolean;
	variable leap_year : boolean;
	variable short_month : boolean;
	variable last_day : boolean;
begin
	if rising_edge(clk) then
		-- check for update from system, then memory buffer, else tick
		clock_update_flip_old <= clock_update_flip;
		rtc_in_set_old <= rtc_in(64);
		if rtc_in(64) /= rtc_in_set_old then
			rt_clock(0) <= rtc_in(7 downto 0); -- seconds
			rt_clock(1) <= rtc_in(15 downto 8); -- minutes
			rt_clock(2) <= rtc_in(23 downto 16); -- hour
			rt_clock(3) <= rtc_in(55 downto 48); -- week day
			rt_clock(4) <= rtc_in(31 downto 24); -- day
			rt_clock(5) <= rtc_in(39 downto 32); -- month
			rt_clock(6) <= rtc_in(47 downto 40); -- year 
		elsif clock_update_flip /= clock_update_flip_old then
			rt_clock(0) <= memory(0);
			rt_clock(1) <= memory(1);
			rt_clock(2) <= memory(2);
			rt_clock(3) <= memory(3);
			rt_clock(4) <= memory(4);
			rt_clock(5) <= memory(5);
			rt_clock(6) <= memory(6);
		elsif seconds_tick = '1' then
			update_minutes := false;
			if rt_clock(0)(3 downto 0) = x"9" then
				rt_clock(0)(3 downto 0) <= x"0";
				if rt_clock(0)(7 downto 4) = x"5" then
					rt_clock(0)(7 downto 4) <= x"0";
					update_minutes := true;
				else
					rt_clock(0)(7 downto 4) <= std_logic_vector(unsigned(rt_clock(0)(7 downto 4)) + 1);
				end if;
			else
				rt_clock(0)(3 downto 0) <= std_logic_vector(unsigned(rt_clock(0)(3 downto 0)) + 1);
			end if;
			update_hours := false;
			if update_minutes then
				if rt_clock(1)(3 downto 0) = x"9" then
					rt_clock(1)(3 downto 0) <= x"0";
					if rt_clock(1)(7 downto 4) = x"5" then
						rt_clock(1)(7 downto 4) <= x"0";
						update_hours := true;
					else
						rt_clock(1)(7 downto 4) <= std_logic_vector(unsigned(rt_clock(1)(7 downto 4)) + 1);
					end if;
				else
					rt_clock(1)(3 downto 0) <= std_logic_vector(unsigned(rt_clock(1)(3 downto 0)) + 1);
				end if;
			end if;
			update_day := false;
			if update_hours then
				if rt_clock(2) = x"23" then
					rt_clock(2) <= x"00";
					update_day := true;
				elsif rt_clock(2)(3 downto 0) = x"9" then
					rt_clock(2)(3 downto 0) <= x"0";
					rt_clock(2)(7 downto 4) <= std_logic_vector(unsigned(rt_clock(2)(7 downto 4)) + 1);
				else
					rt_clock(2)(3 downto 0) <= std_logic_vector(unsigned(rt_clock(2)(3 downto 0)) + 1);
				end if;
			end if;
			update_month := false;
			if update_day then
				leap_year := (rt_clock(6)(4 downto 0) = "10110") or (rt_clock(6)(4 downto 0) = "10010") or (rt_clock(6)(4 downto 0) = "01000") or (rt_clock(6)(4 downto 0) = "00100") or (rt_clock(6)(4 downto 0) = "00000");
				short_month := (rt_clock(5) = x"04") or (rt_clock(5) = x"06") or (rt_clock(5) = x"09") or (rt_clock(5) = x"11");
				last_day := (rt_clock(4) = x"31") or (short_month and (rt_clock(4) = x"30")) or (rt_clock(5) = x"02" and ((leap_year and (rt_clock(4) = x"29")) or (not(leap_year) and (rt_clock(4) = x"28"))));
				if last_day then
					rt_clock(4) <= x"01";
					update_month := true;
				elsif rt_clock(4)(3 downto 0) = x"9" then
					rt_clock(4)(3 downto 0) <= x"0";
					rt_clock(4)(7 downto 4) <= std_logic_vector(unsigned(rt_clock(4)(7 downto 4)) + 1);
				else
					rt_clock(4)(3 downto 0) <= std_logic_vector(unsigned(rt_clock(4)(3 downto 0)) + 1);
				end if;
				if rt_clock(3)(3 downto 0) = x"7" then
					rt_clock(3)(3 downto 0) <= x"1";
				else
					rt_clock(3)(3 downto 0) <= std_logic_vector(unsigned(rt_clock(3)(3 downto 0)) + 1);
				end if;
			end if;
			update_year := false;
			if update_month then
				if rt_clock(5) = x"12" then
					rt_clock(5) <= x"01";
					update_year := true;
				elsif rt_clock(5)(3 downto 0) = x"9" then
					rt_clock(5) <= x"10";
				else
					rt_clock(5)(3 downto 0) <= std_logic_vector(unsigned(rt_clock(5)(3 downto 0)) + 1);
				end if;
			end if;
			if update_year then
				-- wrapping around from 99 to 0 will most probably produce a wrong 
				-- state on the day of the week, but we don't care, the whole clock 
				-- should be considered ill-formed at this point!
				if rt_clock(6)(3 downto 0) = x"9" then
					rt_clock(6)(3 downto 0) <= x"0";
					if rt_clock(6)(7 downto 4) = x"9" then
						rt_clock(6)(7 downto 4) <= x"0";
					else
						rt_clock(6)(7 downto 4) <= std_logic_vector(unsigned(rt_clock(6)(7 downto 4)) + 1);
					end if;
				else
					rt_clock(6)(3 downto 0) <= std_logic_vector(unsigned(rt_clock(6)(3 downto 0)) + 1);
				end if;
			end if;
		end if;
	end if;
end process;

end vhdl;