LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_MISC.all;

use work.AudioTypes.all;

ENTITY pokeymax IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

    ENABLE_179 : in std_logic;
    ENABLE_179_DOUBLE : in std_logic;
	CLOCK_SHIFT : in std_logic_vector(15 downto 0);
	VBXE_MEMAC_ACTIVE : in std_logic;
	ADDR : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	DATA_IN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	REQUEST : IN STD_LOGIC;
	WR_EN : IN STD_LOGIC;
	DATA_OUT : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	DRIVE_DATA_OUT : OUT STD_LOGIC;

	keyboard_scan : out std_logic_vector(5 downto 0);
	keyboard_response : in std_logic_vector(1 downto 0);
	
	-- pots - go high as capacitor charges
	POT_IN : in std_logic_vector(7 downto 0);
	
	-- sio interface
	SIO_IN1 : IN std_logic;
	SIO_OUT1 : OUT std_logic;
	
	SIO_CLOCKIN_IN : IN std_logic;
	SIO_CLOCKIN_OUT : OUT std_logic;
	SIO_CLOCKIN_OE : OUT std_logic;
	SIO_CLOCKOUT : OUT std_logic;
	
	IRQ_N_OUT : OUT std_logic;
	
    -- OSD config
    STEREO : in STD_LOGIC;

    -- sound sources
    GTIA_SOUND : IN STD_LOGIC;
	SIO_SOUND : IN STD_LOGIC_VECTOR(7 downto 0);

    -- sound output
    AUDIO_L : OUT STD_LOGIC_VECTOR(15 downto 0);
	AUDIO_R : OUT STD_LOGIC_VECTOR(15 downto 0);

	POT_RESET : out std_logic;

	SAMPLE_RAM_ADDRESS : out std_logic_vector(15 downto 0);
	SAMPLE_RAM_WRITE_ENABLE : out std_logic;
	SAMPLE_RAM_REQUEST : out std_logic;
	SAMPLE_RAM_READY : in std_logic;
	SAMPLE_RAM_READ_DATA : in std_logic_vector(7 downto 0);
	SAMPLE_RAM_WRITE_DATA : out std_logic_vector(7 downto 0);

	SID_ROM_ADDRESS : out std_logic_vector(16 downto 0);
	SID_ROM_REQUEST : out std_logic;
	SID_ROM_READY : in std_logic;
	SID_ROM_READ_DATA : in std_logic_vector(31 downto 0)
);
END pokeymax;

ARCHITECTURE vhdl OF pokeymax IS

-- WRITE ENABLES
SIGNAL POKEY_WRITE_ENABLE : STD_LOGIC_VECTOR(3 downto 0);		
	
SIGNAL SID_WRITE_ENABLE : STD_LOGIC_VECTOR(1 downto 0);	
SIGNAL SID_READ_ENABLE : STD_LOGIC_VECTOR(1 downto 0);	

SIGNAL PSG_WRITE_ENABLE : STD_LOGIC_VECTOR(1 downto 0);	

SIGNAL SAMPLE_WRITE_ENABLE : STD_LOGIC;	
SIGNAL CONFIG_WRITE_ENABLE : STD_LOGIC;	
	
-- DATA OUTS
type DO_TYPE is array (NATURAL range <>) of std_logic_vector(7 downto 0);
	
SIGNAL POKEY_DO : DO_TYPE(3 downto 0);	
	
SIGNAL SID_DO : DO_TYPE(1 downto 0);
SIGNAL SID_DRIVE_DO : std_logic_vector(1 downto 0);
	
SIGNAL PSG_DO : DO_TYPE(1 DOWNTO 0);	
	
SIGNAL SAMPLE_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);	
SIGNAL CONFIG_DO : STD_LOGIC_VECTOR(7 DOWNTO 0);	
	
-- POKEY	
signal POKEY_CHANNEL0 : POKEY_AUDIO(3 downto 0);
signal POKEY_CHANNEL1 : POKEY_AUDIO(3 downto 0);
signal POKEY_CHANNEL2 : POKEY_AUDIO(3 downto 0);
signal POKEY_CHANNEL3 : POKEY_AUDIO(3 downto 0);

signal CHANNEL0SUM_NEXT : unsigned(5 downto 0);	
signal CHANNEL1SUM_NEXT : unsigned(5 downto 0);
signal CHANNEL2SUM_NEXT : unsigned(5 downto 0);
signal CHANNEL3SUM_NEXT : unsigned(5 downto 0);
signal CHANNEL0SUM_REG : unsigned(5 downto 0);	
signal CHANNEL1SUM_REG : unsigned(5 downto 0);
signal CHANNEL2SUM_REG : unsigned(5 downto 0);
signal CHANNEL3SUM_REG : unsigned(5 downto 0);	

signal POKEY_AUDIO_UNSIGNED : UNSIGNED_AUDIO_TYPE(3 downto 0);
signal POKEY_AUDIO_SIGNED : SIGNED_AUDIO_TYPE(3 downto 0);

signal GTIA_AUDIO_SIGNED : signed(15 downto 0);

signal SIO_AUDIO_UNSIGNED : unsigned(15 downto 0);
signal SIO_AUDIO_SIGNED : signed(15 downto 0);

signal AUDIO_MIXED_SIGNED : SIGNED_AUDIO_TYPE(3 downto 2);

signal POKEY_IRQ : std_logic_vector(3 downto 0);

SIGNAL	ADDR_IN : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	WRITE_DATA : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	WRITE_N : STD_LOGIC;
SIGNAL	DEVICE_ADDR : STD_LOGIC_VECTOR(3 downto 0);
SIGNAL	DO_MUX : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	DRIVE_DO_MUX : STD_LOGIC;
signal	readreq_s : std_logic;
signal	writereq_s : std_logic;

-- SID
signal SID_CLK_ENABLE : std_logic;
signal SID_AUDIO_SIGNED : SIGNED_AUDIO_TYPE(1 downto 0);
signal SID_AUDIO_IN_SIGNED : SIGNED_AUDIO_TYPE(1 downto 0);
signal SID_FLASH1_ADDR : std_logic_vector(16 downto 0);
signal SID_FLASH1_ROMREQUEST : std_logic;
signal SID_FLASH1_ROMREADY : std_logic;
signal SID_FLASH2_ADDR : std_logic_vector(16 downto 0);
signal SID_FLASH2_ROMREQUEST : std_logic;
signal SID_FLASH2_ROMREADY : std_logic;
signal SID_FILTER1_REG : std_logic_vector(2 downto 0);
signal SID_FILTER1_NEXT : std_logic_vector(2 downto 0);
signal SID_FILTER2_REG : std_logic_vector(2 downto 0);
signal SID_FILTER2_NEXT : std_logic_vector(2 downto 0);
signal SID1_FILTER_BP : signed(17 downto 8);
signal SID1_FILTER_HP : signed(17 downto 8);
signal SID1_F_RAW : std_logic_vector(12 downto 0);
signal SID1_F_BP : unsigned(12 downto 0);
signal SID1_F_HP : unsigned(12 downto 0);
signal SID2_FILTER_BP : signed(17 downto 8);
signal SID2_FILTER_HP : signed(17 downto 8);
signal SID2_F_RAW : std_logic_vector(12 downto 0);
signal SID2_F_BP : unsigned(12 downto 0);
signal SID2_F_HP : unsigned(12 downto 0);

	-- SAMPLE/COVOX
