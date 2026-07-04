---------------------------------------------------------------------------
-- (c) 2020 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
use ieee.numeric_std.all;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_MISC.all;

LIBRARY work;

ENTITY SID_top IS 
	GENERIC
	(
		wave_base: std_logic_vector(16 downto 0)
	);
	PORT
	(
		CLK : in std_logic; -- >1MHz, ideally higher for more accurate filter (as long as timing met)
		RESET_N : in std_logic;
		
		ENABLE : in std_logic; -- Typically ~1MHz

		ADDR : in std_logic_vector(4 downto 0); 
		READ_ENABLE : in std_logic;
		WRITE_ENABLE : in std_logic;

		POT_X : in std_logic;
		POT_Y : in std_logic;
		POT_RESET : out std_logic;
		
		DI : in std_logic_vector(7 downto 0);
		DO : out std_logic_vector(7 downto 0);
		DRIVE_DO : out std_logic;
		
		AUDIO : out signed(15 downto 0);

		DEBUG_WV1 : out unsigned(11 downto 0);
		DEBUG_EV1 : out unsigned(7 downto 0);
		DEBUG_AM1 : out signed(15 downto 0);

		sidtype : in std_logic; -- 0=8580 filter, 1=6581 filter
		EXT : in std_logic_vector(1 downto 0); -- 00=GND,01=digifix,10=ADC
		EXT_ADC : in unsigned(15 downto 0);

		rom_addr : out std_logic_vector(16 downto 0);
		rom_data : in std_logic_vector(31 downto 0);
		rom_request : out std_logic;
		rom_ready : in std_logic;

		FILTER_BP_OUT : out signed(17 downto 8);
		FILTER_HP_OUT : out signed(17 downto 8);
		FILTER_F_OUT : out std_logic_vector(12 downto 0);
		FILTER_F_BP : in std_logic_vector(12 downto 0);
		FILTER_F_HP : in std_logic_vector(12 downto 0)
	);
END SID_top;		
		
