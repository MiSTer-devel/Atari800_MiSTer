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

signal covox_channel0 : std_logic_vector(7 downto 0);
signal covox_channel1 : std_logic_vector(7 downto 0);
signal covox_channel2 : std_logic_vector(7 downto 0);
signal covox_channel3 : std_logic_vector(7 downto 0);

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

signal POKEY_IRQ : std_logic_vector(3 downto 0);

SIGNAL	ADDR_IN : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	WRITE_DATA : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	WRITE_N : STD_LOGIC;
SIGNAL	DEVICE_ADDR : STD_LOGIC_VECTOR(3 downto 0);
SIGNAL	DO_MUX : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL	DRIVE_DO_MUX : STD_LOGIC;
signal	readreq_s : std_logic;
signal	writereq_s : std_logic;

signal covox_write_enable : std_logic;

signal FANCY_ENABLE : std_logic;

signal SAMPLE_IRQ : std_logic;

-- config
-- regs
signal DETECT_RIGHT_REG : std_logic;
signal IRQ_EN_REG : std_logic;
signal CHANNEL_MODE_REG : std_logic;
signal SATURATE_REG : std_logic;
signal POST_DIVIDE_REG : std_logic_vector(7 downto 4);	
signal GTIA_ENABLE_REG : std_logic_vector(3 downto 2);
--signal ADC_VOLUME_REG : std_logic_vector(1 downto 0);
signal SIO_DATA_VOLUME_REG : std_logic_vector(1 downto 0);
signal VERSION_LOC_REG : std_logic_vector(2 downto 0);
signal PAL_REG : std_logic;
	
signal DETECT_RIGHT_NEXT : std_logic;
signal IRQ_EN_NEXT : std_logic;
signal CHANNEL_MODE_NEXT : std_logic;
signal SATURATE_NEXT : std_logic;
signal POST_DIVIDE_NEXT : std_logic_vector(7 downto 4);
signal GTIA_ENABLE_NEXT : std_logic_vector(3 downto 2);
--signal ADC_VOLUME_NEXT : std_logic_vector(1 downto 0);
signal SIO_DATA_VOLUME_NEXT : std_logic_vector(1 downto 0);
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

BEGIN

pokey_mixer_both : entity work.pokey_mixer_mux
PORT MAP(CLK => CLK,
	ENABLE_179 => ENABLE_179,
	GTIA_SOUND => GTIA_SOUND,
	SIO_AUDIO => SIO_AUDIO,
	CHANNEL_L_0 => POKEY_CHANNEL0(0),
	CHANNEL_L_1 => POKEY_CHANNEL1(0),
	CHANNEL_L_2 => POKEY_CHANNEL2(0),
	CHANNEL_L_3 => POKEY_CHANNEL3(0),
	COVOX_CHANNEL_L_0 => covox_channel0,
	COVOX_CHANNEL_L_1 => covox_channel1,
	CHANNEL_R_0 => POKEY_CHANNEL0(1),
	CHANNEL_R_1 => POKEY_CHANNEL1(1),
	CHANNEL_R_2 => POKEY_CHANNEL2(1),
	CHANNEL_R_3 => POKEY_CHANNEL3(1),
	COVOX_CHANNEL_R_0 => covox_channel2,
	COVOX_CHANNEL_R_1 => covox_channel3,
	VOLUME_OUT_L => AUDIO_L_pre,
	VOLUME_OUT_R => AUDIO_R_pre);

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
end generate other_pokeys;