signal SAMPLE_AUDIO_SIGNED : SIGNED_AUDIO_TYPE(1 downto 0);	
signal SAMPLE_AUDIO_IN_SIGNED : SIGNED_AUDIO_TYPE(3 downto 0);

signal FANCY_ENABLE : std_logic;

signal SAMPLE_IRQ : std_logic;
signal SAMPLE_RAM_REQUEST_RAW : std_logic;

-- config
-- regs
signal DETECT_RIGHT_REG : std_logic;
signal IRQ_EN_REG : std_logic;
signal CHANNEL_MODE_REG : std_logic;
signal SATURATE_REG : std_logic;
signal POST_DIVIDE_REG : std_logic_vector(7 downto 4);	
signal GTIA_ENABLE_REG : std_logic_vector(3 downto 2);
signal ADC_VOLUME_REG : std_logic_vector(1 downto 0);
--signal SIO_DATA_VOLUME_REG : std_logic_vector(1 downto 0);
signal VERSION_LOC_REG : std_logic_vector(2 downto 0);
signal PAL_REG : std_logic;
	
signal DETECT_RIGHT_NEXT : std_logic;
signal IRQ_EN_NEXT : std_logic;
signal CHANNEL_MODE_NEXT : std_logic;
signal SATURATE_NEXT : std_logic;
signal POST_DIVIDE_NEXT : std_logic_vector(7 downto 4);
signal GTIA_ENABLE_NEXT : std_logic_vector(3 downto 2);
signal ADC_VOLUME_NEXT : std_logic_vector(1 downto 0);
--signal SIO_DATA_VOLUME_NEXT : std_logic_vector(1 downto 0);
signal VERSION_LOC_NEXT : std_logic_vector(2 downto 0);
signal PAL_NEXT : std_logic;

-- capability restriction
signal RESTRICT_CAPABILITY_REG : std_logic_vector(4 downto 0);
signal RESTRICT_CAPABILITY_NEXT : std_logic_vector(4 downto 0);

-- output channel on/off
signal CHANNEL_EN_REG : std_logic_vector(3 downto 2);
signal CHANNEL_EN_NEXT : std_logic_vector(3 downto 2);
-- 2=L ext 
-- 3=R ext
	
--config infra
signal addr_decoded4 : std_logic_vector(15 downto 0);	
signal CONFIG_ENABLE_REG : std_logic;
signal CONFIG_ENABLE_NEXT: std_logic;

signal ADPCM_STEP_ADDR : std_logic_vector(6 downto 0);
signal ADPCM_STEP_VALUE : std_logic_vector(14 downto 0);
signal ADPCM_STEP_REQUEST : std_logic;

signal AUDIO_2_FILTERED : std_logic_vector(15 downto 0);
signal AUDIO_3_FILTERED : std_logic_vector(15 downto 0);

-- MIXER
signal mixer_audio_out : signed(15 downto 0);
signal mixer_l_enable : std_logic;
signal mixer_r_enable : std_logic;
signal mixer_audio_out_channel : unsigned(2 downto 0);
signal mixer_mute : std_logic;
signal MIXER_SIGNED_REG : SIGNED_AUDIO_TYPE(3 downto 0);
signal MIXER_SIGNED_NEXT : SIGNED_AUDIO_TYPE(3 downto 0);
signal MIX_SEL1_NEXT : std_logic_vector(2 downto 0);
signal MIX_SEL1_REG : std_logic_vector(2 downto 0);
signal MIX_SEL2_NEXT : std_logic_vector(2 downto 0);
signal MIX_SEL2_REG : std_logic_vector(2 downto 0);

signal SID1_ROM_ADDRESS : std_logic_vector(16 downto 0);
signal SID1_ROM_REQUEST : std_logic;
signal SID1_ROM_READY : std_logic;
signal SID1_ROM_READ_DATA : std_logic_vector(31 downto 0);

signal SID2_ROM_ADDRESS : std_logic_vector(16 downto 0);
signal SID2_ROM_REQUEST : std_logic;
signal SID2_ROM_READY : std_logic;
signal SID2_ROM_READ_DATA : std_logic_vector(31 downto 0);

function adpcm_step(x: unsigned(6 downto 0)) return unsigned is
begin
	case x is
		when "0000000" => return "000000000000111";
		when "0000001" => return "000000000001000";
		when "0000010" => return "000000000001001";
		when "0000011" => return "000000000001010";
		when "0000100" => return "000000000001011";
		when "0000101" => return "000000000001100";
		when "0000110" => return "000000000001101";
		when "0000111" => return "000000000001110";
		when "0001000" => return "000000000010000";
		when "0001001" => return "000000000010001";
		when "0001010" => return "000000000010011";
		when "0001011" => return "000000000010101";
		when "0001100" => return "000000000010111";
		when "0001101" => return "000000000011001";
		when "0001110" => return "000000000011100";
		when "0001111" => return "000000000011111";
		when "0010000" => return "000000000100010";
		when "0010001" => return "000000000100101";
		when "0010010" => return "000000000101001";
		when "0010011" => return "000000000101101";
		when "0010100" => return "000000000110010";
		when "0010101" => return "000000000110111";
		when "0010110" => return "000000000111100";
		when "0010111" => return "000000001000010";
		when "0011000" => return "000000001001001";
		when "0011001" => return "000000001010000";
		when "0011010" => return "000000001011000";
		when "0011011" => return "000000001100001";
		when "0011100" => return "000000001101011";
		when "0011101" => return "000000001110110";
		when "0011110" => return "000000010000010";
		when "0011111" => return "000000010001111";
		when "0100000" => return "000000010011101";
		when "0100001" => return "000000010101101";
		when "0100010" => return "000000010111110";
		when "0100011" => return "000000011010001";
		when "0100100" => return "000000011100110";
		when "0100101" => return "000000011111101";
		when "0100110" => return "000000100010111";
		when "0100111" => return "000000100110011";
		when "0101000" => return "000000101010001";
		when "0101001" => return "000000101110011";
		when "0101010" => return "000000110011000";
		when "0101011" => return "000000111000001";
		when "0101100" => return "000000111101110";
		when "0101101" => return "000001000100000";
		when "0101110" => return "000001001010110";
		when "0101111" => return "000001010010010";
		when "0110000" => return "000001011010100";
		when "0110001" => return "000001100011100";
		when "0110010" => return "000001101101100";
		when "0110011" => return "000001111000011";
		when "0110100" => return "000010000100100";
		when "0110101" => return "000010010001110";
		when "0110110" => return "000010100000010";
		when "0110111" => return "000010110000011";
		when "0111000" => return "000011000010000";
		when "0111001" => return "000011010101011";
		when "0111010" => return "000011101010110";
		when "0111011" => return "000100000010010";
		when "0111100" => return "000100011100000";
		when "0111101" => return "000100111000011";
		when "0111110" => return "000101010111101";
		when "0111111" => return "000101111010000";
		when "1000000" => return "000110011111111";
		when "1000001" => return "000111001001100";
		when "1000010" => return "000111110111010";
		when "1000011" => return "001000101001100";
		when "1000100" => return "001001100000111";
		when "1000101" => return "001010011101110";
		when "1000110" => return "001011100000110";
		when "1000111" => return "001100101010100";
		when "1001000" => return "001101111011100";
		when "1001001" => return "001111010100101";
		when "1001010" => return "010000110110110";
		when "1001011" => return "010010100010101";
		when "1001100" => return "010100011001010";
		when "1001101" => return "010110011011111";
		when "1001110" => return "011000101011011";
		when "1001111" => return "011011001001011";
		when "1010000" => return "011101110111001";
		when "1010001" => return "100000110110010";
		when "1010010" => return "100100001000100";
		when "1010011" => return "100111101111110";
		when "1010100" => return "101011101110001";
		when "1010101" => return "110000000101111";
		when "1010110" => return "110100111001110";
		when "1010111" => return "111010001100010";
		when "1011000" => return "111111111111111";
		when others => return "000000000000000";
	end case;
