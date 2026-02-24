---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;

LIBRARY work;

ENTITY atari5200top IS 
PORT
(
	CLK        : IN  STD_LOGIC;
	CLK_SDRAM  : IN  STD_LOGIC;
	RESET_N    : IN  STD_LOGIC;

	VGA_VS     : OUT STD_LOGIC;
	VGA_HS     : OUT STD_LOGIC;
	VGA_BLANK  : OUT STD_LOGIC;
	VGA_PIXCE  : OUT STD_LOGIC;
	VGA_B      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	VGA_G      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	VGA_R      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);

	HBLANK     : OUT STD_LOGIC;
	VBLANK     : OUT STD_LOGIC;

	CLIP_SIDES : IN  STD_LOGIC;
	AUDIO_L    : OUT STD_LOGIC_VECTOR(15 downto 0);
	AUDIO_R    : OUT STD_LOGIC_VECTOR(15 downto 0);

	SDRAM_BA   : OUT STD_LOGIC_VECTOR(1 downto 0);
	SDRAM_nCS  : OUT STD_LOGIC;
	SDRAM_nRAS : OUT STD_LOGIC;
	SDRAM_nCAS : OUT STD_LOGIC;
	SDRAM_nWE  : OUT STD_LOGIC;
	SDRAM_DQMH : OUT STD_LOGIC;
	SDRAM_DQML : OUT STD_LOGIC;
	SDRAM_CKE  : OUT STD_LOGIC;
	SDRAM_A    : OUT STD_LOGIC_VECTOR(12 DOWNTO 0);
	SDRAM_DQ   : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);

	ROM_ADDR   : OUT STD_LOGIC_VECTOR(10 DOWNTO 0);
	ROM_DATA   : IN STD_LOGIC_VECTOR(7 DOWNTO 0);

	OSD_PAUSE    : IN STD_LOGIC;
	SDRAM_READY  : OUT STD_LOGIC;
	HPS_DMA_ADDR : IN STD_LOGIC_VECTOR(25 DOWNTO 0);
	HPS_DMA_REQ  : IN STD_LOGIC;
	HPS_DMA_DATA_OUT : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	HPS_DMA_READY: OUT STD_LOGIC;

	SET_RESET_IN : IN STD_LOGIC;
	SET_PAUSE_IN : IN STD_LOGIC;
	CART_SELECT_IN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	HOT_KEYS : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
	COLD_RESET_MENU : IN STD_LOGIC;

	PS2_KEY    : IN  STD_LOGIC_VECTOR(10 downto 0);
	
	CPU_SPEED  : IN std_logic_vector(5 downto 0);

	CPU_HALT   : OUT STD_LOGIC;
	JOY1X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY1Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY2X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY2Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY3X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY3Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY4X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY4Y      : IN  STD_LOGIC_VECTOR(7 downto 0);

	JOY1       : IN  STD_LOGIC_VECTOR(20 DOWNTO 0);
	JOY2       : IN  STD_LOGIC_VECTOR(20 DOWNTO 0);
	JOY3       : IN  STD_LOGIC_VECTOR(20 DOWNTO 0);
	JOY4       : IN  STD_LOGIC_VECTOR(20 DOWNTO 0)

);

END atari5200top;

ARCHITECTURE vhdl OF atari5200top IS 

SIGNAL FKEYS : std_logic_vector(11 downto 0);
SIGNAL JOY   :  STD_LOGIC_VECTOR(20 DOWNTO 0);

SIGNAL KEYBOARD_RESPONSE :  STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL KEYBOARD_SCAN :  STD_LOGIC_VECTOR(5 DOWNTO 0);
signal controller_select : std_logic_vector(1 downto 0);

signal SDRAM_REQUEST : std_logic;
signal SDRAM_REQUEST_COMPLETE : std_logic;
signal SDRAM_READ_ENABLE :  STD_LOGIC;
signal SDRAM_WRITE_ENABLE : std_logic;
signal SDRAM_ADDR : STD_LOGIC_VECTOR(24 DOWNTO 0);
signal SDRAM_DO : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal SDRAM_DI : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal SDRAM_WIDTH_8bit_ACCESS : std_logic;
signal SDRAM_WIDTH_16bit_ACCESS : std_logic;
signal SDRAM_WIDTH_32bit_ACCESS : std_logic;