covox1 : entity work.covox
PORT map(clk => clk,
		reset_n => reset_n,
		addr => ADDR_IN(1 downto 0),
		data_in => WRITE_DATA,
		wr_en => covox_write_enable,
		covox_channel0 => covox_channel0,
		covox_channel1 => covox_channel1,
		covox_channel2 => covox_channel2,
		covox_channel3 => covox_channel3);


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
		--ADC_VOLUME_REG <= "11"; -- 0=silent,1=1x,2=2x,3=4x
		SIO_DATA_VOLUME_REG <= "10"; -- 0=silent,1=quieter,2=normal,3=louder
		CONFIG_ENABLE_REG <= '0';
		VERSION_LOC_REG <= (others=>'0');
		PAL_REG <= '1';

		--PSG_FREQ_REG <= "00"; --2MHz
		--PSG_STEREOMODE_REG <= "01"; --Polish
		--PSG_PROFILESEL_REG <= "00"; --Simple log
		--PSG_ENVELOPE16_REG <= '0'; --32 step

		--SID_FILTER1_REG <= "010"; -- 0=8580,1=6581,2=digifix
		--SID_FILTER2_REG <= "010"; -- 0=8580,1=6581,2=digifix

		RESTRICT_CAPABILITY_REG <= (others=>'1');
		CHANNEL_EN_REG <= (others=>'1');

		--MIXER_SIGNED_REG(0) <= to_signed(0,16);
		--MIXER_SIGNED_REG(1) <= to_signed(0,16);
		--MIXER_SIGNED_REG(2) <= to_signed(0,16);
		--MIXER_SIGNED_REG(3) <= to_signed(0,16);
		--MIX_SEL1_REG <= (others=>'0');
		--MIX_SEL2_REG <= (others=>'0');
	elsif (clk'event and clk='1') then
		DETECT_RIGHT_REG <= DETECT_RIGHT_NEXT;
		IRQ_EN_REG <= IRQ_EN_NEXT;
		CHANNEL_MODE_REG <= CHANNEL_MODE_NEXT;
		SATURATE_REG <= SATURATE_NEXT;
		POST_DIVIDE_REG <= POST_DIVIDE_NEXT;
		GTIA_ENABLE_REG <= GTIA_ENABLE_NEXT;
		--ADC_VOLUME_REG <= ADC_VOLUME_NEXT;
		SIO_DATA_VOLUME_REG <= SIO_DATA_VOLUME_NEXT;
		CONFIG_ENABLE_REG <= CONFIG_ENABLE_NEXT;
		VERSION_LOC_REG <= VERSION_LOC_NEXT;
		PAL_REG <= PAL_NEXT;

		--PSG_FREQ_REG <= PSG_FREQ_NEXT;
		--PSG_STEREOMODE_REG <= PSG_STEREOMODE_NEXT;
		--PSG_PROFILESEL_REG <= PSG_PROFILESEL_NEXT;
		--PSG_ENVELOPE16_REG <= PSG_ENVELOPE16_NEXT;

		--SID_FILTER1_REG <= SID_FILTER1_NEXT;
		--SID_FILTER2_REG <= SID_FILTER2_NEXT;

		RESTRICT_CAPABILITY_REG <= RESTRICT_CAPABILITY_NEXT;
		CHANNEL_EN_REG <= CHANNEL_EN_NEXT;

		--MIXER_SIGNED_REG <= MIXER_SIGNED_NEXT;
		--MIX_SEL1_REG <= MIX_SEL1_NEXT;
		--MIX_SEL2_REG <= MIX_SEL2_NEXT;
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
	--request,
	RESTRICT_CAPABILITY_REG, readreq_s, writereq_s
	)
	variable writereq : std_logic;
	variable readreq : std_logic;
	variable enable_region : std_logic;