end adpcm_step;

signal POKEY_PROFILE_ADDR : std_logic_vector(5 downto 0);
signal POKEY_PROFILE_REQUEST : std_logic;
signal POKEY_PROFILE_DATA : std_logic_vector(15 downto 0);

function pokey_volume(x: unsigned(5 downto 0)) return unsigned is
begin
	case x is
		when "000000" => return x"0022";
		when "000001" => return x"0993";
		when "000010" => return x"135E";
		when "000011" => return x"1D9A";
		when "000100" => return x"2842";
		when "000101" => return x"3345";
		when "000110" => return x"3E84";
		when "000111" => return x"49E0";
		when "001000" => return x"5538";
		when "001001" => return x"606E";
		when "001010" => return x"6B69";
		when "001011" => return x"7612";
		when "001100" => return x"805A";
		when "001101" => return x"8A34";
		when "001110" => return x"9399";
		when "001111" => return x"9C84";
		when "010000" => return x"A4F4";
		when "010001" => return x"ACEA";
		when "010010" => return x"B468";
		when "010011" => return x"BB70";
		when "010100" => return x"C207";
		when "010101" => return x"C830";
		when "010110" => return x"CDEE";
		when "010111" => return x"D343";
		when "011000" => return x"D833";
		when "011001" => return x"DCC0";
		when "011010" => return x"E0EB";
		when "011011" => return x"E4B6";
		when "011100" => return x"E824";
		when "011101" => return x"EB36";
		when "011110" => return x"EDEF";
		when "011111" => return x"F053";
		when "100000" => return x"F265";
		when "100001" => return x"F42B";
		when "100010" => return x"F5AB";
		when "100011" => return x"F6E9";
		when "100100" => return x"F7EF";
		when "100101" => return x"F8C3";
		when "100110" => return x"F96D";
		when "100111" => return x"F9F4";
		when "101000" => return x"FA61";
		when "101001" => return x"FABB";
		when "101010" => return x"FB07";
		when "101011" => return x"FB4C";
		when "101100" => return x"FB8D";
		when "101101" => return x"FBCE";
		when "101110" => return x"FC11";
		when "101111" => return x"FC56";
		when "110000" => return x"FC9F";
		when "110001" => return x"FCEA";
		when "110010" => return x"FD37";
		when "110011" => return x"FD85";
		when "110100" => return x"FDD5";
		when "110101" => return x"FE28";
		when "110110" => return x"FE82";
		when "110111" => return x"FEE7";
		when "111000" => return x"FF5D";
		when "111001" => return x"FFEB";
		when others => return x"FFFF";
	end case;
end pokey_volume;

function signed_to_unsigned(audio_in : signed(15 downto 0)) return unsigned is
	variable ret : std_logic_vector(15 downto 0);
begin
        ret(15) := not(audio_in(15));
        ret(14 downto 0) := std_logic_vector(audio_in(14 downto 0));
    return unsigned(ret);
end function signed_to_unsigned;

BEGIN

pokey1 : entity work.pokey
PORT MAP(CLK => CLK,
	ENABLE_179 => ENABLE_179,
	WR_EN => POKEY_WRITE_ENABLE(0),
	RESET_N => RESET_N,
	SIO_IN1 => SIO_IN1,
	SIO_CLOCKIN_IN => SIO_CLOCKIN_IN,
	SIO_CLOCKIN_OUT => SIO_CLOCKIN_OUT,
	SIO_CLOCKIN_OE => SIO_CLOCKIN_OE,
	ADDR => ADDR_IN(3 DOWNTO 0),
	DATA_IN => WRITE_DATA,
	keyboard_response => KEYBOARD_RESPONSE,
	POT_IN => POT_IN,
	IRQ_N_OUT => POKEY_IRQ(0),
	SIO_OUT1 => SIO_OUT1,
	SIO_OUT2 => open,
	SIO_OUT3 => open,
	SIO_CLOCKOUT => SIO_CLOCKOUT,
	POT_RESET => POT_RESET,
	CHANNEL_0_OUT => POKEY_CHANNEL0(0),
	CHANNEL_1_OUT => POKEY_CHANNEL1(0),
	CHANNEL_2_OUT => POKEY_CHANNEL2(0),
	CHANNEL_3_OUT => POKEY_CHANNEL3(0),
	DATA_OUT => POKEY_DO(0),
	keyboard_scan => KEYBOARD_SCAN);

pokey1_dc_blocker : entity work.dc_blocker_pm
PORT MAP(CLK => CLK,
	RESET_N => RESET_N,
	ENABLE_CYCLE => ENABLE_179,
	AUDIO_IN => POKEY_AUDIO_UNSIGNED(0),
	AUDIO_OUT => POKEY_AUDIO_SIGNED(0));

other_pokeys: for I in 1 to 3 generate
	pokeyx : entity work.pokey
	GENERIC MAP (custom_keyboard_scan => 2)
	PORT MAP(CLK => CLK,
		ENABLE_179 => ENABLE_179,
		WR_EN => POKEY_WRITE_ENABLE(I),
		RESET_N => RESET_N,
		ADDR => ADDR_IN(3 DOWNTO 0),
		DATA_IN => WRITE_DATA,
		IRQ_N_OUT => POKEY_IRQ(I),
		CHANNEL_0_OUT => POKEY_CHANNEL0(I),
		CHANNEL_1_OUT => POKEY_CHANNEL1(I),
		CHANNEL_2_OUT => POKEY_CHANNEL2(I),
		CHANNEL_3_OUT => POKEY_CHANNEL3(I),
		DATA_OUT => POKEY_DO(I),
		SIO_IN1 => '1',
		keyboard_response => "00",
		pot_in => "00000000");

	pokeyx_dc_blocker : entity work.dc_blocker_pm
	PORT MAP(CLK => CLK,
		RESET_N => RESET_N,
		ENABLE_CYCLE => ENABLE_179,
		AUDIO_IN => POKEY_AUDIO_UNSIGNED(I),
		AUDIO_OUT => POKEY_AUDIO_SIGNED(I));

end generate other_pokeys;

