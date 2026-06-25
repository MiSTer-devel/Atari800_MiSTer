LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY pokeymax IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

    ENABLE_179 : in std_logic;
	ADDR : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	DATA_IN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
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
	SIO_AUDIO : IN STD_LOGIC_VECTOR(7 downto 0);

    -- sound output
    AUDIO_L : OUT STD_LOGIC_VECTOR(15 downto 0);
	AUDIO_R : OUT STD_LOGIC_VECTOR(15 downto 0);

	POT_RESET : out std_logic
);
END pokeymax;

ARCHITECTURE vhdl OF pokeymax IS

signal AUDIO_L_pre : std_logic_vector(15 downto 0);
signal AUDIO_R_pre : std_logic_vector(15 downto 0);

signal POKEY1_CHANNEL0 : std_logic_vector(3 downto 0);
signal POKEY1_CHANNEL1 : std_logic_vector(3 downto 0);
signal POKEY1_CHANNEL2 : std_logic_vector(3 downto 0);
signal POKEY1_CHANNEL3 : std_logic_vector(3 downto 0);

signal POKEY2_CHANNEL0 : std_logic_vector(3 downto 0);
signal POKEY2_CHANNEL1 : std_logic_vector(3 downto 0);
signal POKEY2_CHANNEL2 : std_logic_vector(3 downto 0);
signal POKEY2_CHANNEL3 : std_logic_vector(3 downto 0);

signal covox_channel0 : std_logic_vector(7 downto 0);
signal covox_channel1 : std_logic_vector(7 downto 0);
signal covox_channel2 : std_logic_vector(7 downto 0);
signal covox_channel3 : std_logic_vector(7 downto 0);

SIGNAL	DO_MUX :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	DRIVE_DO_MUX :  STD_LOGIC;

SIGNAL	POKEY1_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	POKEY1_WRITE_ENABLE :  STD_LOGIC;

SIGNAL	POKEY2_DO :  STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	POKEY2_WRITE_ENABLE :  STD_LOGIC;

signal covox_write_enable : std_logic;


BEGIN

pokey_mixer_both : entity work.pokey_mixer_mux
PORT MAP(CLK => CLK,
	ENABLE_179 => ENABLE_179,
	GTIA_SOUND => GTIA_SOUND,
	SIO_AUDIO => SIO_AUDIO,
	CHANNEL_L_0 => POKEY1_CHANNEL0,
	CHANNEL_L_1 => POKEY1_CHANNEL1,
	CHANNEL_L_2 => POKEY1_CHANNEL2,
	CHANNEL_L_3 => POKEY1_CHANNEL3,
	COVOX_CHANNEL_L_0 => covox_channel0,
	COVOX_CHANNEL_L_1 => covox_channel1,
	CHANNEL_R_0 => POKEY2_CHANNEL0,
	CHANNEL_R_1 => POKEY2_CHANNEL1,
	CHANNEL_R_2 => POKEY2_CHANNEL2,
	CHANNEL_R_3 => POKEY2_CHANNEL3,
	COVOX_CHANNEL_R_0 => covox_channel2,
	COVOX_CHANNEL_R_1 => covox_channel3,
	VOLUME_OUT_L => AUDIO_L_pre,
	VOLUME_OUT_R => AUDIO_R_pre);

pokey1 : entity work.pokey
PORT MAP(CLK => CLK,
	ENABLE_179 => ENABLE_179,
	WR_EN => POKEY1_WRITE_ENABLE,
	RESET_N => RESET_N,
	SIO_IN1 => SIO_IN1,
	SIO_CLOCKIN_IN => SIO_CLOCKIN_IN,
	SIO_CLOCKIN_OUT => SIO_CLOCKIN_OUT,
	SIO_CLOCKIN_OE => SIO_CLOCKIN_OE,
	ADDR => ADDR(3 DOWNTO 0),
	DATA_IN => DATA_IN,
	keyboard_response => KEYBOARD_RESPONSE,
	POT_IN => POT_IN,
	IRQ_N_OUT => IRQ_N_OUT,
	SIO_OUT1 => SIO_OUT1,
	SIO_OUT2 => open,
	SIO_OUT3 => open,
	SIO_CLOCKOUT => SIO_CLOCKOUT,
	POT_RESET => POT_RESET,
	CHANNEL_0_OUT => POKEY1_CHANNEL0,
	CHANNEL_1_OUT => POKEY1_CHANNEL1,
	CHANNEL_2_OUT => POKEY1_CHANNEL2,
	CHANNEL_3_OUT => POKEY1_CHANNEL3,
	DATA_OUT => POKEY1_DO,
	keyboard_scan => KEYBOARD_SCAN);

pokey2 : entity work.pokey
PORT MAP(CLK => CLK,
	ENABLE_179 => ENABLE_179,
	WR_EN => POKEY2_WRITE_ENABLE,
	RESET_N => RESET_N,
	ADDR => ADDR(3 DOWNTO 0),
	DATA_IN => DATA_IN,
	CHANNEL_0_OUT => POKEY2_CHANNEL0,
	CHANNEL_1_OUT => POKEY2_CHANNEL1,
	CHANNEL_2_OUT => POKEY2_CHANNEL2,
	CHANNEL_3_OUT => POKEY2_CHANNEL3,
	DATA_OUT => POKEY2_DO,
	SIO_IN1 => '1',
	keyboard_response => "00",
	pot_in => "00000000");

covox1 : entity work.covox
PORT map(clk => clk,
		reset_n => reset_n,
		addr => ADDR(1 downto 0),
		data_in => DATA_IN,
		wr_en => covox_write_enable,
		covox_channel0 => covox_channel0,
		covox_channel1 => covox_channel1,
		covox_channel2 => covox_channel2,
		covox_channel3 => covox_channel3);

DATA_OUT <= DO_MUX;
DRIVE_DATA_OUT <= DRIVE_DO_MUX;

DO_MUX <= POKEY2_DO when ADDR(4) = '1' and STEREO = '1' else POKEY1_DO;
DRIVE_DO_MUX <= '1';

POKEY1_WRITE_ENABLE <= WR_EN and (not(ADDR(4)) or not(STEREO));
POKEY2_WRITE_ENABLE <= WR_EN and ADDR(4) and STEREO;
covox_write_enable <= '1' when WR_EN = '1' and ADDR(7 downto 2) = "100000" else '0';

AUDIO_L <= AUDIO_L_pre;
AUDIO_R <= AUDIO_R_pre when STEREO = '1' else AUDIO_L_pre;

END vhdl;