begin
	writereq := not(write_n); -- and request;
	readreq := write_n; -- and request;
	
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
	--ADC_VOLUME_REG,
	SIO_DATA_VOLUME_REG,
	VERSION_LOC_REG,
	--PSG_FREQ_REG,
	--PSG_STEREOMODE_REG,
	--PSG_PROFILESEL_REG,
	--PSG_ENVELOPE16_REG,
	--SID_FILTER1_REG, SID_FILTER2_REG,
	RESTRICT_CAPABILITY_REG,
	CHANNEL_EN_REG,
	--MIX_SEL1_REG, MIX_SEL2_REG,
	PAL_REG
)
begin
	SATURATE_NEXT <= SATURATE_REG;
	CHANNEL_MODE_NEXT <= CHANNEL_MODE_REG;
	IRQ_EN_NEXT <= IRQ_EN_REG;
	DETECT_RIGHT_NEXT <= DETECT_RIGHT_REG;

	POST_DIVIDE_NEXT <= POST_DIVIDE_REG;
	
	GTIA_ENABLE_NEXT <= GTIA_ENABLE_REG;

	-- ADC_VOLUME_NEXT <= ADC_VOLUME_REG;
	SIO_DATA_VOLUME_NEXT <= SIO_DATA_VOLUME_REG;
	
	CONFIG_ENABLE_NEXT <= CONFIG_ENABLE_REG;
	
	VERSION_LOC_NEXT <= VERSION_LOC_REG;

	--PSG_FREQ_NEXT <= PSG_FREQ_REG;
	--PSG_STEREOMODE_NEXT <= PSG_STEREOMODE_REG;
	--PSG_PROFILESEL_NEXT <= PSG_PROFILESEL_REG;
	--PSG_ENVELOPE16_NEXT <= PSG_ENVELOPE16_REG;

	--SID_FILTER1_NEXT <= SID_FILTER1_REG;
	--SID_FILTER2_NEXT <= SID_FILTER2_REG;

	RESTRICT_CAPABILITY_NEXT <= RESTRICT_CAPABILITY_REG;
	CHANNEL_EN_NEXT <= CHANNEL_EN_REG;

	PAL_NEXT <= PAL_REG;

	--MIX_SEL1_NEXT <= MIX_SEL1_REG;
	--MIX_SEL2_NEXT <= MIX_SEL2_REG;

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
			--ADC_VOLUME_NEXT <= WRITE_DATA(5 downto 4);
			SIO_DATA_VOLUME_NEXT <= WRITE_DATA(7 downto 6);
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

		--if (addr_decoded4(6)='1') then
		--	SID_FILTER1_NEXT <= WRITE_DATA(2 downto 0);
		--	SID_FILTER2_NEXT <= WRITE_DATA(6 downto 4);
		--end if;

		if (addr_decoded4(7)='1') then
			RESTRICT_CAPABILITY_NEXT(4 downto 0) <= WRITE_DATA(4 downto 0);
		end if;

		--if (addr_decoded4(8)='1') then
		--	MIX_SEL1_NEXT <= WRITE_DATA(2 downto 0);
		--	MIX_SEL2_NEXT <= WRITE_DATA(6 downto 4);
		--end if;

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
--ADC_VOLUME_REG,
SIO_DATA_VOLUME_REG, 
--PSG_FREQ_REG, PSG_STEREOMODE_REG, PSG_PROFILESEL_REG, PSG_ENVELOPE16_REG,
--SID_FILTER1_REG, SID_FILTER2_REG,
RESTRICT_CAPABILITY_REG,
CHANNEL_EN_REG,
--MIX_SEL1_REG, MIX_SEL2_REG,
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

	ACTUAL_CAPABILITY(1 downto 0) := "11"; --bit1=quad

	--if (enable_sid=1) then
	--	ACTUAL_CAPABILITY(2) := '1';

	--if (enable_psg=1) then
	--	ACTUAL_CAPABILITY(3) := '1';

	--if (enable_covox=1) then
	--	ACTUAL_CAPABILITY(4) := '1';

	--if (enable_sample=1) then
	--	ACTUAL_CAPABILITY(5) := '1';

	ACTUAL_CAPABILITY(7) := '1';
	
	if (addr_decoded4(1)='1') then
		CONFIG_DO <= ACTUAL_CAPABILITY and "11"&RESTRICT_CAPABILITY_REG(4)&RESTRICT_CAPABILITY_REG;
	end if;
	
	if (addr_decoded4(2)='1') then
		CONFIG_DO <= POST_DIVIDE_REG & "0000";
	end if;	
	
	if (addr_decoded4(3)='1') then
		CONFIG_DO <= (others=>'0');
		CONFIG_DO(3 downto 2) <= GTIA_ENABLE_REG;
		CONFIG_DO(7 downto 6) <= SIO_DATA_VOLUME_REG;
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

	--if (addr_decoded4(6)='1') then -- different use on sidmax
	--	CONFIG_DO <= (others=>'0');
	--	CONFIG_DO(2 downto 0) <= SID_FILTER1_REG;
	--	-- (3 downto 3) reserved in case we want more filter options
	--	CONFIG_DO(6 downto 4) <= SID_FILTER2_REG;
	--	-- (7 downto 7) reserved in case we want more filter options
	--end if;

	if (addr_decoded4(7)='1') then
		CONFIG_DO(4 downto 0) <= RESTRICT_CAPABILITY_REG(4 downto 0);
	end if;

	--if (addr_decoded4(8)='1') then -- different use on sidmax
	--	CONFIG_DO(2 downto 0) <= MIX_SEL1_REG;
	--	CONFIG_DO(6 downto 4) <= MIX_SEL2_REG;
	--end if;

	if (addr_decoded4(9)='1') then
		CONFIG_DO(4 downto 0) <= '0'&CHANNEL_EN_REG&"00";
	end if;

	if (addr_decoded4(12)='1') then
		CONFIG_DO <= x"01";
	end if;		

end process;

FANCY_ENABLE <= STEREO;
ADDR_IN <= ADDR;
WRITE_DATA <= DATA_IN;
WRITE_N <= not(WR_EN);

DATA_OUT <= DO_MUX;
DRIVE_DATA_OUT <= DRIVE_DO_MUX;

-- TODO
SAMPLE_IRQ <= '0';
covox_write_enable <= SAMPLE_WRITE_ENABLE;

-- TODO
AUDIO_L <= AUDIO_L_pre;
AUDIO_R <= AUDIO_R_pre when STEREO = '1' else AUDIO_L_pre;

IRQ_N_OUT <= (not(IRQ_EN_REG) or (and_reduce(POKEY_IRQ))) and (IRQ_EN_REG or POKEY_IRQ(0)) and not(SAMPLE_IRQ);

END vhdl;