sample1 : entity work.sample_top
GENERIC MAP(enable_record => 1)
PORT MAP(
	CLK => CLK,
	RESET_N => RESET_N,

	ENABLE => ENABLE_179_DOUBLE,
	REQUEST => REQUEST,

	WRITE_ENABLE => SAMPLE_WRITE_ENABLE,
	ADDR => ADDR_IN(4 downto 0),
	DI => WRITE_DATA(7 downto 0),
	DO => SAMPLE_DO,
	AUDIO0 => SAMPLE_AUDIO_SIGNED(0),
	AUDIO1 => SAMPLE_AUDIO_SIGNED(1),
	IRQ => SAMPLE_IRQ,

	AUDIO_IN0 => SAMPLE_AUDIO_IN_SIGNED(0),
	AUDIO_IN1 => SAMPLE_AUDIO_IN_SIGNED(1),
	AUDIO_IN2 => SAMPLE_AUDIO_IN_SIGNED(2),
	AUDIO_IN3 => SAMPLE_AUDIO_IN_SIGNED(3),

	RAM_ADDR => SAMPLE_RAM_ADDRESS,
	RAM_REQUEST => SAMPLE_RAM_REQUEST_RAW,
	RAM_READY => SAMPLE_RAM_READY,
	RAM_WRITE_ENABLE => SAMPLE_RAM_WRITE_ENABLE,
	RAM_DATA => SAMPLE_RAM_READ_DATA,
	RAM_WRITE_DATA => SAMPLE_RAM_WRITE_DATA,

	ADPCM_STEP_ADDR => ADPCM_STEP_ADDR,
	ADPCM_STEP_REQUEST => ADPCM_STEP_REQUEST,
	ADPCM_STEP_READY => ADPCM_STEP_REQUEST,
	ADPCM_STEP_VALUE => ADPCM_STEP_VALUE
);

ADPCM_STEP_VALUE <= std_logic_vector(adpcm_step(unsigned(ADPCM_STEP_ADDR)));

-- TODO There is currently no software for sample engine that works
-- with VBXE, so this is (a) impossible to test, (b) say whether it's at all needed.
-- SID playing with VBXE active seems to work without a hitch and without any hacks of this sort.

SAMPLE_RAM_REQUEST <= SAMPLE_RAM_REQUEST_RAW and (not(VBXE_MEMAC_ACTIVE) or or_reduce(CLOCK_SHIFT(11 downto 4)));

enable_1mhz_clock_div : entity work.enable_divider
generic map (COUNT=>28) -- TODO dep cycle_length
port map(clk=>clk,reset_n=>reset_n,enable_in=>'1',enable_out=>SID_CLK_ENABLE);

sid_data_mapper : entity work.sid_data
PORT MAP(
	CLK => CLK,
	RESET_N => RESET_N,

	SID1_ROM_ADDRESS => SID1_ROM_ADDRESS,
	SID1_ROM_REQUEST => SID1_ROM_REQUEST,
	SID1_ROM_READY => SID1_ROM_READY,
	SID1_ROM_READ_DATA => SID1_ROM_READ_DATA,

	SID2_ROM_ADDRESS => SID2_ROM_ADDRESS,
	SID2_ROM_REQUEST => SID2_ROM_REQUEST,
	SID2_ROM_READY => SID2_ROM_READY,
	SID2_ROM_READ_DATA => SID2_ROM_READ_DATA,

	SID_ROM_ADDRESS => SID_ROM_ADDRESS,
	SID_ROM_REQUEST => SID_ROM_REQUEST,
	SID_ROM_READY => SID_ROM_READY,
	SID_ROM_READ_DATA => SID_ROM_READ_DATA
);

sid1 : entity work.SID_top
GENERIC MAP
(
	wave_base => "00100000000000000"
)
PORT MAP(
	CLK => CLK,
	RESET_N => RESET_N,
	ENABLE => SID_CLK_ENABLE, --1MHz

	WRITE_ENABLE => SID_WRITE_ENABLE(0),
	READ_ENABLE => SID_READ_ENABLE(0),
	ADDR => ADDR_IN(4 downto 0),
	DI => WRITE_DATA(7 downto 0),
	DO => SID_DO(0),
	DRIVE_DO => SID_DRIVE_DO(0),
	AUDIO => SID_AUDIO_SIGNED(0),

	SIDTYPE => SID_FILTER1_REG(0),
	EXT => SID_FILTER1_REG(2 downto 1),
	EXT_ADC => signed_to_unsigned(SID_AUDIO_IN_SIGNED(0)),

	POT_X => '0',
	POT_Y => '0',

	rom_addr => SID1_ROM_ADDRESS,
	rom_data => SID1_ROM_READ_DATA,
    rom_request => SID1_ROM_REQUEST,
	rom_ready => SID1_ROM_READY,

	FILTER_BP_OUT => SID1_FILTER_BP,
	FILTER_HP_OUT => SID1_FILTER_HP,
	FILTER_F_OUT => SID1_F_RAW,
	FILTER_F_BP => std_logic_vector(SID1_F_BP),
	FILTER_F_HP => std_logic_vector(SID1_F_HP)
);

sid2 : entity work.SID_top
GENERIC MAP
(
	wave_base => "00100000000000000"
)
PORT MAP(
	CLK => CLK,
	RESET_N => RESET_N,
	ENABLE => SID_CLK_ENABLE, --1MHz

	WRITE_ENABLE => SID_WRITE_ENABLE(1),
	READ_ENABLE => SID_READ_ENABLE(1),
	ADDR => ADDR_IN(4 downto 0),
	DI => WRITE_DATA(7 downto 0),
	DO => SID_DO(1),
	DRIVE_DO => SID_DRIVE_DO(1),
	AUDIO => SID_AUDIO_SIGNED(1),

	SIDTYPE => SID_FILTER2_REG(0),
	EXT => SID_FILTER2_REG(2 downto 1),
	EXT_ADC => signed_to_unsigned(SID_AUDIO_IN_SIGNED(1)),

	POT_X => '0',
	POT_Y => '0',

	rom_addr => SID2_ROM_ADDRESS,
	rom_data => SID2_ROM_READ_DATA,
    rom_request => SID2_ROM_REQUEST,
	rom_ready => SID2_ROM_READY,

	FILTER_BP_OUT => SID2_FILTER_BP,
	FILTER_HP_OUT => SID2_FILTER_HP,
	FILTER_F_OUT => SID2_F_RAW,
	FILTER_F_BP => std_logic_vector(SID2_F_BP),
	FILTER_F_HP => std_logic_vector(SID2_F_HP)
);

f_distortion_mux : entity work.SID_f_distortion_mux
port map
(
	clk=>clk,
	reset_n=>reset_n,
	state1=>SID1_FILTER_BP(17 downto 8),
	state2=>SID1_FILTER_HP(17 downto 8),
	state3=>SID2_FILTER_BP(17 downto 8),
	state4=>SID2_FILTER_HP(17 downto 8),
	SIDTYPE12 => SID_FILTER1_REG(0),
	SIDTYPE34 => SID_FILTER2_REG(0),
	f_raw12=>unsigned(SID1_F_RAW),
	f_raw34=>unsigned(SID2_F_RAW),
	f_distorted1=>SID1_F_BP,
	f_distorted2=>SID1_F_HP,
	f_distorted3=>SID2_F_BP,
	f_distorted4=>SID2_F_HP
);

-- Configuration