ARCHITECTURE vhdl OF SID_top IS
	-- frequency (added to 24 bit osc on each tick)
	signal freq_adj_channel_a_reg : std_logic_vector(15 downto 0);
	signal freq_adj_channel_a_next : std_logic_vector(15 downto 0);
	signal freq_adj_channel_b_reg : std_logic_vector(15 downto 0);
	signal freq_adj_channel_b_next : std_logic_vector(15 downto 0);
	signal freq_adj_channel_c_reg : std_logic_vector(15 downto 0);
	signal freq_adj_channel_c_next : std_logic_vector(15 downto 0);

	-- pulse waveform duty cycle 
	signal pulse_width_channel_a_reg : std_logic_vector(11 downto 0);
	signal pulse_width_channel_a_next : std_logic_vector(11 downto 0);
	signal pulse_width_channel_b_reg : std_logic_vector(11 downto 0);
	signal pulse_width_channel_b_next : std_logic_vector(11 downto 0);
	signal pulse_width_channel_c_reg : std_logic_vector(11 downto 0);
	signal pulse_width_channel_c_next : std_logic_vector(11 downto 0);
	
	-- waveform
	signal waveselect_a_reg : std_logic_vector(3 downto 0);
	signal waveselect_a_next : std_logic_vector(3 downto 0);	
	signal waveselect_b_reg : std_logic_vector(3 downto 0);
	signal waveselect_b_next : std_logic_vector(3 downto 0);	
	signal waveselect_c_reg : std_logic_vector(3 downto 0);
	signal waveselect_c_next : std_logic_vector(3 downto 0);	

	--ring mod, sync, gate
	signal control_a_reg : std_logic_vector(3 downto 0);
	signal control_a_next : std_logic_vector(3 downto 0);	
	signal control_b_reg : std_logic_vector(3 downto 0);
	signal control_b_next : std_logic_vector(3 downto 0);	
	signal control_c_reg : std_logic_vector(3 downto 0);
	signal control_c_next : std_logic_vector(3 downto 0);	

	-- ADSR envelope - attack/decay/sustain/release
	signal envelope_attack_a_reg : std_logic_vector(3 downto 0);
	signal envelope_attack_a_next : std_logic_vector(3 downto 0);	
	signal envelope_attack_b_reg : std_logic_vector(3 downto 0);
	signal envelope_attack_b_next : std_logic_vector(3 downto 0);	
	signal envelope_attack_c_reg : std_logic_vector(3 downto 0);
	signal envelope_attack_c_next : std_logic_vector(3 downto 0);	

	signal envelope_decay_a_reg : std_logic_vector(3 downto 0);
	signal envelope_decay_a_next : std_logic_vector(3 downto 0);	
	signal envelope_decay_b_reg : std_logic_vector(3 downto 0);
	signal envelope_decay_b_next : std_logic_vector(3 downto 0);	
	signal envelope_decay_c_reg : std_logic_vector(3 downto 0);
	signal envelope_decay_c_next : std_logic_vector(3 downto 0);	

	signal envelope_sustain_a_reg : std_logic_vector(3 downto 0);
	signal envelope_sustain_a_next : std_logic_vector(3 downto 0);	
	signal envelope_sustain_b_reg : std_logic_vector(3 downto 0);
	signal envelope_sustain_b_next : std_logic_vector(3 downto 0);	
	signal envelope_sustain_c_reg : std_logic_vector(3 downto 0);
	signal envelope_sustain_c_next : std_logic_vector(3 downto 0);	

	signal envelope_release_a_reg : std_logic_vector(3 downto 0);
	signal envelope_release_a_next : std_logic_vector(3 downto 0);	
	signal envelope_release_b_reg : std_logic_vector(3 downto 0);
	signal envelope_release_b_next : std_logic_vector(3 downto 0);	
	signal envelope_release_c_reg : std_logic_vector(3 downto 0);
	signal envelope_release_c_next : std_logic_vector(3 downto 0);	
	
	-- state variable filter params
	signal statevariable_fcutoff_reg : std_logic_vector(10 downto 0); --30Hz to 12KHz, linear (or rather not, read from rom...)
	signal statevariable_fcutoff_next : std_logic_vector(10 downto 0);
	signal statevariable_F_reg : std_logic_vector(12 downto 0);  -- F computed from fcutoff -> or read from ram : 0.21 fixed point
	signal statevariable_F_next : std_logic_vector(12 downto 0); -- see example computation at start of filter.vhdl
	signal statevariable_f_changed : std_logic;
	signal statevariable_f_dirty_next : std_logic;
	signal statevariable_f_dirty_reg : std_logic;
	signal rom_state_reg : std_logic_vector(2 downto 0);
	signal rom_state_next : std_logic_vector(2 downto 0);
	constant rom_state_init : std_logic_vector(2 downto 0) := "000";
	constant rom_state_romrequest_statevariable_f : std_logic_vector(2 downto 0) := "001";
	constant rom_state_romrequest_wave_a : std_logic_vector(2 downto 0) := "010";
	constant rom_state_romrequest_wave_b : std_logic_vector(2 downto 0) := "011";
	constant rom_state_romrequest_wave_c : std_logic_vector(2 downto 0) := "100";
	constant rom_state_romrequest_statevariable_q : std_logic_vector(2 downto 0) := "101";
	signal statevariable_q_changed : std_logic;
	signal statevariable_q_dirty_next : std_logic;
	signal statevariable_q_dirty_reg : std_logic;
	signal statevariable_Q_reg : std_logic_vector(3 downto 0); --resonance
	signal statevariable_Q_next : std_logic_vector(3 downto 0);
	signal statevariable_1q_reg : signed(17 downto 0); --resonance
	signal statevariable_1q_next : signed(17 downto 0);

	signal rom_addr_mux : std_logic_vector(2 downto 0);
	signal rom_data_word : std_logic_vector(15 downto 0);

	signal rom_osc : std_logic_vector(10 downto 0);
	signal rom_high_word : std_logic;
	signal rom_wave_3bit : std_logic_vector(2 downto 0);
	signal rom_wave_2bit : std_logic_vector(1 downto 0);

	signal wavegen_data_needed : std_logic_vector(2 downto 0);
	signal wavegen_data_ready : std_logic_vector(2 downto 0);

	-- which channels are filtered?
	signal filter_en_reg : std_logic_vector(3 downto 0);
	signal filter_en_next : std_logic_vector(3 downto 0);

	-- which filters are we using?
	signal filter_sel_reg : std_logic_vector(2 downto 0); --hp/bp/lp
	signal filter_sel_next : std_logic_vector(2 downto 0);

	-- allow ch3 to be silent (direct audio path), if using it for modulation
	signal ch3silent_reg : std_logic;
	signal ch3silent_next : std_logic;

	-- overall volume
	signal vol_reg : std_logic_vector(3 downto 0);
	signal vol_next : std_logic_vector(3 downto 0);

	-- op regs
	signal addr_decoded : std_logic_vector(31 downto 0);
	
	signal audio_reg: signed(15 downto 0);

	-- osc regs
	signal osc_a_reg : std_logic_vector(11 downto 0);
	signal osc_b_reg : std_logic_vector(11 downto 0);
	signal osc_c_reg : std_logic_vector(11 downto 0);
	signal osc_a_lfsr_enable : std_logic;
	signal osc_b_lfsr_enable : std_logic;
	signal osc_c_lfsr_enable : std_logic;
	signal sync_a : std_logic;
	signal sync_b : std_logic;
	signal sync_c : std_logic;
	signal osc_a_sync_out : std_logic;
	signal osc_b_sync_out : std_logic;
	signal osc_c_sync_out : std_logic;
	signal osc_a_changing : std_logic;
	signal osc_b_changing : std_logic;
	signal osc_c_changing : std_logic;

	-- wavegen regs
	signal wave_a_reg : std_logic_vector(11 downto 0);
	signal wave_b_reg : std_logic_vector(11 downto 0);
	signal wave_c_reg : std_logic_vector(11 downto 0);

	-- envelope regs
	signal envelope_a_reg : std_logic_vector(7 downto 0);
	signal envelope_b_reg : std_logic_vector(7 downto 0);
	signal envelope_c_reg : std_logic_vector(7 downto 0);
	signal delay_lfsr_a : std_logic_vector(14 downto 0);
	signal delay_lfsr_b : std_logic_vector(14 downto 0);
	signal delay_lfsr_c : std_logic_vector(14 downto 0);
	signal tapkey_a : std_logic_vector(3 downto 0);
	signal tapkey_b : std_logic_vector(3 downto 0);
	signal tapkey_c : std_logic_vector(3 downto 0);
	signal tapmatches : std_logic_vector(2 downto 0);

	-- amplitude modulator
	signal channel_mux_modulated : signed(15 downto 0);
	signal channel_mux_sel : std_logic_vector(2 downto 0);
	signal channel_d : signed(15 downto 0);

	-- prefilter
	signal channel_prefilter : signed(15 downto 0);
	signal channel_directsum : signed(15 downto 0);

	-- filter
	signal filter_lp : signed(17 downto 0); -- extra bit due to Jammer causing filter to clip
	signal filter_bp : signed(17 downto 0);
	signal filter_hp : signed(17 downto 0);

	-- paddles
	signal potx_reg : std_logic_vector(7 downto 0);
	signal potx_next : std_logic_vector(7 downto 0);
	signal poty_reg : std_logic_vector(7 downto 0);
	signal poty_next : std_logic_vector(7 downto 0);
	signal potcount_reg : std_logic_vector(8 downto 0);
	signal potcount_next : std_logic_vector(8 downto 0);
	signal potread_x_reg : std_logic;
	signal potread_y_reg : std_logic;
	signal potread_x_next : std_logic;
	signal potread_y_next : std_logic;

	-- do internal bus
	signal do_out_next : std_logic_vector(7 downto 0);
	signal do_out_reg : std_logic_vector(7 downto 0);
	signal reset_readcount : std_logic;
	signal readcount_reg : unsigned(15 downto 0);
	signal readcount_next : unsigned(15 downto 0);
