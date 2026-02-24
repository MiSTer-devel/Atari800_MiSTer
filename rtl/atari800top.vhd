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

ENTITY atari800top IS 
PORT
(
	CLK        : IN  STD_LOGIC;
	CLK_SDRAM  : IN  STD_LOGIC;
	RESET_N    : IN  STD_LOGIC;
	ARESET     : OUT STD_LOGIC;

	PAL        : IN  STD_LOGIC;
	CLIP_SIDES : IN  STD_LOGIC;
	VGA_VS     : OUT STD_LOGIC;
	VGA_HS     : OUT STD_LOGIC;
	VGA_BLANK  : OUT STD_LOGIC;
	VGA_PIXCE  : OUT STD_LOGIC;
	VGA_B      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	VGA_G      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	VGA_R      : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
	interlace_enable : in std_logic;
	interlace_field : out std_logic;
	interlace : out std_logic;

	HBLANK     : OUT STD_LOGIC;
	VBLANK     : OUT STD_LOGIC;

	STEREO     : IN  STD_LOGIC;
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

	TURBOFREEZER_ROM_LOADED : in std_logic;
	OSD_PAUSE : in std_logic;
	SDRAM_READY : out std_logic;
	
	HPS_DMA_ADDR : in std_logic_vector(25 downto 0);
	HPS_DMA_REQ : in std_logic;
	HPS_DMA_READ_ENABLE : in std_logic;
	HPS_DMA_DATA_OUT : in std_logic_vector(7 downto 0);
	HPS_DMA_DATA_IN : out std_logic_vector(7 downto 0);
	HPS_DMA_READY : out std_logic;

	SET_RESET_IN : in std_logic;
	SET_PAUSE_IN : in std_logic;
	SET_FREEZER_IN : in std_logic;
	SET_RESET_RNMI_IN : in std_logic;
	SET_OPTION_FORCE_IN : in std_logic;
	CART1_SELECT_IN : in std_logic_vector(7 downto 0);
	CART2_SELECT_IN : in std_logic_vector(7 downto 0);
	HOT_KEYS : out std_logic_vector(2 downto 0);

	UART_ADDR : in std_logic_vector(4 downto 0);
	UART_ENABLE : in std_logic;
	UART_WR : in std_logic;
	UART_DATA_WRITE : in std_logic_vector(7 downto 0);
	UART_DATA_READ : out std_logic_vector(15 downto 0);

	PS2_KEY    : IN  STD_LOGIC_VECTOR(10 downto 0);

	CPU_SPEED  : IN  STD_LOGIC_VECTOR(5 downto 0);
	RAM_SIZE   : IN  STD_LOGIC_VECTOR(2 downto 0);
	OS_MODE_800   : IN  STD_LOGIC;
	PBI_MODE      : IN  STD_LOGIC;
	XEX_LOADER_MODE : IN  STD_LOGIC;
	WARM_RESET_MENU : IN STD_LOGIC;
	COLD_RESET_MENU : IN STD_LOGIC;
	RTC        : IN STD_LOGIC_VECTOR(64 downto 0);
	VBXE_MODE  : IN STD_LOGIC_VECTOR(2 downto 0) := "000";
	VBXE_PALETTE_RGB : IN STD_LOGIC_VECTOR(2 downto 0);
	VBXE_PALETTE_INDEX : IN STD_LOGIC_VECTOR(7 downto 0);
	VBXE_PALETTE_COLOR : IN STD_LOGIC_VECTOR(6 downto 0);

	CPU_HALT   : OUT STD_LOGIC;
	JOY1X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY1Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY2X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY2Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY3X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY3Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY4X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY4Y      : IN  STD_LOGIC_VECTOR(7 downto 0);

	JOY1       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
	JOY2       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
	JOY3       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);
	JOY4       : IN  STD_LOGIC_VECTOR(13 DOWNTO 0);

	SIO_MODE   : IN  STD_LOGIC := '0';
	SIO_IN     : IN  STD_LOGIC;
	SIO_OUT    : OUT STD_LOGIC;
	SIO_CLKOUT : OUT STD_LOGIC;
	SIO_CLKIN  : IN  STD_LOGIC;
	SIO_CMD    : OUT STD_LOGIC;
	SIO_PROC   : IN  STD_LOGIC;
	SIO_MOTOR  : OUT STD_LOGIC;
	SIO_IRQ    : IN  STD_LOGIC
);

END atari800top;

ARCHITECTURE vhdl OF atari800top IS 

SIGNAL CONSOL_OPTION :  STD_LOGIC;
SIGNAL CONSOL_SELECT :  STD_LOGIC;
SIGNAL CONSOL_START :  STD_LOGIC;
SIGNAL FKEYS : std_logic_vector(11 downto 0);

