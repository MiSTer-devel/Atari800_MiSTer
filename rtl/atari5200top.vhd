--------------------------------------------------------------------------- -- (c) 2013 mark watson
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

	PS2_KEY    : IN  STD_LOGIC_VECTOR(10 downto 0);
	
	CPU_SPEED  : IN std_logic_vector(5 downto 0);

	CPU_HALT   : OUT STD_LOGIC;
	JOY1X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY1Y      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY2X      : IN  STD_LOGIC_VECTOR(7 downto 0);
	JOY2Y      : IN  STD_LOGIC_VECTOR(7 downto 0);

	JOY1       : IN  STD_LOGIC_VECTOR(20 DOWNTO 0);
	JOY2       : IN  STD_LOGIC_VECTOR(20 DOWNTO 0);

	ZPU_IN2    : IN  STD_LOGIC_VECTOR(7 downto 0);
	ZPU_OUT2   : OUT STD_LOGIC_VECTOR(31 downto 0);
	ZPU_IN3    : IN  STD_LOGIC_VECTOR(31 downto 0);
	ZPU_OUT3   : OUT STD_LOGIC_VECTOR(31 downto 0);
	ZPU_RD     : OUT STD_LOGIC_VECTOR(15 downto 0);
	ZPU_WR     : OUT STD_LOGIC_VECTOR(15 downto 0)
);

END atari5200top;

ARCHITECTURE vhdl OF atari5200top IS 

SIGNAL FKEYS : std_logic_vector(11 downto 0);

signal capslock_pressed : std_logic;
signal capsheld_next : std_logic;
signal capsheld_reg : std_logic;

signal JOY    :  STD_LOGIC_VECTOR(20 DOWNTO 0);

SIGNAL KEYBOARD_RESPONSE :  STD_LOGIC_VECTOR(1 DOWNTO 0);
SIGNAL KEYBOARD_SCAN :  STD_LOGIC_VECTOR(5 DOWNTO 0);
signal controller_select : std_logic_vector(1 downto 0);

signal SDRAM_REQUEST : std_logic;
signal SDRAM_REQUEST_COMPLETE : std_logic;
signal SDRAM_READ_ENABLE :  STD_LOGIC;
signal SDRAM_WRITE_ENABLE : std_logic;
signal SDRAM_ADDR : STD_LOGIC_VECTOR(22 DOWNTO 0);
signal SDRAM_DO : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal SDRAM_DI : STD_LOGIC_VECTOR(31 DOWNTO 0);
signal SDRAM_WIDTH_8bit_ACCESS : std_logic;
signal SDRAM_WIDTH_16bit_ACCESS : std_logic;
signal SDRAM_WIDTH_32bit_ACCESS : std_logic;

signal SDRAM_REFRESH : std_logic;
signal SDRAM_RESET_N : std_logic;

-- dma/virtual drive
signal DMA_ADDR_FETCH : std_logic_vector(23 downto 0);
signal DMA_WRITE_DATA : std_logic_vector(31 downto 0);
signal DMA_FETCH : std_logic;
signal DMA_32BIT_WRITE_ENABLE : std_logic;
signal DMA_16BIT_WRITE_ENABLE : std_logic;
signal DMA_8BIT_WRITE_ENABLE : std_logic;
signal DMA_READ_ENABLE : std_logic;
signal DMA_MEMORY_READY : std_logic;
signal DMA_MEMORY_DATA : std_logic_vector(31 downto 0);

signal ZPU_ADDR_ROM : std_logic_vector(15 downto 0);
signal ZPU_ROM_DATA :  std_logic_vector(31 downto 0);

signal ZPU_OUT1 : std_logic_vector(31 downto 0);

signal zpu_pokey_enable : std_logic;

-- system control from zpu
signal reset_atari : std_logic;
signal pause_atari : std_logic;

-- ps2
signal PS2_KEYS : STD_LOGIC_VECTOR(511 downto 0);

signal BIOS_DATA  : std_logic_vector(7 downto 0);
signal RAM_DATA : std_logic_vector(31 downto 0);

BEGIN

JOY <= JOY1 or JOY2;

-- PS2 to pokey
keyboard_map1 : entity work.ps2_to_atari5200
generic map (ps2_enable => 0, direct_enable => 1)
PORT MAP
( 
	CLK => clk,
	RESET_N => reset_n,
	INPUT => x"000"&"000"&ps2_key(9)&"000"&ps2_key(8)&x"0"&ps2_key(7 downto 0),

	JOY1 => JOY1,
	JOY2 => JOY2,

	CONTROLLER_SELECT => CONTROLLER_SELECT, -- selected stick keyboard/shift button
	
	KEYBOARD_SCAN => KEYBOARD_SCAN,
	KEYBOARD_RESPONSE => KEYBOARD_RESPONSE,

	FKEYS => FKEYS,

	PS2_KEYS => PS2_KEYS
);