signal SDRAM_REFRESH : std_logic;
signal SDRAM_RESET_N : std_logic;

signal areset_n : std_logic;
signal cold_reset_request : std_logic;
signal reset_atari : std_logic;
signal pause_atari : std_logic;

signal RAM_DATA : std_logic_vector(31 downto 0);

BEGIN

JOY <= JOY1 or JOY2 or JOY3 or JOY4;

-- PS2 to pokey
keyboard_map1 : entity work.ps2_to_atari5200
generic map (ps2_enable => 0, direct_enable => 1)
PORT MAP
( 
	CLK => clk,
	RESET_N => reset_n,
	INPUT => x"000"&"000"&ps2_key(9)&"000"&ps2_key(8)&x"0"&ps2_key(7 downto 0),
	INPUT2 => JOY(13 downto 9),

	JOY1 => JOY1,
	JOY2 => JOY2,
	JOY3 => JOY3,
	JOY4 => JOY4,

	CONTROLLER_SELECT => CONTROLLER_SELECT, -- selected stick keyboard/shift button
	
	KEYBOARD_SCAN => KEYBOARD_SCAN,
	KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,

	FKEYS => FKEYS
);

atarixl_simple_sdram1 : entity work.atari5200core_simplesdram
GENERIC MAP
(
	cycle_length => 16,
	video_bits => 8,
	palette => 1,
	internal_rom => 0,
	-- For the size, doing anything else than 16K (single Atari bank)
	-- would require a different code and new branches in the 
	-- address decoder to handle SDRAM correctly, and we need SDRAM
	-- for larger carts (Super Cart 512K).
	internal_ram => 16384 -- 65536
)
PORT MAP
(
	CLK => CLK,
	RESET_N => areset_n,

	VIDEO_VS => VGA_VS,
	VIDEO_HS => VGA_HS,
	VIDEO_CS => open,
	VIDEO_BLANK => VGA_BLANK,
	VIDEO_PIXCE => VGA_PIXCE,
	VIDEO_B => VGA_B,
	VIDEO_G => VGA_G,
	VIDEO_R => VGA_R,

	HBLANK => HBLANK,
	VBLANK => VBLANK,

	CLIP_SIDES => CLIP_SIDES,
	AUDIO_L => AUDIO_L,
	AUDIO_R => AUDIO_R,

	JOY1_n => not(JOY1(4)&JOY1(0)&JOY1(1)&JOY1(2)&JOY1(3)), --FRLDU
	JOY2_n => not(JOY2(4)&JOY2(0)&JOY2(1)&JOY2(2)&JOY2(3)), --FRLDU
	JOY3_n => not(JOY3(4)&JOY3(0)&JOY3(1)&JOY3(2)&JOY3(3)), --FRLDU
	JOY4_n => not(JOY4(4)&JOY4(0)&JOY4(1)&JOY4(2)&JOY4(3)), --FRLDU

	JOY1_X => signed(joy1x),
	JOY1_Y => signed(joy1y),
	JOY2_X => signed(joy2x),
	JOY2_Y => signed(joy2y),
	JOY3_X => signed(joy3x),
	JOY3_Y => signed(joy3y),
	JOY4_X => signed(joy4x),
	JOY4_Y => signed(joy4y),

	KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,
	KEYBOARD_SCAN => KEYBOARD_SCAN,
	CONTROLLER_SELECT => CONTROLLER_SELECT,

	SDRAM_REQUEST => SDRAM_REQUEST,
	SDRAM_REQUEST_COMPLETE => SDRAM_REQUEST_COMPLETE,
	SDRAM_READ_ENABLE => SDRAM_READ_ENABLE,
	SDRAM_WRITE_ENABLE => SDRAM_WRITE_ENABLE,
	SDRAM_ADDR => SDRAM_ADDR,
	SDRAM_DO => RAM_DATA,
	SDRAM_DI => SDRAM_DI,
	SDRAM_32BIT_WRITE_ENABLE => SDRAM_WIDTH_32bit_ACCESS,
	SDRAM_16BIT_WRITE_ENABLE => SDRAM_WIDTH_16bit_ACCESS,
	SDRAM_8BIT_WRITE_ENABLE => SDRAM_WIDTH_8bit_ACCESS,
	SDRAM_REFRESH => SDRAM_REFRESH,

	DMA_FETCH => HPS_DMA_REQ,
	DMA_READ_ENABLE => '0',
	DMA_32BIT_WRITE_ENABLE => '0',
	DMA_16BIT_WRITE_ENABLE => '0',
	DMA_8BIT_WRITE_ENABLE => '1',
	DMA_ADDR => HPS_DMA_ADDR,
	DMA_WRITE_DATA => x"000000" & HPS_DMA_DATA_OUT,
	MEMORY_READY_DMA => HPS_DMA_READY,

	HALT => pause_atari,
	THROTTLE_COUNT_6502 => CPU_SPEED,
	EMULATED_CARTRIDGE_SELECT => CART_SELECT_IN
);