signal capslock_pressed : std_logic;
signal capsheld_next : std_logic;
signal capsheld_reg : std_logic;

signal JOY1_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY2_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY3_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY4_n :  STD_LOGIC_VECTOR(4 DOWNTO 0);
signal JOY    :  STD_LOGIC_VECTOR(13 DOWNTO 0);
signal JOY1_X :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY2_X :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY3_X :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY4_X :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY1_Y :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY2_Y :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY3_Y :  STD_LOGIC_VECTOR(7 downto 0);
signal JOY4_Y :  STD_LOGIC_VECTOR(7 downto 0);

SIGNAL KEYBOARD_RESPONSE :  STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL KEYBOARD_SCAN :  STD_LOGIC_VECTOR(5 DOWNTO 0);

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

-- dma/virtual drive
signal DMA_ADDR_FETCH : std_logic_vector(25 downto 0);
signal DMA_WRITE_DATA : std_logic_vector(31 downto 0);
signal DMA_FETCH : std_logic;
signal DMA_32BIT_WRITE_ENABLE : std_logic;
signal DMA_16BIT_WRITE_ENABLE : std_logic;
signal DMA_8BIT_WRITE_ENABLE : std_logic;
signal DMA_READ_ENABLE : std_logic;
signal DMA_MEMORY_READY : std_logic;
signal DMA_MEMORY_DATA : std_logic_vector(31 downto 0);

signal emu_pokey_enable : std_logic;
signal emu_sio_txd : std_logic;
signal emu_sio_rxd : std_logic;
signal emu_sio_command : std_logic;
signal emu_sio_clk : std_logic;

signal sio_rxd : std_logic;
signal sio_txd : std_logic;
signal sio_command : std_logic;
signal sio_clk : std_logic;

signal OLD_OUT : STD_LOGIC_VECTOR(7 DOWNTO 0);
signal old_command : std_logic;
signal end_command : std_logic;

-- system control from zpu
signal reset_atari : std_logic;
signal reset_rnmi_atari : std_logic;
signal pause_atari : std_logic;

-- ps2
signal PS2_KEYS : STD_LOGIC_VECTOR(511 downto 0);

-- turbo freezer!
signal freezer_activate: std_logic;

-- paddles
signal paddle_1 : std_logic_vector(2 downto 0);
signal paddle_2 : std_logic_vector(2 downto 0);
signal paddle_3 : std_logic_vector(2 downto 0);
signal paddle_4 : std_logic_vector(2 downto 0);

signal areset_n   : std_logic;
signal option_tmp : std_logic;
signal warm_reset_request : std_logic;
signal cold_reset_request : std_logic;

BEGIN

areset_n <= (SDRAM_RESET_N and not(reset_atari));
areset <= not areset_n;
SDRAM_READY <= SDRAM_RESET_N;

process(clk)
	variable cnt : integer := 0;
	variable old_reset : std_logic := '1';
begin
	if rising_edge(clk) then
		if (old_reset = '1' and areset_n = '0') then
			paddle_1 <= "000";
			paddle_2 <= "000";
			paddle_3 <= "000";
			paddle_4 <= "000";
			cnt := 0;
			option_tmp <= '0';
			warm_reset_request <= '0';
			cold_reset_request <= '0';
		else
			if JOY1(6 downto 4) /= "000" then paddle_1(0) <= '0';   end if;
			if JOY1(5) = '1'             then paddle_1(1) <= '1';   end if;
			if JOY1(6) = '1'             then paddle_1(2) <= '1';   end if;
			if JOY1(8 downto 7) /= "00"  then paddle_1    <= "001"; end if;

			if JOY2(6 downto 4) /= "000" then paddle_2(0) <= '0';   end if;
			if JOY2(5) = '1'             then paddle_2(1) <= '1';   end if;
			if JOY2(6) = '1'             then paddle_2(2) <= '1';   end if;
			if JOY2(8 downto 7) /= "00"  then paddle_2    <= "001"; end if;

			if JOY3(6 downto 4) /= "000" then paddle_3(0) <= '0';   end if;
			if JOY3(5) = '1'             then paddle_3(1) <= '1';   end if;
			if JOY3(6) = '1'             then paddle_3(2) <= '1';   end if;
			if JOY3(8 downto 7) /= "00"  then paddle_3    <= "001"; end if;

			if JOY4(6 downto 4) /= "000" then paddle_4(0) <= '0';   end if;
			if JOY4(5) = '1'             then paddle_4(1) <= '1';   end if;
			if JOY4(6) = '1'             then paddle_4(2) <= '1';   end if;
			if JOY4(8 downto 7) /= "00"  then paddle_4    <= "001"; end if;

			if cnt < 50000000 then
				cnt := cnt + 1;
				option_tmp <= option_tmp or SET_OPTION_FORCE_IN or JOY(5);
			else
				option_tmp <= '0';
			end if;
			warm_reset_request <= not(reset_rnmi_atari) and (warm_reset_request or warm_reset_menu);
			cold_reset_request <= cold_reset_request or cold_reset_menu;
		end if;

		old_reset := areset_n;
	end if;