BEGIN
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			freq_adj_channel_a_reg <= (others=>'0');
			freq_adj_channel_b_reg <= (others=>'0');
			freq_adj_channel_c_reg <= (others=>'0');
			pulse_width_channel_a_reg <= (others=>'0');
			pulse_width_channel_b_reg <= (others=>'0');
			pulse_width_channel_c_reg <= (others=>'0');
			waveselect_a_reg <= (others=>'0');
			waveselect_b_reg <= (others=>'0');
			waveselect_c_reg <= (others=>'0');
			control_a_reg <= (others=>'0');
			control_b_reg <= (others=>'0');
			control_c_reg <= (others=>'0');
			envelope_attack_a_reg <= (others=>'0');
			envelope_attack_b_reg <= (others=>'0');
			envelope_attack_c_reg <= (others=>'0');
			envelope_decay_a_reg <= (others=>'0');
			envelope_decay_b_reg <= (others=>'0');
			envelope_decay_c_reg <= (others=>'0');
			envelope_sustain_a_reg <= (others=>'0');
			envelope_sustain_b_reg <= (others=>'0');
			envelope_sustain_c_reg <= (others=>'0');
			envelope_release_a_reg <= (others=>'0');
			envelope_release_b_reg <= (others=>'0');
			envelope_release_c_reg <= (others=>'0');
			statevariable_fcutoff_reg <= (others=>'0');
			statevariable_F_reg <= (others=>'0');
			statevariable_Q_reg <= (others=>'0');
			statevariable_1q_reg <= (others=>'0');
			rom_state_reg <= rom_state_init;
			filter_en_reg <= (others=>'0');
			filter_sel_reg <= (others=>'0');
			ch3silent_reg <= '0';
			vol_reg <= (others=>'0');
			statevariable_f_dirty_reg <= '1';
			statevariable_q_dirty_reg <= '1';
			potx_reg <= (others=>'0');
			poty_reg <= (others=>'0');
			potread_x_reg <= '0';
			potread_y_reg <= '0';
			potcount_reg <= (others=>'0');
			do_out_reg <= (others=>'0');
			readcount_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			freq_adj_channel_a_reg <= freq_adj_channel_a_next;
			freq_adj_channel_b_reg <= freq_adj_channel_b_next;
			freq_adj_channel_c_reg <= freq_adj_channel_c_next;
			pulse_width_channel_a_reg <= pulse_width_channel_a_next;
			pulse_width_channel_b_reg <= pulse_width_channel_b_next;
			pulse_width_channel_c_reg <= pulse_width_channel_c_next;
			waveselect_a_reg <= waveselect_a_next;
			waveselect_b_reg <= waveselect_b_next;
			waveselect_c_reg <= waveselect_c_next;
			control_a_reg <= control_a_next;
			control_b_reg <= control_b_next;
			control_c_reg <= control_c_next;
			envelope_attack_a_reg <= envelope_attack_a_next;
			envelope_attack_b_reg <= envelope_attack_b_next;
			envelope_attack_c_reg <= envelope_attack_c_next;
			envelope_decay_a_reg <= envelope_decay_a_next;
			envelope_decay_b_reg <= envelope_decay_b_next;
			envelope_decay_c_reg <= envelope_decay_c_next;
			envelope_sustain_a_reg <= envelope_sustain_a_next;
			envelope_sustain_b_reg <= envelope_sustain_b_next;
			envelope_sustain_c_reg <= envelope_sustain_c_next;
			envelope_release_a_reg <= envelope_release_a_next;
			envelope_release_b_reg <= envelope_release_b_next;
			envelope_release_c_reg <= envelope_release_c_next;
			statevariable_fcutoff_reg <= statevariable_fcutoff_next;
			statevariable_F_reg <= statevariable_F_next;
			statevariable_Q_Reg <= statevariable_Q_next;
			statevariable_1q_reg <= statevariable_1q_next;
			rom_state_reg <= rom_state_next;
			filter_en_reg <= filter_en_next;
			filter_sel_reg <= filter_sel_next;
			ch3silent_reg <= ch3silent_next;
			vol_reg <= vol_next;
			statevariable_f_dirty_reg <= statevariable_f_dirty_next;
			statevariable_q_dirty_reg <= statevariable_q_dirty_next;
			potx_reg <= potx_next;
			poty_reg <= poty_next;
			potread_x_reg <= potread_x_next;
			potread_y_reg <= potread_y_next;
			potcount_reg <= potcount_next;
			do_out_reg <= do_out_next;
			readcount_reg <= readcount_next;
		end if;
	end process;
	