atarixl_simple_sdram1 : entity work.atari5200core_simplesdram
GENERIC MAP
(
	cycle_length => 32,
	video_bits => 8,
	palette => 1,
	internal_rom => 0,
	internal_ram => 65536
)
PORT MAP
(
	CLK => CLK,
	RESET_N => RESET_N and SDRAM_RESET_N and not(reset_atari),

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

	AUDIO_L => AUDIO_L,
	AUDIO_R => AUDIO_R,

	JOY1_n => not(JOY1(4)&JOY1(0)&JOY1(1)&JOY1(2)&JOY1(3)), --FRLDU
	JOY2_n => not(JOY2(4)&JOY2(0)&JOY2(1)&JOY2(2)&JOY2(3)), --FRLDU

	JOY1_X => signed(joy1x),
	JOY1_Y => signed(joy1y),
	JOY2_X => signed(joy2x),
	JOY2_Y => signed(joy2y),

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

	DMA_FETCH => dma_fetch,
	DMA_READ_ENABLE => dma_read_enable,
	DMA_32BIT_WRITE_ENABLE => dma_32bit_write_enable,
	DMA_16BIT_WRITE_ENABLE => dma_16bit_write_enable,
	DMA_8BIT_WRITE_ENABLE => dma_8bit_write_enable,
	DMA_ADDR => dma_addr_fetch,
	DMA_WRITE_DATA => dma_write_data,
	MEMORY_READY_DMA => dma_memory_ready,
	DMA_MEMORY_DATA => dma_memory_data, 

	HALT => pause_atari,
	THROTTLE_COUNT_6502 => CPU_SPEED
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
	ADDRESS_IN => "00"&SDRAM_ADDR,
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
bios: work.spram generic map(11,8, "rtl/rom/5200.mif")
port map
(
	clock => clk,

	address => SDRAM_ADDR(10 downto 0),
	q => BIOS_DATA
);

RAM_DATA <= x"FFFFFF"&BIOS_DATA  when SDRAM_ADDR(22 downto 14) = "111000001"  else
            (others=>'1')        when SDRAM_ADDR(22 downto 20) = "111" else
            SDRAM_DO;

zpu: entity work.zpucore
GENERIC MAP
(
	platform => 1
)
PORT MAP
(
	-- standard...
	CLK => CLK,
	RESET_N => RESET_N and sdram_reset_n,

	-- dma bus master (with many waitstates...)
	ZPU_ADDR_FETCH => dma_addr_fetch,
	ZPU_DATA_OUT => dma_write_data,
	ZPU_FETCH => dma_fetch,
	ZPU_32BIT_WRITE_ENABLE => dma_32bit_write_enable,
	ZPU_16BIT_WRITE_ENABLE => dma_16bit_write_enable,
	ZPU_8BIT_WRITE_ENABLE => dma_8bit_write_enable,
	ZPU_READ_ENABLE => dma_read_enable,
	ZPU_MEMORY_READY => dma_memory_ready,
	ZPU_MEMORY_DATA => dma_memory_data, 

	-- rom bus master
	-- data on next cycle after addr
	ZPU_ADDR_ROM => zpu_addr_rom,
	ZPU_ROM_DATA => zpu_rom_data,

	ZPU_ROM_WREN => open,

	-- SIO
	-- Ditto for speaking to Atari, we have a built in Pokey
	ZPU_POKEY_ENABLE => zpu_pokey_enable,
	ZPU_SIO_TXD => open,
	ZPU_SIO_RXD => '1',
	ZPU_SIO_COMMAND => '1',
	ZPU_SIO_CLK => '0',

	-- external control
	-- switches etc. sector DMA blah blah.
	ZPU_IN1 => X"000"&
			'0'&(ps2_keys(16#11F#) or ps2_keys(16#127#)) &
			((ps2_keys(16#76#)&ps2_keys(16#5A#)&ps2_keys(16#174#)&ps2_keys(16#16B#)&ps2_keys(16#172#)&ps2_keys(16#175#)) or (joy(5)&joy(4)&joy(0)&joy(1)&joy(2)&joy(3)))& -- (esc)FRLDU
			(FKEYS(10) and (ps2_keys(16#11f#) or ps2_keys(16#127#)))&(FKEYS(10) and (not ps2_keys(16#11f#)) and (not ps2_keys(16#127#)))&FKEYS(9 downto 0),
	ZPU_IN2 => X"0000"& ZPU_IN2 & x"00",
	ZPU_IN3 => ZPU_IN3,
	ZPU_IN4 => X"00000000",
	
	ZPU_RD => ZPU_RD,
	ZPU_WR => ZPU_WR,

	-- ouputs - e.g. Atari system control, halt, throttle, rom select
	ZPU_OUT1 => zpu_out1,
	ZPU_OUT2 => zpu_out2,
	ZPU_OUT3 => zpu_out3
);

pause_atari <= zpu_out1(0);
reset_atari <= zpu_out1(1);

CPU_HALT <= pause_atari;

zpu_rom1: entity work.spram
generic map(11,32,"firmware/zpu_rom_5200.mif")
port map
(
  clock => clk,
  address => zpu_addr_rom(12 downto 2),
  q => zpu_rom_data
);

enable_179_clock_div_zpu_pokey : entity work.enable_divider
	generic map (COUNT=>32) -- cycle_length
	port map(clk=>clk,reset_n=>reset_n,enable_in=>'1',enable_out=>zpu_pokey_enable);

END vhdl;