end process;

JOY1_n <= '1'&not(JOY1(8)&JOY1(7))&"11" when paddle_1(0) = '1' else not(JOY1(4)&JOY1(0)&JOY1(1)&JOY1(2)&JOY1(3)); --FRLDU
JOY1_X <= JOY1X when paddle_1(0) = '1' else X"80" when (paddle_1(1) = '0' or JOY1(5) = '1') else X"70";
JOY1_Y <= JOY1Y when paddle_1(0) = '1' else X"80" when (paddle_1(2) = '0' or JOY1(6) = '1') else X"70";

JOY2_n <= '1'&not(JOY2(8)&JOY2(7))&"11" when paddle_2(0) = '1' else not(JOY2(4)&JOY2(0)&JOY2(1)&JOY2(2)&JOY2(3)); --FRLDU
JOY2_X <= JOY2X when paddle_2(0) = '1' else X"80" when (paddle_2(1) = '0' or JOY2(5) = '1') else X"70";
JOY2_Y <= JOY2Y when paddle_2(0) = '1' else X"80" when (paddle_2(2) = '0' or JOY2(6) = '1') else X"70";

JOY3_n <= '1'&not(JOY3(8)&JOY3(7))&"11" when paddle_3(0) = '1' else not(JOY3(4)&JOY3(0)&JOY3(1)&JOY3(2)&JOY3(3)); --FRLDU
JOY3_X <= JOY3X when paddle_3(0) = '1' else X"80" when (paddle_3(1) = '0' or JOY3(5) = '1') else X"70";
JOY3_Y <= JOY3Y when paddle_3(0) = '1' else X"80" when (paddle_3(2) = '0' or JOY3(6) = '1') else X"70";

JOY4_n <= '1'&not(JOY4(8)&JOY4(7))&"11" when paddle_4(0) = '1' else not(JOY4(4)&JOY4(0)&JOY4(1)&JOY4(2)&JOY4(3)); --FRLDU
JOY4_X <= JOY4X when paddle_4(0) = '1' else X"80" when (paddle_4(1) = '0' or JOY4(5) = '1') else X"70";
JOY4_Y <= JOY4Y when paddle_4(0) = '1' else X"80" when (paddle_4(2) = '0' or JOY4(6) = '1') else X"70";

-- PS2 to pokey
keyboard_map1 : entity work.ps2_to_atari800
generic map (ps2_enable => 0, direct_enable => 1)
PORT MAP
( 
	CLK => clk,
	RESET_N => reset_n,

	INPUT => x"000"&"000"&ps2_key(9)&"000"&ps2_key(8)&x"0"&ps2_key(7 downto 0),
	INPUT2 => JOY(13 downto 9),

	KEYBOARD_SCAN => KEYBOARD_SCAN,
	KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,

	CONSOL_START => CONSOL_START,
	CONSOL_SELECT => CONSOL_SELECT,
	CONSOL_OPTION => CONSOL_OPTION,

	FKEYS => FKEYS,
	FREEZER_ACTIVATE => freezer_activate,

	PS2_KEYS_NEXT_OUT => open,
	PS2_KEYS => ps2_keys
);