decode_addr1 : entity work.complete_address_decoder
	generic map(width=>5)
	port map (addr_in=>ADDR(4 downto 0), addr_decoded=>addr_decoded);	
	
	process(addr_decoded,write_enable,di,
		freq_adj_channel_a_reg,
		freq_adj_channel_b_reg,
		freq_adj_channel_c_reg,
		pulse_width_channel_a_reg,
		pulse_width_channel_b_reg,
		pulse_width_channel_c_reg,
		waveselect_a_reg,
		waveselect_b_reg,
		waveselect_c_reg,
		control_a_reg,
		control_b_reg,
		control_c_reg,
		envelope_attack_a_reg,
		envelope_attack_b_reg,
		envelope_attack_c_reg,
		envelope_decay_a_reg,
		envelope_decay_b_reg,
		envelope_decay_c_reg,
		envelope_sustain_a_reg,
		envelope_sustain_b_reg,
		envelope_sustain_c_reg,
		envelope_release_a_reg,
		envelope_release_b_reg,
		envelope_release_c_reg,
		statevariable_fcutoff_reg,
		statevariable_Q_Reg,
		filter_en_reg,
		filter_sel_reg,
		ch3silent_reg,
		vol_reg
		)
	begin
		freq_adj_channel_a_next <= freq_adj_channel_a_reg;
		freq_adj_channel_b_next <= freq_adj_channel_b_reg;
		freq_adj_channel_c_next <= freq_adj_channel_c_reg;
		pulse_width_channel_a_next <= pulse_width_channel_a_reg;
		pulse_width_channel_b_next <= pulse_width_channel_b_reg;
		pulse_width_channel_c_next <= pulse_width_channel_c_reg;
		waveselect_a_next <= waveselect_a_reg;
		waveselect_b_next <= waveselect_b_reg;
		waveselect_c_next <= waveselect_c_reg;
		control_a_next <= control_a_reg;
		control_b_next <= control_b_reg;
		control_c_next <= control_c_reg;
		envelope_attack_a_next <= envelope_attack_a_reg;
		envelope_attack_b_next <= envelope_attack_b_reg;
		envelope_attack_c_next <= envelope_attack_c_reg;
		envelope_decay_a_next <= envelope_decay_a_reg;
		envelope_decay_b_next <= envelope_decay_b_reg;
		envelope_decay_c_next <= envelope_decay_c_reg;
		envelope_sustain_a_next <= envelope_sustain_a_reg;
		envelope_sustain_b_next <= envelope_sustain_b_reg;
		envelope_sustain_c_next <= envelope_sustain_c_reg;
		envelope_release_a_next <= envelope_release_a_reg;
		envelope_release_b_next <= envelope_release_b_reg;
		envelope_release_c_next <= envelope_release_c_reg;
		statevariable_fcutoff_next <= statevariable_fcutoff_reg;
		statevariable_Q_next <= statevariable_Q_reg;
		filter_en_next <= filter_en_reg;
		filter_sel_next <= filter_sel_reg;
		ch3silent_next <= ch3silent_reg;
		vol_next <= vol_reg;

		statevariable_f_changed <= '0';
		statevariable_q_changed <= '0';
	
		if (write_enable='1') then
			--ch a
			if (addr_decoded(0)='1') then
				freq_adj_channel_a_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(1)='1') then
				freq_adj_channel_a_next(15 downto 8) <= di;
			end if;
			if (addr_decoded(2)='1') then
				pulse_width_channel_a_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(3)='1') then
				pulse_width_channel_a_next(11 downto 8) <= di(3 downto 0);
			end if;
			if (addr_decoded(4)='1') then
				control_a_next <= di(3 downto 0);
				waveselect_a_next <= di(7 downto 4);
			end if;
			if (addr_decoded(5)='1') then
				envelope_attack_a_next <= di(7 downto 4);
				envelope_decay_a_next <= di(3 downto 0);
			end if;
			if (addr_decoded(6)='1') then
				envelope_sustain_a_next <= di(7 downto 4);
				envelope_release_a_next <= di(3 downto 0);
			end if;

			--ch b
			if (addr_decoded(7)='1') then
				freq_adj_channel_b_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(8)='1') then
				freq_adj_channel_b_next(15 downto 8) <= di;
			end if;
			if (addr_decoded(9)='1') then
				pulse_width_channel_b_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(10)='1') then
				pulse_width_channel_b_next(11 downto 8) <= di(3 downto 0);
			end if;
			if (addr_decoded(11)='1') then
				control_b_next <= di(3 downto 0);
				waveselect_b_next <= di(7 downto 4);
			end if;
			if (addr_decoded(12)='1') then
				envelope_attack_b_next <= di(7 downto 4);
				envelope_decay_b_next <= di(3 downto 0);
			end if;
			if (addr_decoded(13)='1') then
				envelope_sustain_b_next <= di(7 downto 4);
				envelope_release_b_next <= di(3 downto 0);
			end if;

			--ch c
			if (addr_decoded(14)='1') then
				freq_adj_channel_c_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(15)='1') then
				freq_adj_channel_c_next(15 downto 8) <= di;
			end if;
			if (addr_decoded(16)='1') then
				pulse_width_channel_c_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(17)='1') then
				pulse_width_channel_c_next(11 downto 8) <= di(3 downto 0);
			end if;
			if (addr_decoded(18)='1') then
				control_c_next <= di(3 downto 0);
				waveselect_c_next <= di(7 downto 4);
			end if;
			if (addr_decoded(19)='1') then
				envelope_attack_c_next <= di(7 downto 4);
				envelope_decay_c_next <= di(3 downto 0);
			end if;
			if (addr_decoded(20)='1') then
				envelope_sustain_c_next <= di(7 downto 4);
				envelope_release_c_next <= di(3 downto 0);
			end if;

			--filter
			if (addr_decoded(21)='1') then
				statevariable_fcutoff_next(2 downto 0) <= di(2 downto 0);
				statevariable_f_changed <= '1';
			end if;
			if (addr_decoded(22)='1') then
				statevariable_fcutoff_next(10 downto 3) <= di;
				statevariable_f_changed <= '1';
			end if;
			if (addr_decoded(23)='1') then
				statevariable_Q_next <= di(7 downto 4);
				statevariable_q_changed <= '1';
				filter_en_next <= di(3 downto 0);
			end if;
			if (addr_decoded(24)='1') then
				ch3silent_next <= di(7);
				filter_sel_next <= di(6 downto 4);
				vol_next <= di(3 downto 0);
			end if;
		end if;
	end process;
	
	process(addr,addr_decoded,
		do_out_reg,do_out_next,
		read_enable,
		wave_c_reg,
		envelope_c_reg,
		potx_reg,
		poty_reg,
		readcount_reg
		)
	begin
		drive_do <= '1'; 
		--ADDR(4) and ADDR(3) and or_reduce(ADDR(2 downto 0));
		do_out_next <= do_out_reg;

		reset_readcount <= '0';

		if (read_enable='1') then
			if (addr_decoded(25)='1') then
				do_out_next <= potx_reg;
				reset_readcount <= '1';
			end if;
			if (addr_decoded(26)='1') then
				do_out_next <= poty_reg;
				reset_readcount <= '1';
			end if;
			if (addr_decoded(27)='1') then
				do_out_next <= wave_c_reg(11 downto 4);
				reset_readcount <= '1';
			end if;
			if (addr_decoded(28)='1') then
				do_out_next <= envelope_c_reg;
				reset_readcount <= '1';
			end if;
		else
			if (or_reduce(std_logic_vector(readcount_reg))='0') then
				do_out_next <= (others=>'0');
			end if;
		end if;
		do <= do_out_next;
	end process;	

	process(readcount_reg,enable,reset_readcount,sidtype)
	begin
		readcount_next <= readcount_reg;

		if (reset_readcount='1') then
			if (sidtype ='1') then --6581
				readcount_next <=to_unsigned(8000,16);
			else
				readcount_next <=to_unsigned(65535,16);
			end if;
		else
			if (enable='1') then
				readcount_next <=readcount_reg-1;
			end if;
		end if;
	end process;

	-- osc a
	osc_a : entity work.SID_oscillator
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => enable,
		
		TEST => control_a_reg(3),
		LFSR_ENABLE => osc_a_lfsr_enable,
		CHANGING => osc_a_changing,
		BITS_OUT => osc_a_reg,

		SYNC_IN => sync_a,
		SYNC_OUT => osc_a_sync_out,
		
		ADJ => freq_adj_channel_a_reg
	);
	sync_a <= control_a_reg(1) and osc_c_sync_out;

	-- osc b
	osc_b : entity work.SID_oscillator
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => enable,
		
		TEST => control_b_reg(3),
		LFSR_ENABLE => osc_b_lfsr_enable,
		CHANGING => osc_b_changing,
		BITS_OUT => osc_b_reg,

		SYNC_IN => sync_b,
		SYNC_OUT => osc_b_sync_out,
		
		ADJ => freq_adj_channel_b_reg
	);
	sync_b <= control_b_reg(1) and osc_a_sync_out;

	-- osc c
	osc_c : entity work.SID_oscillator
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => enable,
		
		TEST => control_c_reg(3),
		LFSR_ENABLE => osc_c_lfsr_enable,
		CHANGING => osc_c_changing,
		BITS_OUT => osc_c_reg,

		SYNC_IN => sync_c,
		SYNC_OUT => osc_c_sync_out,
		
		ADJ => freq_adj_channel_c_reg
	);
	sync_c <= control_c_reg(1) and osc_b_sync_out;

	--wave generator
	wavegen_a : entity work.SID_wavegen
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => enable,

		CHANGING => osc_a_changing,

		DELAYSAWTOOTH => not(sidtype),
		RINGMOD => control_a_reg(2),
		RINGMOD_OSC_MSB => osc_c_reg(11),
		TEST => control_a_next(3),
		LFSR_ENABLE => (osc_a_lfsr_enable or (control_a_reg(3) xor control_a_next(3)) or (control_a_reg(3) and enable)),
		OSC_IN => osc_a_reg,
		PULSE_WIDTH_IN => pulse_width_channel_a_reg,

		WAVESELECT_IN => waveselect_a_reg,

		WAVE_DATA_NEEDED => wavegen_data_needed(0),
		WAVE_DATA_READY => wavegen_data_ready(0),
		WAVE_DATA => rom_data_word(11 downto 0),

		WAVE_OUT => wave_a_reg
	);
	wavegen_b : entity work.SID_wavegen
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => enable,

		CHANGING => osc_b_changing,

		DELAYSAWTOOTH => not(sidtype),
		RINGMOD => control_b_reg(2),
		RINGMOD_OSC_MSB => osc_a_reg(11),
		TEST => control_b_next(3),
		LFSR_ENABLE => (osc_b_lfsr_enable or (control_b_reg(3) xor control_b_next(3)) or (control_b_reg(3) and enable)),
		OSC_IN => osc_b_reg,
		PULSE_WIDTH_IN => pulse_width_channel_b_reg,

		WAVESELECT_IN => waveselect_b_reg,

		WAVE_DATA_NEEDED => wavegen_data_needed(1),
		WAVE_DATA_READY => wavegen_data_ready(1),
		WAVE_DATA => rom_data_word(11 downto 0),

		WAVE_OUT => wave_b_reg
	);
	wavegen_c : entity work.SID_wavegen
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => enable,

		CHANGING => osc_c_changing,

		DELAYSAWTOOTH => not(sidtype),
		RINGMOD => control_c_reg(2),
		RINGMOD_OSC_MSB => osc_b_reg(11),
		TEST => control_c_next(3),
		LFSR_ENABLE => (osc_c_lfsr_enable or (control_c_reg(3) xor control_c_next(3)) or (control_c_reg(3) and enable)),
		OSC_IN => osc_c_reg,
		PULSE_WIDTH_IN => pulse_width_channel_c_reg,

		WAVESELECT_IN => waveselect_c_reg,

		WAVE_DATA_NEEDED => wavegen_data_needed(2),
		WAVE_DATA_READY => wavegen_data_ready(2),
		WAVE_DATA => rom_data_word(11 downto 0),

		WAVE_OUT => wave_c_reg
	);

	-- envelope
	envelope_a : entity work.SID_envelope
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,

		TAPMATCH => tapmatches(0),

		ATTACK => envelope_attack_a_reg,
		SUSTAIN => envelope_sustain_a_reg,
		DECAY => envelope_decay_a_reg,
		RELEASE_IN => envelope_release_a_reg,

		GATE => control_a_reg(0),
		
		ENVELOPE => envelope_a_reg,
		DELAY_LFSR => delay_lfsr_a,
		TAPKEY => tapkey_a
	);		

	envelope_b : entity work.SID_envelope
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,

		TAPMATCH => tapmatches(1),

		ATTACK => envelope_attack_b_reg,
		SUSTAIN => envelope_sustain_b_reg,
		DECAY => envelope_decay_b_reg,
		RELEASE_IN => envelope_release_b_reg,

		GATE => control_b_reg(0),
		
		ENVELOPE => envelope_b_reg,
		DELAY_LFSR => delay_lfsr_b,
		TAPKEY => tapkey_b
	);		

	envelope_c : entity work.SID_envelope
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,

		TAPMATCH => tapmatches(2),

		ATTACK => envelope_attack_c_reg,
		SUSTAIN => envelope_sustain_c_reg,
		DECAY => envelope_decay_c_reg,
		RELEASE_IN => envelope_release_c_reg,

		GATE => control_c_reg(0),
		
		ENVELOPE => envelope_c_reg,
		DELAY_LFSR => delay_lfsr_c,
		TAPKEY => tapkey_c
	);		

	envelope_tapmatcher : entity work.SID_envelope_tapmatch
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		

		DELAY_LFSR1 => delay_lfsr_a,
		DELAY_LFSR2 => delay_lfsr_b,
		DELAY_LFSR3 => delay_lfsr_c,

		TAPKEY1 => tapkey_a,
		TAPKEY2 => tapkey_b,
		TAPKEY3 => tapkey_c,

		TAPMATCHES => tapmatches
	);		

	-- volume
	vol_abc : entity work.SID_amplitudeModulator
	PORT MAP
	( 
		WAVE_A => wave_a_reg,
		ENVELOPE_A => envelope_a_reg,
		WAVE_B => wave_b_reg,
		ENVELOPE_B => envelope_b_reg,
		WAVE_C => wave_c_reg,
		ENVELOPE_C => envelope_c_reg,
		CHANNEL_D => channel_d,

		CHANNEL_MUX_SEL => channel_mux_sel,
		
		MODULATED => channel_mux_modulated
	);		

	prefilter: entity work.SID_preFilterSum
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,

		BIAS_CHANNEL => sidtype,

		CHANNEL_MUX => channel_mux_modulated,
		CHANNEL_C_CUTDIRECT => ch3silent_reg,
		FILTER_EN => filter_en_reg,

		CHANNEL_MUX_SEL => channel_mux_sel,
		PREFILTER_OUT => channel_prefilter,
		DIRECT_OUT => channel_directsum
	);

	process(statevariable_F_reg, statevariable_1q_reg,
		rom_state_reg, 
		statevariable_f_changed, statevariable_f_dirty_reg,
		statevariable_q_changed, statevariable_q_dirty_reg,
		rom_data, rom_data_word, rom_high_word, rom_ready,
		wavegen_data_needed)
	begin
		statevariable_f_dirty_next <= statevariable_f_dirty_reg or statevariable_f_changed;
		statevariable_F_next <= statevariable_F_reg;
		statevariable_q_dirty_next <= statevariable_q_dirty_reg or statevariable_q_changed;
		statevariable_1q_next <= statevariable_1q_reg;
		rom_state_next <= rom_state_reg;
		rom_request <= '0';

		rom_addr_mux <= "000";
		wavegen_data_ready <= (others=>'0');

		if (rom_high_word='0') then
			rom_data_word <= rom_data(15 downto 0);
		else
			rom_data_word <= rom_data(31 downto 16);
		end if;

		case rom_state_reg is
			when rom_state_init =>
				if (statevariable_f_dirty_reg='1') then
					rom_state_next <= rom_state_romrequest_statevariable_f;
				end if;
				if (statevariable_q_dirty_reg='1') then
					rom_state_next <= rom_state_romrequest_statevariable_q;
				end if;
				if (wavegen_data_needed(0)='1') then
					rom_state_next <= rom_state_romrequest_wave_a;
				end if;
				if (wavegen_data_needed(1)='1') then
					rom_state_next <= rom_state_romrequest_wave_b;
				end if;
				if (wavegen_data_needed(2)='1') then
					rom_state_next <= rom_state_romrequest_wave_c;
				end if;
			when rom_state_romrequest_statevariable_f =>
				rom_request <= '1';
				rom_addr_mux <= "000";
				if (rom_ready = '1') then
					statevariable_f_dirty_next <= '0';
					statevariable_F_next <= rom_data_word(12 downto 0);
					rom_state_next <= rom_state_init;
				end if;
			when rom_state_romrequest_wave_a =>
				rom_request <= '1';
				rom_addr_mux <= "001";
				wavegen_data_ready(0) <= rom_ready;
				if (rom_ready = '1') then
					rom_state_next <= rom_state_init;
				end if;
			when rom_state_romrequest_wave_b =>
				rom_request <= '1';
				rom_addr_mux <= "010";
				wavegen_data_ready(1) <= rom_ready;
				if (rom_ready = '1') then
					rom_state_next <= rom_state_init;
				end if;
			when rom_state_romrequest_wave_c =>
				rom_request <= '1';
				rom_addr_mux <= "011";
				wavegen_data_ready(2) <= rom_ready;
				if (rom_ready = '1') then
					rom_state_next <= rom_state_init;
				end if;
			when rom_state_romrequest_statevariable_q =>
				rom_request <= '1';
				rom_addr_mux <= "100";
				if (rom_ready = '1') then
					statevariable_q_dirty_next <= '0';
					statevariable_1q_next <= signed(rom_data(17 downto 0));
					rom_state_next <= rom_state_init;
				end if;
			when others =>
				rom_state_next <= rom_state_init;
		end case;
	end process;

	process(rom_addr_mux,
		sidtype,
		statevariable_fcutoff_reg,
		statevariable_q_reg,
		osc_a_reg,osc_b_reg,osc_c_reg,
		waveselect_a_reg,waveselect_b_reg,waveselect_c_reg,
		rom_wave_2bit,rom_wave_3bit,
		rom_osc,rom_high_word)

	variable rom_wave_addr: std_logic_vector(16 downto 0);
	variable sidtype2: std_logic_vector(0 downto 0);
	begin
		rom_addr <= (others=>'0');
		rom_high_word <= '0';
		rom_wave_2bit <= (others=>'0');
		rom_wave_3bit <= (others=>'0');
		rom_osc <= (others=>'0');

		sidtype2(0) := sidtype;

		case rom_wave_3bit is
		when "011" => -- ST
			rom_wave_2bit <= "00";
		when "101" => --P T
			rom_wave_2bit <= "01";
		when "110" => --PS 
			rom_wave_2bit <= "10";
		when "111" => --PST
			rom_wave_2bit <= "11";
		when others =>
		end case;

				
		rom_wave_addr := std_logic_vector(unsigned(wave_base)+resize(unsigned(sidtype2(0 downto 0)&rom_wave_2bit&rom_osc),17)); --1:2:11

		case rom_addr_mux is
		when "000" =>
			rom_addr <= "00000"&std_logic_vector(unsigned('0'&sidtype2(0 downto 0))+1)&statevariable_fcutoff_reg(10 downto 1);
			rom_high_word <= statevariable_fcutoff_reg(0);
		when "001" =>
			rom_osc <= osc_a_reg(11 downto 1);
			rom_wave_3bit <= waveselect_a_reg(2 downto 0);
			rom_addr <= rom_wave_addr;
			rom_high_word <= osc_a_reg(0);
		when "010" =>
			rom_osc <= osc_b_reg(11 downto 1);
			rom_wave_3bit <= waveselect_b_reg(2 downto 0);
			rom_addr <= rom_wave_addr;
			rom_high_word <= osc_b_reg(0);
		when "011" =>
			rom_osc <= osc_c_reg(11 downto 1);
			rom_wave_3bit <= waveselect_c_reg(2 downto 0);
			rom_addr <= rom_wave_addr;
			rom_high_word <= osc_c_reg(0);
		when "100" =>
			rom_addr <= "000000010000"&sidtype2(0 downto 0)&statevariable_q_reg;
		when others =>
		end case;

	end process;

	variable_state_filter : entity work.SID_filter
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,

		INPUT => channel_prefilter,

		SIDTYPE => sidtype,

		LOWPASS => filter_lp,
		BANDPASS => filter_bp,
		HIGHPASS => filter_hp,

		--CUTOFF_FREQUENCY => statevariable_fcutoff_reg,
		F_BP => unsigned(filter_f_bp),
		F_HP => unsigned(filter_f_hp),
		Q => statevariable_1q_reg
	);

	postfilter: entity work.SID_postFilterSum
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,		

		DIRECT => channel_directsum,

		FILTER_LP => filter_lp,
		FILTER_BP => filter_bp,
		FILTER_HP => filter_hp,
		FILTER_SEL => filter_sel_reg,

		VOLUME => vol_reg,

		CHANNEL_OUT => audio_reg
	);

	-- paddles
	process (potx_reg,poty_reg,pot_x,pot_y,potcount_reg,enable,potread_x_reg,potread_y_reg)
	begin
		potx_next <= potx_reg;
		poty_next <= poty_reg;
		potread_x_next <= potread_x_reg and not(potcount_reg(8));
		potread_y_next <= potread_y_reg and not(potcount_reg(8));
		potcount_next <= potcount_reg;

		pot_reset <= potcount_reg(8);
		if (enable='1') then
			potcount_next <= std_logic_vector(unsigned(potcount_reg)+1);
			if ((pot_x='1' or potcount_reg="011111111") and potread_x_reg='0') then
				potx_next <= potcount_reg(7 downto 0);
				potread_x_next <= '1';
			end if;
			if ((pot_y='1' or potcount_reg="011111111") and potread_y_reg='0') then
				poty_next <= potcount_reg(7 downto 0);
				potread_y_next <= '1';
			end if;
		end if;

	end process;

	-- ext audio
	process(ext_adc,ext)
	begin
		--EXT : in std_logic_vector(1 downto 0); -- 00=GND,01=digifix,10=ADC
		--EXT_ADC : in unsigned(7 downto 0);
		channel_d <= to_signed(0,16);

		case EXT is 
			when "01" =>
				channel_d <= signed("000"&ext&"00000000000");
			when "10" =>
				channel_d <= signed(not(ext_adc(15))&ext_adc(14 downto 0));
			when others=>
		end case;
	end process;
	
	--------------------------------
	-- TODO
	-- 1) DONE:check above works!
	-- 2) DONE: wave combinations need to read flash
	-- 3) DONE:envelope/gate
	-- 4) DONE:amplitude modulation
	-- 5) DONE:filter on/off
	-- 5) DONE:filter (state variable as per info found)
	-- 6) DONE:volume
	-- 7) DONE: read registers: pot, osc3 etc
	-- 8) 6581! buggy_variable_state_filter : entity work.SID_filter
	-- ref: https://bel.fi/alankila/c64-sw/index-cpp.html
	-- see distortion section
	--------------------------------
	
	--outputs
	AUDIO <= audio_reg;

	DEBUG_EV1 <= unsigned(envelope_a_reg);
	DEBUG_WV1 <= unsigned(wave_a_reg);
	DEBUG_AM1 <= channel_mux_modulated;

	FILTER_BP_OUT <= filter_bp(17 downto 8);
	FILTER_HP_OUT <= filter_hp(17 downto 8);
	FILTER_F_OUT <= statevariable_F_reg;

end vhdl;

