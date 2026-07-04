LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_MISC.all;

ENTITY sid_data IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

    SID1_ROM_ADDRESS : in std_logic_vector(16 downto 0);
	SID1_ROM_REQUEST : in std_logic;
	SID1_ROM_READY : out std_logic;
	SID1_ROM_READ_DATA : out std_logic_vector(31 downto 0);

	SID2_ROM_ADDRESS : in std_logic_vector(16 downto 0);
	SID2_ROM_REQUEST : in std_logic;
	SID2_ROM_READY : out std_logic;
	SID2_ROM_READ_DATA : out std_logic_vector(31 downto 0);

    SID_ROM_ADDRESS : out std_logic_vector(16 downto 0);
	SID_ROM_REQUEST : out std_logic;
	SID_ROM_READY : in std_logic;
	SID_ROM_READ_DATA : in std_logic_vector(31 downto 0)
);
END sid_data;

ARCHITECTURE vhdl OF sid_data IS

signal SID1_NEED_ROM : std_logic;
signal SID1_ACT_ROM_REQUEST : std_logic;
signal SID2_NEED_ROM : std_logic;
signal SID2_ACT_ROM_REQUEST : std_logic;
signal CURRENT_REQUEST : std_logic;
signal alt_reg : std_logic;
signal alt_next : std_logic;

BEGIN

SID1_ACT_ROM_REQUEST <= SID1_ROM_REQUEST and SID1_NEED_ROM;
SID2_ACT_ROM_REQUEST <= SID2_ROM_REQUEST and SID2_NEED_ROM;

SID_ROM_REQUEST <= SID1_ACT_ROM_REQUEST or SID2_ACT_ROM_REQUEST;
SID1_NEED_ROM <= '1';
SID2_NEED_ROM <= '1';

process(alt_reg, SID1_ACT_ROM_REQUEST, SID2_ACT_ROM_REQUEST) is
begin
    CURRENT_REQUEST <= alt_reg;
    if (SID1_ACT_ROM_REQUEST xor SID2_ACT_ROM_REQUEST) = '1' then
        CURRENT_REQUEST <= SID2_ACT_ROM_REQUEST;
    end if;
end process;

SID_ROM_ADDRESS <= SID2_ROM_ADDRESS(14 downto 0) & "00" when CURRENT_REQUEST = '1' else SID1_ROM_ADDRESS(14 downto 0) & "00";
SID1_ROM_READ_DATA <= SID_ROM_READ_DATA;
SID2_ROM_READ_DATA <= SID_ROM_READ_DATA;

process(alt_reg, SID_ROM_READY, SID1_NEED_ROM, SID2_NEED_ROM, SID1_ROM_REQUEST, SID2_ROM_REQUEST, CURRENT_REQUEST) is
begin
    SID1_ROM_READY <= not(SID1_NEED_ROM) and SID1_ROM_REQUEST;
    SID2_ROM_READY <= not(SID2_NEED_ROM) and SID2_ROM_REQUEST;
    alt_next <= alt_reg;
    if SID_ROM_READY = '1' then
        -- alt_next <= not(CURRENT_REQUEST);
        if CURRENT_REQUEST = '1' then
            SID2_ROM_READY <= '1';
            alt_next <= '0';
        else
            SID1_ROM_READY <= '1';
            alt_next <= '1';
        end if;
    end if;
end process;

process(clk, reset_n) is
begin
    if reset_n = '0' then
        alt_reg <= '0';
    elsif rising_edge(clk) then
        alt_reg <= alt_next;
    end if;
end process;

END vhdl;