process(clk,reset_n)
begin
	if (reset_n='0') then
		DETECT_RIGHT_REG <= '1';
		IRQ_EN_REG <= '0';
		CHANNEL_MODE_REG <= '0';
		SATURATE_REG <= '1';
		POST_DIVIDE_REG <= "1010"; -- 1/2 5v, 3/4 1v
		GTIA_ENABLE_REG <= "11"; -- external only
		ADC_VOLUME_REG <= "10"; -- 0=silent,1=1x,2=2x,3=4x
		--SIO_DATA_VOLUME_REG <= "10"; -- 0=silent,1=quieter,2=normal,3=louder
		CONFIG_ENABLE_REG <= '0';
		VERSION_LOC_REG <= (others=>'0');
		PAL_REG <= '1';

		--PSG_FREQ_REG <= "00"; --2MHz
		--PSG_STEREOMODE_REG <= "01"; --Polish
		--PSG_PROFILESEL_REG <= "00"; --Simple log
		--PSG_ENVELOPE16_REG <= '0'; --32 step

		SID_FILTER1_REG <= "010"; -- 0=8580,1=6581,2=digifix
		SID_FILTER2_REG <= "010"; -- 0=8580,1=6581,2=digifix

		RESTRICT_CAPABILITY_REG <= (others=>'1');
		CHANNEL_EN_REG <= (others=>'1');

		MIXER_SIGNED_REG(0) <= to_signed(0,16);
		MIXER_SIGNED_REG(1) <= to_signed(0,16);
		MIXER_SIGNED_REG(2) <= to_signed(0,16);
		MIXER_SIGNED_REG(3) <= to_signed(0,16);
		MIX_SEL1_REG <= (others=>'0');
		MIX_SEL2_REG <= (others=>'0');
	elsif (clk'event and clk='1') then
		DETECT_RIGHT_REG <= DETECT_RIGHT_NEXT;
		IRQ_EN_REG <= IRQ_EN_NEXT;
		CHANNEL_MODE_REG <= CHANNEL_MODE_NEXT;
		SATURATE_REG <= SATURATE_NEXT;
		POST_DIVIDE_REG <= POST_DIVIDE_NEXT;
		GTIA_ENABLE_REG <= GTIA_ENABLE_NEXT;
		ADC_VOLUME_REG <= ADC_VOLUME_NEXT;
		--SIO_DATA_VOLUME_REG <= SIO_DATA_VOLUME_NEXT;
		CONFIG_ENABLE_REG <= CONFIG_ENABLE_NEXT;
		VERSION_LOC_REG <= VERSION_LOC_NEXT;
		PAL_REG <= PAL_NEXT;

		--PSG_FREQ_REG <= PSG_FREQ_NEXT;
		--PSG_STEREOMODE_REG <= PSG_STEREOMODE_NEXT;
		--PSG_PROFILESEL_REG <= PSG_PROFILESEL_NEXT;
		--PSG_ENVELOPE16_REG <= PSG_ENVELOPE16_NEXT;

		SID_FILTER1_REG <= SID_FILTER1_NEXT;
		SID_FILTER2_REG <= SID_FILTER2_NEXT;

		RESTRICT_CAPABILITY_REG <= RESTRICT_CAPABILITY_NEXT;
		CHANNEL_EN_REG <= CHANNEL_EN_NEXT;

		MIXER_SIGNED_REG <= MIXER_SIGNED_NEXT;
		MIX_SEL1_REG <= MIX_SEL1_NEXT;
		MIX_SEL2_REG <= MIX_SEL2_NEXT;

	end if;
end process;

-------------------------------------------------------
-- COMMON, data bus
--
--
-- memory map
-- d200 - pokey0
-- d210 - pokey1
-- d220 - pokey2
-- d230 - pokey3
-- d240 - sid1
-- d260 - sid2
-- d280 - covox/sample
-- d2a0 - ym1 (mapped as 0-f, rather than convoluted 0/1)
-- d2b0 - ym2
-- d2f0 - config (write 0x3f to d21c to map it in d210, for low bit devices)

process(CONFIG_ENABLE_REG,ADDR_IN,addr_decoded4,FANCY_ENABLE)
	variable addr_bits : std_logic_vector(3 downto 0);
begin
	-- choose which bank
	addr_bits := (others=>'0');
	addr_bits(3 downto 0) := ADDR_IN(7 downto 4);
	
	if (fancy_enable='0') then
		addr_bits := (others=>'0');
	end if;

	if (addr_in(7 downto 4)=x"f") then -- TODO: tweak...
		addr_bits := x"0"; --disable config access here
	end if;

	if ((config_enable_reg='1' and addr_bits="0001") or (addr_bits(3 downto 2) = "00" and addr_decoded4(12)='1')) then
		addr_bits := x"f";
	end if;
	
	DEVICE_ADDR <= addr_bits;
end process;			

process(
	DEVICE_ADDR,
	POKEY_DO,
	SID_DO,SID_DRIVE_DO,
	PSG_DO,
	SAMPLE_DO,
	CONFIG_DO,
	write_n,
	request,
	RESTRICT_CAPABILITY_REG, readreq_s, writereq_s
	)
	variable writereq : std_logic;
	variable readreq : std_logic;
	variable enable_region : std_logic;
begin
	writereq := not(write_n) and request;
	readreq := write_n and request;
	
	POKEY_WRITE_ENABLE <= (others=>'0');
	SID_WRITE_ENABLE <= (others=>'0');
	SID_READ_ENABLE <= (others=>'0');
	PSG_WRITE_ENABLE <= (others=>'0');
	SAMPLE_WRITE_ENABLE <= '0';
	CONFIG_WRITE_ENABLE <= '0';
	enable_region :='0';
	
	DO_MUX <= (others =>'0');
	DRIVE_DO_MUX <= '1';
	
	case DEVICE_ADDR is
		when "0001" =>
			enable_region := RESTRICT_CAPABILITY_REG(0) or RESTRICT_CAPABILITY_REG(1);
			DO_MUX <= POKEY_DO(1);
			POKEY_WRITE_ENABLE(1) <= writereq_s;
		when "0010" =>
			enable_region := RESTRICT_CAPABILITY_REG(1);
			DO_MUX <= POKEY_DO(2);
			POKEY_WRITE_ENABLE(2) <= writereq_s;
		when "0011" =>
			enable_region := RESTRICT_CAPABILITY_REG(1);
			DO_MUX <= POKEY_DO(3);
			POKEY_WRITE_ENABLE(3) <= writereq_s;
		when "0100"|"0101" =>
			enable_region := RESTRICT_CAPABILITY_REG(2);
			DO_MUX <= SID_DO(0);
			DRIVE_DO_MUX <= SID_DRIVE_DO(0);
			SID_WRITE_ENABLE(0) <= writereq_s;
			SID_READ_ENABLE(0) <= readreq_s;
		when "0110"|"0111" =>
			enable_region := RESTRICT_CAPABILITY_REG(2);
			DO_MUX <= SID_DO(1);
			DRIVE_DO_MUX <= SID_DRIVE_DO(1);
			SID_WRITE_ENABLE(1) <= writereq_s;
			SID_READ_ENABLE(1) <= readreq_s;
		when "1000"|"1001" =>
			enable_region := RESTRICT_CAPABILITY_REG(4);
			DO_MUX <= SAMPLE_DO;								
			SAMPLE_WRITE_ENABLE <= writereq_s;			
		when "1010" =>
			enable_region := RESTRICT_CAPABILITY_REG(3);
			DO_MUX <= PSG_DO(0);
			PSG_WRITE_ENABLE(0) <= writereq_s;
		when "1011" =>
			enable_region := RESTRICT_CAPABILITY_REG(3);
			DO_MUX <= PSG_DO(1);			
			PSG_WRITE_ENABLE(1) <= writereq_s;
		when "1111" =>
			enable_region := '1';
			DO_MUX <= CONFIG_DO;
			CONFIG_WRITE_ENABLE <= writereq_s;
		when others =>
	end case;

	readreq_s <= readreq and enable_region;
	writereq_s <= writereq and enable_region;

	if enable_region='0' then
		DO_MUX <= POKEY_DO(0);
		POKEY_WRITE_ENABLE(0) <= writereq;
	end if;
end process;

-- default config

decode_addr1 : entity work.complete_address_decoder
	generic map(width=>4)
	port map (addr_in=>ADDR_IN(3 downto 0), addr_decoded=>addr_decoded4);

process(CONFIG_WRITE_ENABLE, WRITE_DATA, addr_decoded4,
	SATURATE_REG,CHANNEL_MODE_REG,IRQ_EN_REG,DETECT_RIGHT_REG,
	CONFIG_ENABLE_REG,
	POST_DIVIDE_REG,
	GTIA_ENABLE_REG,
	ADC_VOLUME_REG,
	--SIO_DATA_VOLUME_REG,
	VERSION_LOC_REG,
	--PSG_FREQ_REG,
	--PSG_STEREOMODE_REG,
	--PSG_PROFILESEL_REG,
	--PSG_ENVELOPE16_REG,
	SID_FILTER1_REG, SID_FILTER2_REG,
	RESTRICT_CAPABILITY_REG,
	CHANNEL_EN_REG,
	MIX_SEL1_REG, MIX_SEL2_REG,
	PAL_REG
)
begin
	SATURATE_NEXT <= SATURATE_REG;
	CHANNEL_MODE_NEXT <= CHANNEL_MODE_REG;
	IRQ_EN_NEXT <= IRQ_EN_REG;
	DETECT_RIGHT_NEXT <= DETECT_RIGHT_REG;

	POST_DIVIDE_NEXT <= POST_DIVIDE_REG;
	
	GTIA_ENABLE_NEXT <= GTIA_ENABLE_REG;

	ADC_VOLUME_NEXT <= ADC_VOLUME_REG;
	--SIO_DATA_VOLUME_NEXT <= SIO_DATA_VOLUME_REG;
	
	CONFIG_ENABLE_NEXT <= CONFIG_ENABLE_REG;
	
	VERSION_LOC_NEXT <= VERSION_LOC_REG;

	--PSG_FREQ_NEXT <= PSG_FREQ_REG;
	--PSG_STEREOMODE_NEXT <= PSG_STEREOMODE_REG;
	--PSG_PROFILESEL_NEXT <= PSG_PROFILESEL_REG;
	--PSG_ENVELOPE16_NEXT <= PSG_ENVELOPE16_REG;

	SID_FILTER1_NEXT <= SID_FILTER1_REG;
	SID_FILTER2_NEXT <= SID_FILTER2_REG;

	RESTRICT_CAPABILITY_NEXT <= RESTRICT_CAPABILITY_REG;
	CHANNEL_EN_NEXT <= CHANNEL_EN_REG;

	PAL_NEXT <= PAL_REG;

	MIX_SEL1_NEXT <= MIX_SEL1_REG;
	MIX_SEL2_NEXT <= MIX_SEL2_REG;

	if (CONFIG_WRITE_ENABLE='1') then
		if (addr_decoded4(0)='1') then
			SATURATE_NEXT <= WRITE_DATA(0);
			CHANNEL_MODE_NEXT <= WRITE_DATA(2);
			IRQ_EN_NEXT <= WRITE_DATA(3);
			DETECT_RIGHT_NEXT <= WRITE_DATA(4);
			PAL_NEXT <= WRITE_DATA(5);
		end if;

		if (addr_decoded4(2)='1') then
			POST_DIVIDE_NEXT <= WRITE_DATA(7 downto 4);
		end if;
				
		if (addr_decoded4(3)='1') then			
			GTIA_ENABLE_NEXT <= WRITE_DATA(3 downto 2);
			ADC_VOLUME_NEXT <= WRITE_DATA(5 downto 4);
			--SIO_DATA_VOLUME_NEXT <= WRITE_DATA(7 downto 6);
		end if;		

		if (addr_decoded4(4)='1') then
			VERSION_LOC_NEXT <= WRITE_DATA(2 downto 0);
		end if;
		
		--if (addr_decoded4(5)='1') then
		--	PSG_FREQ_NEXT <= WRITE_DATA(1 downto 0);
		--	PSG_STEREOMODE_NEXT <= WRITE_DATA(3 downto 2);
		--	PSG_ENVELOPE16_NEXT <= WRITE_DATA(4);
		--	PSG_PROFILESEL_NEXT <= WRITE_DATA(6 downto 5);
		--end if;

		if (addr_decoded4(6)='1') then
			SID_FILTER1_NEXT <= WRITE_DATA(2 downto 0);
			SID_FILTER2_NEXT <= WRITE_DATA(6 downto 4);
		end if;

		if (addr_decoded4(7)='1') then
			RESTRICT_CAPABILITY_NEXT(4 downto 0) <= WRITE_DATA(4 downto 0);
		end if;

		if (addr_decoded4(8)='1') then
			MIX_SEL1_NEXT <= WRITE_DATA(2 downto 0);
			MIX_SEL2_NEXT <= WRITE_DATA(6 downto 4);
		end if;

		if (addr_decoded4(9)='1') then
			CHANNEL_EN_NEXT <= WRITE_DATA(3 downto 2);
		end if;

		if (addr_decoded4(12)='1') then
			if (WRITE_DATA=x"3F") then
				CONFIG_ENABLE_NEXT <= '1';
			else
				CONFIG_ENABLE_NEXT <= '0';
			end if;
		end if;		

	end if;	
end process;

process(addr_decoded4,VERSION_LOC_REG,
SATURATE_REG,CHANNEL_MODE_REG,IRQ_EN_REG,DETECT_RIGHT_REG,
POST_DIVIDE_REG, GTIA_ENABLE_REG,
ADC_VOLUME_REG,
--SIO_DATA_VOLUME_REG, 
--PSG_FREQ_REG, PSG_STEREOMODE_REG, PSG_PROFILESEL_REG, PSG_ENVELOPE16_REG,
SID_FILTER1_REG, SID_FILTER2_REG,
RESTRICT_CAPABILITY_REG,
CHANNEL_EN_REG,
MIX_SEL1_REG, MIX_SEL2_REG,
PAL_REG
)
	variable ACTUAL_CAPABILITY : std_logic_vector(7 downto 0);
begin
	CONFIG_DO <= (others=>'1');
	
	if (addr_decoded4(0)='1') then
			CONFIG_DO <= (others=>'0');
			CONFIG_DO(0) <= SATURATE_REG;
			CONFIG_DO(2) <= CHANNEL_MODE_REG;
			CONFIG_DO(3) <= IRQ_EN_REG;
			CONFIG_DO(4) <= DETECT_RIGHT_REG;
			CONFIG_DO(5) <= PAL_REG;
	end if;	

	ACTUAL_CAPABILITY := (others=>'0');

	ACTUAL_CAPABILITY(1 downto 0) := "11"; -- POKEY CFG bit1=quad

	--if (enable_sid=1) then
	ACTUAL_CAPABILITY(2) := '1'; -- SID

	--if (enable_psg=1) then
	--	ACTUAL_CAPABILITY(3) := '1'; -- PSG

	ACTUAL_CAPABILITY(4) := '1'; -- COVOX
	ACTUAL_CAPABILITY(5) := '1'; -- Sample engine
	-- 6 would be Flash, don't have it here
	ACTUAL_CAPABILITY(7) := '1'; -- Mixer routing
	
	if (addr_decoded4(1)='1') then
		CONFIG_DO <= ACTUAL_CAPABILITY and "11"&RESTRICT_CAPABILITY_REG(4)&RESTRICT_CAPABILITY_REG;
	end if;
	
	if (addr_decoded4(2)='1') then
		CONFIG_DO <= POST_DIVIDE_REG & "0000";
	end if;	
	
	if (addr_decoded4(3)='1') then
		CONFIG_DO <= (others=>'0');
		CONFIG_DO(3 downto 2) <= GTIA_ENABLE_REG;
		CONFIG_DO(5 downto 4) <= ADC_VOLUME_REG;
		--CONFIG_DO(7 downto 6) <= SIO_DATA_VOLUME_REG;
	end if;
	
	if (addr_decoded4(4)='1') then
		-- version -> 31MiSTer
		case VERSION_LOC_REG(2 downto 0) is			
			when "000" => 
				CONFIG_DO <= x"33";
			when "001" =>
				CONFIG_DO <= x"31";
			when "010" =>
				CONFIG_DO <= x"4D";
			when "011" =>
				CONFIG_DO <= x"69";
			when "100" => 
				CONFIG_DO <= x"53";
			when "101" =>
				CONFIG_DO <= x"54";
			when "110" =>
				CONFIG_DO <= x"65";
			when "111" =>
				CONFIG_DO <= x"72";
			when others =>
		end case;		
	end if;

	--if (addr_decoded4(5)='1') then
	--	CONFIG_DO <= (others=>'0');
	--	CONFIG_DO(1 downto 0) <= PSG_FREQ_REG;
	--	CONFIG_DO(3 downto 2) <= PSG_STEREOMODE_REG;
	--	CONFIG_DO(4) <= PSG_ENVELOPE16_REG;
	--	CONFIG_DO(6 downto 5) <= PSG_PROFILESEL_REG;
	--end if;

	if (addr_decoded4(6)='1') then -- different use on sidmax
		CONFIG_DO <= (others=>'0');
		CONFIG_DO(2 downto 0) <= SID_FILTER1_REG;
		-- (3 downto 3) reserved in case we want more filter options
		CONFIG_DO(6 downto 4) <= SID_FILTER2_REG;
		-- (7 downto 7) reserved in case we want more filter options
	end if;

	if (addr_decoded4(7)='1') then
		CONFIG_DO(4 downto 0) <= RESTRICT_CAPABILITY_REG(4 downto 0);
	end if;

	if (addr_decoded4(8)='1') then
		CONFIG_DO(2 downto 0) <= MIX_SEL1_REG;
		CONFIG_DO(6 downto 4) <= MIX_SEL2_REG;
	end if;

	if (addr_decoded4(9)='1') then
		CONFIG_DO(4 downto 0) <= '0'&CHANNEL_EN_REG&"00";
	end if;

	if (addr_decoded4(12)='1') then
		CONFIG_DO <= x"01";
	end if;		

end process;

process(clk)
begin
	if (clk'event and clk='1') then
		CHANNEL0SUM_REG <= CHANNEL0SUM_NEXT;
		CHANNEL1SUM_REG <= CHANNEL1SUM_NEXT;
		CHANNEL2SUM_REG <= CHANNEL2SUM_NEXT;
		CHANNEL3SUM_REG <= CHANNEL3SUM_NEXT;
	end if;
end process;

process(
	POKEY_CHANNEL0,POKEY_CHANNEL1,POKEY_CHANNEL2,POKEY_CHANNEL3,
	CHANNEL_MODE_REG -- 0=pokeys have a channel each,1=ch 0 summed, ch 1 summed, ch 2 summed etc
	)
variable p0 : unsigned(5 downto 0);
variable p1 : unsigned(5 downto 0);
variable p2 : unsigned(5 downto 0);
variable p3 : unsigned(5 downto 0);

variable c0 : unsigned(5 downto 0);
variable c1 : unsigned(5 downto 0);
variable c2 : unsigned(5 downto 0);
variable c3 : unsigned(5 downto 0);

variable sum0 : unsigned(5 downto 0);
variable sum1 : unsigned(5 downto 0);
variable sum2 : unsigned(5 downto 0);
variable sum3 : unsigned(5 downto 0);

begin
	p0 := resize(unsigned(POKEY_CHANNEL0(0)),6) + resize(unsigned(POKEY_CHANNEL1(0)),6) + resize(unsigned(POKEY_CHANNEL2(0)),6) + resize(unsigned(POKEY_CHANNEL3(0)),6);
	p1 := resize(unsigned(POKEY_CHANNEL0(1)),6) + resize(unsigned(POKEY_CHANNEL1(1)),6) + resize(unsigned(POKEY_CHANNEL2(1)),6) + resize(unsigned(POKEY_CHANNEL3(1)),6);
	p2 := resize(unsigned(POKEY_CHANNEL0(2)),6) + resize(unsigned(POKEY_CHANNEL1(2)),6) + resize(unsigned(POKEY_CHANNEL2(2)),6) + resize(unsigned(POKEY_CHANNEL3(2)),6);
	p3 := resize(unsigned(POKEY_CHANNEL0(3)),6) + resize(unsigned(POKEY_CHANNEL1(3)),6) + resize(unsigned(POKEY_CHANNEL2(3)),6) + resize(unsigned(POKEY_CHANNEL3(3)),6);

	c0 := resize(unsigned(POKEY_CHANNEL0(0)),6) + resize(unsigned(POKEY_CHANNEL0(1)),6) + resize(unsigned(POKEY_CHANNEL0(2)),6) + resize(unsigned(POKEY_CHANNEL0(3)),6);
	c1 := resize(unsigned(POKEY_CHANNEL1(0)),6) + resize(unsigned(POKEY_CHANNEL1(1)),6) + resize(unsigned(POKEY_CHANNEL1(2)),6) + resize(unsigned(POKEY_CHANNEL1(3)),6);
	c2 := resize(unsigned(POKEY_CHANNEL2(0)),6) + resize(unsigned(POKEY_CHANNEL2(1)),6) + resize(unsigned(POKEY_CHANNEL2(2)),6) + resize(unsigned(POKEY_CHANNEL2(3)),6);
	c3 := resize(unsigned(POKEY_CHANNEL3(0)),6) + resize(unsigned(POKEY_CHANNEL3(1)),6) + resize(unsigned(POKEY_CHANNEL3(2)),6) + resize(unsigned(POKEY_CHANNEL3(3)),6);

	if CHANNEL_MODE_REG ='1' then
		sum0 := c0;
		sum1 := c1;
		sum2 := c2;
		sum3 := c3;
	else
		sum0 := p0;
		sum1 := p1;
		sum2 := p2;
		sum3 := p3;
	end if;

	CHANNEL0SUM_NEXT <= sum0;
	CHANNEL1SUM_NEXT <= sum1;
	CHANNEL2SUM_NEXT <= sum2;
	CHANNEL3SUM_NEXT <= sum3;
end process;

pokey_mixer_all : entity work.pokey_mixer_mux
PORT MAP(CLK => CLK,
	RESET_N => RESET_N,
	CHANNEL_0 => CHANNEL0SUM_REG,
	CHANNEL_1 => CHANNEL1SUM_REG,
	CHANNEL_2 => CHANNEL2SUM_REG,
	CHANNEL_3 => CHANNEL3SUM_REG,
	VOLUME_OUT_0 => POKEY_AUDIO_UNSIGNED(0),
	VOLUME_OUT_1 => POKEY_AUDIO_UNSIGNED(1),
	VOLUME_OUT_2 => POKEY_AUDIO_UNSIGNED(2),
	VOLUME_OUT_3 => POKEY_AUDIO_UNSIGNED(3),
	PROFILE_ADDR => POKEY_PROFILE_ADDR,
	PROFILE_REQUEST => POKEY_PROFILE_REQUEST,
	PROFILE_READY => POKEY_PROFILE_REQUEST,
	PROFILE_DATA => POKEY_PROFILE_DATA);

POKEY_PROFILE_DATA <= std_logic_vector(pokey_volume(unsigned(POKEY_PROFILE_ADDR))) when saturate_reg = '1' else POKEY_PROFILE_ADDR&"0000000000";

-- provide audio back to:
-- sample enggine -> to record to ram
-- sid ext        -> to use filter (mutes original output)
--	S_AUDIO  => mixer_audio_out,,
--	S_LEFT => mixer_l_enable,
--	S_RIGHT => mixer_r_enable,
--	S_CHANNEL => mixer_audio_out_channel,

process(MIXER_SIGNED_REG, mixer_l_enable, mixer_r_enable, mixer_audio_out, MIX_SEL1_REG, MIX_SEL2_REG, mixer_audio_out_channel, SID_FILTER1_REG, SID_FILTER2_REG)
begin
	MIXER_SIGNED_NEXT <= MIXER_SIGNED_REG;

	mixer_mute <= '0';

	if (std_logic_vector(mixer_audio_out_channel) = MIX_SEL1_REG) then
		if (mixer_l_enable='1') then
			MIXER_SIGNED_NEXT(0) <= mixer_audio_out;
			mixer_mute <= SID_FILTER1_REG(2);
		end if;

		if (mixer_r_enable='1') then
			MIXER_SIGNED_NEXT(1) <= mixer_audio_out;
			mixer_mute <= SID_FILTER2_REG(2);
		end if;
	end if;

	if (std_logic_vector(mixer_audio_out_channel) = MIX_SEL2_REG) then
		if (mixer_l_enable='1') then
			MIXER_SIGNED_NEXT(2) <= mixer_audio_out;
		end if;

		if (mixer_r_enable='1') then
			MIXER_SIGNED_NEXT(3) <= mixer_audio_out;
		end if;
	end if;
end process;

SAMPLE_AUDIO_IN_SIGNED <= MIXER_SIGNED_REG;
SID_AUDIO_IN_SIGNED(0) <= MIXER_SIGNED_REG(0);
SID_AUDIO_IN_SIGNED(1) <= MIXER_SIGNED_REG(1);

process(GTIA_SOUND) is
begin
	if GTIA_SOUND='1' then
		GTIA_AUDIO_SIGNED <= to_signed(5120,16);
	else
		GTIA_AUDIO_SIGNED <= to_signed(-5120,16);
	end if;
end process;

sio_audio_dc_blocker : entity work.dc_blocker_pm
PORT  MAP
(
	CLK          => CLK,
	RESET_N      => RESET_N,
	ENABLE_CYCLE => ENABLE_179,
	AUDIO_IN    => SIO_AUDIO_UNSIGNED,
	AUDIO_OUT   => SIO_AUDIO_SIGNED
);

process(ADC_VOLUME_REG,SIO_SOUND)
begin
	SIO_AUDIO_UNSIGNED <= (others=>'0');
	case ADC_VOLUME_REG is
		when "01" =>
			SIO_AUDIO_UNSIGNED(12 downto 5) <= unsigned(SIO_SOUND);
		when "10" =>
			SIO_AUDIO_UNSIGNED(13 downto 6) <= unsigned(SIO_SOUND);
		when "11" =>
			SIO_AUDIO_UNSIGNED(14 downto 7) <= unsigned(SIO_SOUND);
		when others =>
	end case;
end process;


mixer1 : entity work.mixer
PORT MAP
(
	CLK => CLK,
	RESET_N => RESET_N,

	ENABLE_CYCLE => ENABLE_179,

	POST_DIVIDE => POST_DIVIDE_REG&"0000",
	DETECT_RIGHT => DETECT_RIGHT_REG,
	FANCY_ENABLE => FANCY_ENABLE,
	B_CH0_EN => GTIA_ENABLE_REG&"00",
	B_CH1_EN => "1100",

	L_CH0 => POKEY_AUDIO_SIGNED(0),
	R_CH0 => POKEY_AUDIO_SIGNED(1),
	L_CH1 => POKEY_AUDIO_SIGNED(2),
	R_CH1 => POKEY_AUDIO_SIGNED(3),
	L_CH2 => SAMPLE_AUDIO_SIGNED(0),
	R_CH2 => SAMPLE_AUDIO_SIGNED(1),
	L_CH3 => SID_AUDIO_SIGNED(0),
	R_CH3 => SID_AUDIO_SIGNED(1),
	L_CH4 => to_signed(0, 16), -- PSG_AUDIO_SIGNED(0),
	R_CH4 => to_signed(0, 16), -- PSG_AUDIO_SIGNED(1),
	B_CH0 => GTIA_AUDIO_SIGNED,
	B_CH1 => SIO_AUDIO_SIGNED,

	MUTE_CHANNEL => mixer_mute,

	S_AUDIO  => mixer_audio_out,
	S_LEFT => mixer_l_enable,
	S_RIGHT => mixer_r_enable,
	S_CHANNEL => mixer_audio_out_channel,

	--AUDIO_0_SIGNED => AUDIO_MIXED_SIGNED(0),
	--AUDIO_1_SIGNED => AUDIO_MIXED_SIGNED(1),
	AUDIO_2_SIGNED => AUDIO_MIXED_SIGNED(2),
	AUDIO_3_SIGNED => AUDIO_MIXED_SIGNED(3)
);

filter_left : entity work.simple_low_pass_filter
PORT MAP
(
	CLK => clk,
	AUDIO_IN => signed_to_unsigned(AUDIO_MIXED_SIGNED(2)),
	SAMPLE_IN => enable_179,
	AUDIO_OUT => AUDIO_2_FILTERED
);

filter_right : entity work.simple_low_pass_filter
PORT MAP
(
	CLK => clk,
	AUDIO_IN => signed_to_unsigned(AUDIO_MIXED_SIGNED(3)),
	SAMPLE_IN => enable_179,
	AUDIO_OUT => AUDIO_3_FILTERED
);

AUDIO_L <= not(AUDIO_2_FILTERED(15))&AUDIO_2_FILTERED(14 downto 0);
AUDIO_R <= not(AUDIO_3_FILTERED(15))&AUDIO_3_FILTERED(14 downto 0);

FANCY_ENABLE <= STEREO;
ADDR_IN <= ADDR;
WRITE_DATA <= DATA_IN;
WRITE_N <= not(WR_EN);

DATA_OUT <= DO_MUX;
DRIVE_DATA_OUT <= DRIVE_DO_MUX;

IRQ_N_OUT <= (not(IRQ_EN_REG) or (and_reduce(POKEY_IRQ))) and (IRQ_EN_REG or POKEY_IRQ(0)) and not(SAMPLE_IRQ);

END vhdl;
