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

function sid_q(x: unsigned(4 downto 0)) return unsigned is
begin
	case x is
		when "00000" => return "01011010100000101";
		when "00001" => return "01010010111111111";
		when "00010" => return "01001100000111000";
		when "00011" => return "01000101110010110";
		when "00100" => return "01000000000000000";
		when "00101" => return "00111010101100000";
		when "00110" => return "00110101110100010";
		when "00111" => return "00110001010110100";
		when "01000" => return "00101101010000010";
		when "01001" => return "00101001011111111";
		when "01010" => return "00100110000011100";
		when "01011" => return "00100010111001011";
		when "01100" => return "00100000000000000";
		when "01101" => return "00011101010110000";
		when "01110" => return "00011010111010001";
		when "01111" => return "00011000101011010";
		when "10000" => return "10000000000000000";
		when "10001" => return "01110011001100110";
		when "10010" => return "01101000101110100";
		when "10011" => return "01100000000000000";
		when "10100" => return "01011000100111011";
		when "10101" => return "01010010010010010";
		when "10110" => return "01001100110011010";
		when "10111" => return "01001000000000000";
		when "11000" => return "01000011110001000";
		when "11001" => return "01000000000000000";
		when "11010" => return "00111100101000011";
		when "11011" => return "00111001100110011";
		when "11100" => return "00110110110110111";
		when "11101" => return "00110100010111010";
		when "11110" => return "00110010000101101";
		when "11111" => return "00110000000000000";
	end case;
end sid_q;

signal SID1_NEED_ROM : std_logic;
signal SID1_ACT_ROM_REQUEST : std_logic;
signal SID2_NEED_ROM : std_logic;
signal SID2_ACT_ROM_REQUEST : std_logic;
signal SID_Q_ROM_ADDRESS : std_logic_vector(4 downto 0);
signal SID_Q_DATA : std_logic_vector(16 downto 0);
signal CURRENT_REQUEST : std_logic;
signal alt_reg : std_logic;
signal alt_next : std_logic;

BEGIN

SID1_ACT_ROM_REQUEST <= SID1_ROM_REQUEST and SID1_NEED_ROM;
SID2_ACT_ROM_REQUEST <= SID2_ROM_REQUEST and SID2_NEED_ROM;

SID_ROM_REQUEST <= SID1_ACT_ROM_REQUEST or SID2_ACT_ROM_REQUEST;
SID1_NEED_ROM <= '0' when SID1_ROM_ADDRESS(16 downto 9) = "00000001" else '1';
SID2_NEED_ROM <= '0' when SID2_ROM_ADDRESS(16 downto 9) = "00000001" else '1';

process(alt_reg, SID1_ACT_ROM_REQUEST, SID2_ACT_ROM_REQUEST) is
begin
    CURRENT_REQUEST <= alt_reg;
    if (SID1_ACT_ROM_REQUEST xor SID2_ACT_ROM_REQUEST) = '1' then
        CURRENT_REQUEST <= SID2_ACT_ROM_REQUEST;
    end if;
end process;

SID_ROM_ADDRESS <= SID2_ROM_ADDRESS(14 downto 0) & "00" when CURRENT_REQUEST = '1' else SID1_ROM_ADDRESS(14 downto 0) & "00";

SID_Q_ROM_ADDRESS <= SID2_ROM_ADDRESS(4 downto 0) when SID2_ROM_REQUEST = '1' else SID1_ROM_ADDRESS(4 downto 0);

SID_Q_DATA <= std_logic_vector(sid_q(unsigned(SID_Q_ROM_ADDRESS)));

SID1_ROM_READ_DATA <= SID_ROM_READ_DATA when SID1_NEED_ROM = '1' else "000000000000000"&SID_Q_DATA;
SID2_ROM_READ_DATA <= SID_ROM_READ_DATA when SID2_NEED_ROM = '1' else "000000000000000"&SID_Q_DATA;

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