sdram_adaptor : entity work.sdram_statemachine
GENERIC MAP
(
	ADDRESS_WIDTH => 24,
	AP_BIT => 10,
	COLUMN_WIDTH => 9,
	ROW_WIDTH => 13
)
PORT MAP
(
	CLK_SYSTEM => CLK,
	CLK_SDRAM => CLK_SDRAM,
	RESET_N =>  RESET_N,
	READ_EN => SDRAM_READ_ENABLE,
	WRITE_EN => SDRAM_WRITE_ENABLE,
	REQUEST => SDRAM_REQUEST,
	BYTE_ACCESS => SDRAM_WIDTH_8BIT_ACCESS,
	WORD_ACCESS => SDRAM_WIDTH_16BIT_ACCESS,
	LONGWORD_ACCESS => SDRAM_WIDTH_32BIT_ACCESS,
	REFRESH => SDRAM_REFRESH,
	ADDRESS_IN => SDRAM_ADDR,
	DATA_IN => SDRAM_DI,
	SDRAM_DQ => SDRAM_DQ,
	COMPLETE => SDRAM_REQUEST_COMPLETE,
	SDRAM_BA0 => SDRAM_BA(0),
	SDRAM_BA1 => SDRAM_BA(1),
	SDRAM_CKE => SDRAM_CKE,
	SDRAM_CS_N => SDRAM_nCS,
	SDRAM_RAS_N => SDRAM_nRAS,
	SDRAM_CAS_N => SDRAM_nCAS,
	SDRAM_WE_N => SDRAM_nWE,
	SDRAM_ldqm => SDRAM_DQML,
	SDRAM_udqm => SDRAM_DQMH,
	DATA_OUT => SDRAM_DO,
	SDRAM_ADDR => SDRAM_A,
	reset_client_n => SDRAM_RESET_N
);

ROM_ADDR <= SDRAM_ADDR(10 downto 0);

RAM_DATA <= x"FFFFFF"&ROM_DATA  when SDRAM_ADDR(24 downto 14) = "00111000001"  else
            (others=>'1')        when SDRAM_ADDR(24 downto 20) = "00111" else
            SDRAM_DO;

SDRAM_READY <= SDRAM_RESET_N;
areset_n <= (SDRAM_RESET_N and not(reset_atari));

process(clk)
	variable old_reset : std_logic := '1';
begin
	if rising_edge(clk) then
		if (old_reset = '1' and areset_n = '0') then
			cold_reset_request <= '0';
		else
			cold_reset_request <= cold_reset_request or cold_reset_menu;
		end if;
		old_reset := areset_n;
	end if;
end process;

pause_atari <= SET_PAUSE_IN or OSD_PAUSE;
reset_atari <= SET_RESET_IN;
HOT_KEYS <= FKEYS(8) & (FKEYS(9) or cold_reset_request) & '0';
CPU_HALT <= pause_atari;

END vhdl;