atarixl_simple_sdram1 : entity work.atari800core_simple_sdram
GENERIC MAP
(
	cycle_length => 16,
	video_bits => 8,
	palette => 1,
	internal_rom => 0,
	internal_ram => 0
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
	interlace_enable => interlace_enable,
	interlace => interlace,
	interlace_field => interlace_field,

	HBLANK => HBLANK,
	VBLANK => VBLANK,

	STEREO => STEREO,
	AUDIO_L => AUDIO_L,
	AUDIO_R => AUDIO_R,

	JOY1_n => JOY1_n,
	JOY2_n => JOY2_n,
	JOY3_n => JOY3_n,
	JOY4_n => JOY4_n,

	PADDLE0 => signed(JOY1_X),
	PADDLE1 => signed(JOY1_Y),
	PADDLE2 => signed(JOY2_X),
	PADDLE3 => signed(JOY2_Y),
	PADDLE4 => signed(JOY3_X),
	PADDLE5 => signed(JOY3_Y),
	PADDLE6 => signed(JOY4_X),
	PADDLE7 => signed(JOY4_Y),

	KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,
	KEYBOARD_SCAN => KEYBOARD_SCAN,

	SIO_COMMAND => sio_command,
	SIO_RXD => sio_rxd,
	SIO_TXD => sio_txd,
	SIO_CLOCK => sio_clk,
	SIO_CLOCK_IN => SIO_CLKIN,
	SIO_PROC => SIO_PROC,
	SIO_IRQ  => SIO_IRQ,
	SIO_MOTOR => SIO_MOTOR,
	ENABLE_179_EARLY => emu_pokey_enable,

	CONSOL_OPTION => CONSOL_OPTION or option_tmp,
	CONSOL_SELECT => CONSOL_SELECT,
	CONSOL_START => CONSOL_START,

	SDRAM_REQUEST => SDRAM_REQUEST,
	SDRAM_REQUEST_COMPLETE => SDRAM_REQUEST_COMPLETE,
	SDRAM_READ_ENABLE => SDRAM_READ_ENABLE,
	SDRAM_WRITE_ENABLE => SDRAM_WRITE_ENABLE,
	SDRAM_ADDR => SDRAM_ADDR,
	SDRAM_DO => SDRAM_DO,
	SDRAM_DI => SDRAM_DI,
	SDRAM_32BIT_WRITE_ENABLE => SDRAM_WIDTH_32bit_ACCESS,
	SDRAM_16BIT_WRITE_ENABLE => SDRAM_WIDTH_16bit_ACCESS,
	SDRAM_8BIT_WRITE_ENABLE => SDRAM_WIDTH_8bit_ACCESS,
	SDRAM_REFRESH => SDRAM_REFRESH,

	DMA_FETCH => HPS_DMA_REQ,
	DMA_READ_ENABLE => HPS_DMA_READ_ENABLE,
	DMA_32BIT_WRITE_ENABLE => '0',
	DMA_16BIT_WRITE_ENABLE => '0',
	DMA_8BIT_WRITE_ENABLE => '1',
	DMA_ADDR => HPS_DMA_ADDR,
	DMA_WRITE_DATA => x"000000" & HPS_DMA_DATA_OUT,
	MEMORY_READY_DMA => HPS_DMA_READY,
	DMA_MEMORY_DATA => dma_memory_data,

	RAM_SELECT => RAM_SIZE,
	PAL => PAL,
	CLIP_SIDES => CLIP_SIDES,
	RESET_RNMI => reset_rnmi_atari,
	ATARI800MODE => OS_MODE_800,
	PBI_ROM_MODE => PBI_MODE,
	XEX_LOADER_MODE => XEX_LOADER_MODE,
	RTC => RTC,
	VBXE_SWITCH => VBXE_MODE(0) or VBXE_MODE(1),
	VBXE_REG_BASE => VBXE_MODE(1),
	VBXE_NTSC_FIX => VBXE_MODE(2),
	VBXE_PALETTE_RGB => VBXE_PALETTE_RGB,
	VBXE_PALETTE_INDEX => VBXE_PALETTE_INDEX,
	VBXE_PALETTE_COLOR => VBXE_PALETTE_COLOR,

	HALT => pause_atari,
	THROTTLE_COUNT_6502 => CPU_SPEED,
	emulated_cartridge_select => CART1_SELECT_IN,
	emulated_cartridge2_select => CART2_SELECT_IN,
	freezer_enable => SET_FREEZER_IN and TURBOFREEZER_ROM_LOADED,
	freezer_activate => freezer_activate
);

SIO_CLKOUT <= sio_clk;
SIO_OUT    <= sio_txd;
SIO_CMD    <= sio_command;

emu_sio_rxd     <= sio_txd     when SIO_MODE = '0' else '1';
emu_sio_command <= sio_command when SIO_MODE = '0' else '1';
emu_sio_clk     <= sio_clk     when SIO_MODE = '0' else '1';

sio_rxd <= emu_sio_txd when SIO_MODE = '0' else SIO_IN;

HPS_DMA_DATA_IN <= dma_memory_data(7 downto 0);

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

joy <= joy1 or joy2 or joy3 or joy4;

HOT_KEYS <= ps2_keys(16#111#) & (FKEYS(9) or cold_reset_request) & (FKEYS(8) or warm_reset_request);

pause_atari <= set_pause_in or OSD_PAUSE;
reset_atari <= set_reset_in;
reset_rnmi_atari <= set_reset_rnmi_in;

CPU_HALT <= pause_atari;

simple_uart_inst : entity work.sio_handler
PORT  MAP
(
	CLK => CLK,
	ADDR => UART_ADDR,
	CPU_DATA_IN => UART_DATA_WRITE,
	EN => UART_ENABLE,
	WR_EN => UART_WR,
	DATA_OUT => UART_DATA_READ,

	RESET_N => RESET_N and sdram_reset_n,

	POKEY_ENABLE => emu_pokey_enable,

	SIO_DATA_IN  => emu_sio_txd,
	SIO_COMMAND => emu_sio_command,
	SIO_DATA_OUT => emu_sio_rxd,
	SIO_CLK_OUT => emu_sio_clk
);

END vhdl;
