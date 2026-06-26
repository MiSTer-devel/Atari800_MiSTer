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
	SIO_SOUND : IN STD_LOGIC_VECTOR(7 downto 0);

    -- sound output
    AUDIO_L : OUT STD_LOGIC_VECTOR(15 downto 0);
	AUDIO_R : OUT STD_LOGIC_VECTOR(15 downto 0);

	POT_RESET : out std_logic
);
END pokeymax;

ARCHITECTURE vhdl OF pokeymax IS

--signal AUDIO_L_pre : std_logic_vector(15 downto 0);
--signal AUDIO_R_pre : std_logic_vector(15 downto 0);

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
		ADC_VOLUME_REG <= "10"; -- 0=silent,1=1x,2=2x,3=4x
		--SIO_DATA_VOLUME_REG <= "10"; -- 0=silent,1=quieter,2=normal,3=louder
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
		ADC_VOLUME_REG <= ADC_VOLUME_NEXT;
		--SIO_DATA_VOLUME_REG <= SIO_DATA_VOLUME_NEXT;
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
	ADC_VOLUME_REG,
	--SIO_DATA_VOLUME_REG,
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

	ADC_VOLUME_NEXT <= ADC_VOLUME_REG;
	--SIO_DATA_VOLUME_NEXT <= SIO_DATA_VOLUME_REG;
	
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
ADC_VOLUME_REG,
--SIO_DATA_VOLUME_REG, 
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

pokey_mixer_all : entity work.pokey_mixer_mux4
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
	SATURATE => SATURATE_REG);

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
	L_CH2 => to_signed(0, 16), -- SAMPLE_AUDIO_SIGNED(0),
	R_CH2 => to_signed(0, 16), -- SAMPLE_AUDIO_SIGNED(1),
	L_CH3 => to_signed(0, 16), -- SID_AUDIO_SIGNED(0),
	R_CH3 => to_signed(0, 16), -- SID_AUDIO_SIGNED(1),
	L_CH4 => to_signed(0, 16), -- PSG_AUDIO_SIGNED(0),
	R_CH4 => to_signed(0, 16), -- PSG_AUDIO_SIGNED(1),
	B_CH0 => GTIA_AUDIO_SIGNED,
	B_CH1 => SIO_AUDIO_SIGNED,

	MUTE_CHANNEL => '0', -- mixer_mute,

	--S_AUDIO  => mixer_audio_out,
	--S_LEFT => mixer_l_enable,
	--S_RIGHT => mixer_r_enable,
	--S_CHANNEL => mixer_audio_out_channel,

	--AUDIO_0_SIGNED => AUDIO_MIXED_SIGNED(0),
	--AUDIO_1_SIGNED => AUDIO_MIXED_SIGNED(1),
	AUDIO_2_SIGNED => AUDIO_MIXED_SIGNED(2),
	AUDIO_3_SIGNED => AUDIO_MIXED_SIGNED(3)
);

filter_left : entity work.simple_low_pass_filter
PORT MAP
(
	CLK => clk,
	AUDIO_IN => std_logic_vector(AUDIO_MIXED_SIGNED(2)),
	SAMPLE_IN => enable_179,
	AUDIO_OUT => AUDIO_L
);

filter_right : entity work.simple_low_pass_filter
PORT MAP
(
	CLK => clk,
	AUDIO_IN => std_logic_vector(AUDIO_MIXED_SIGNED(3)),
	SAMPLE_IN => enable_179,
	AUDIO_OUT => AUDIO_R
);

FANCY_ENABLE <= STEREO;
ADDR_IN <= ADDR;
WRITE_DATA <= DATA_IN;
WRITE_N <= not(WR_EN);

DATA_OUT <= DO_MUX;
DRIVE_DATA_OUT <= DRIVE_DO_MUX;

-- TODO
SAMPLE_IRQ <= '0';
covox_write_enable <= SAMPLE_WRITE_ENABLE;

IRQ_N_OUT <= (not(IRQ_EN_REG) or (and_reduce(POKEY_IRQ))) and (IRQ_EN_REG or POKEY_IRQ(0)) and not(SAMPLE_IRQ);

END vhdl;
