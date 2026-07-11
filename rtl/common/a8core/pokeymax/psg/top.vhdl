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

-- audio only, no need for io part
ENTITY PSG_top IS 
	PORT
	(
		CLK : in std_logic;
		RESET_N : in std_logic;
		
		ENABLE : in std_logic;

		ENVELOPE32 : in std_logic := '1'; -- 0=16 step,1=32 step
		
		ADDR : in std_logic_vector(3 downto 0); --TODO: Handy to address this way, but could use the original crappy way if people prefer!
		WRITE_ENABLE : in std_logic;
		
		DI : in std_logic_vector(7 downto 0);
		DO : out std_logic_vector(7 downto 0);
		
		IOA_IN : in std_logic_vector(7 downto 0) := (others=>'0');
		IOB_IN : in std_logic_vector(7 downto 0) := (others=>'0');
		IOA_OUT : out std_logic_vector(7 downto 0);
		IOB_OUT : out std_logic_vector(7 downto 0);		
		IOA_OE : out std_logic;
		IOB_OE : out std_logic;
		
		channel_a_vol : out std_logic_vector(4 downto 0);
		channel_b_vol : out std_logic_vector(4 downto 0);
		channel_c_vol : out std_logic_vector(4 downto 0);

		channel_changed : out std_logic
	);
END PSG_top;		
		
ARCHITECTURE vhdl OF PSG_top IS
	signal period_channel_a_reg : std_logic_vector(11 downto 0);
	signal period_channel_a_next : std_logic_vector(11 downto 0);
	signal period_channel_b_reg : std_logic_vector(11 downto 0);
	signal period_channel_b_next : std_logic_vector(11 downto 0);
	signal period_channel_c_reg : std_logic_vector(11 downto 0);
	signal period_channel_c_next : std_logic_vector(11 downto 0);
	
	signal period_noise_reg : std_logic_vector(4 downto 0);
	signal period_noise_next : std_logic_vector(4 downto 0);	
	
	signal vol_channel_a_reg : std_logic_vector(4 downto 0);
	signal vol_channel_a_next : std_logic_vector(4 downto 0);
	signal vol_channel_b_reg : std_logic_vector(4 downto 0);
	signal vol_channel_b_next : std_logic_vector(4 downto 0);
	signal vol_channel_c_reg : std_logic_vector(4 downto 0);
	signal vol_channel_c_next : std_logic_vector(4 downto 0);	
	
	signal period_envelope_reg : std_logic_vector(15 downto 0);
	signal period_envelope_next : std_logic_vector(15 downto 0);	
	
	signal shape_envelope_reg : std_logic_vector(3 downto 0);
	signal shape_envelope_next : std_logic_vector(3 downto 0);		

	signal mixer_noise_reg : std_logic_vector(2 downto 0);
	signal mixer_noise_next : std_logic_vector(2 downto 0);		
	signal mixer_tone_reg : std_logic_vector(2 downto 0);
	signal mixer_tone_next : std_logic_vector(2 downto 0);	

	signal io_output_reg : std_logic_vector(1 downto 0);
	signal io_output_next : std_logic_vector(1 downto 0);
	
	signal ioa_reg : std_logic_vector(7 downto 0);
	signal ioa_next : std_logic_vector(7 downto 0);	
	signal iob_reg : std_logic_vector(7 downto 0);
	signal iob_next : std_logic_vector(7 downto 0);
	
	signal addr_decoded : std_logic_vector(15 downto 0);
	
	signal core_tick : std_logic;
	signal core_tick_half : std_logic;
	signal channel_a_tick : std_logic;
	signal channel_b_tick : std_logic;
	signal channel_c_tick : std_logic;
	signal noise_tick : std_logic;
	signal noise_val : std_logic;
	
	signal channel_a_val : std_logic;
	signal channel_b_val : std_logic;
	signal channel_c_val : std_logic;

	signal channel_a_changed : std_logic;
	signal channel_b_changed : std_logic;
	signal channel_c_changed : std_logic;
	
	signal envelope_reg : std_logic_vector(4 downto 0); 
	signal envelope_count_reset : std_logic;
	
BEGIN
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			period_channel_a_reg <= (others=>'0');
			period_channel_b_reg <= (others=>'0');
			period_channel_c_reg <= (others=>'0');
			period_noise_reg <= (others=>'0');
			vol_channel_a_reg <= (others=>'0');
			vol_channel_b_reg <= (others=>'0');
			vol_channel_c_reg <= (others=>'0');		
			period_envelope_reg <=	(others=>'0');
			shape_envelope_reg <= (others=>'0');
			mixer_noise_reg <= (others=>'0');
			mixer_tone_reg <= (others=>'0');
			io_output_reg <= (others=>'0');
			ioa_reg <= (others=>'0');
			iob_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			period_channel_a_reg <= period_channel_a_next;
			period_channel_b_reg <= period_channel_b_next;
			period_channel_c_reg <= period_channel_c_next;
			period_noise_reg <= period_noise_next;
			vol_channel_a_reg <= vol_channel_a_next;
			vol_channel_b_reg <= vol_channel_b_next;
			vol_channel_c_reg <= vol_channel_c_next;			
			period_envelope_reg <= period_envelope_next;
			shape_envelope_reg <= shape_envelope_next; 
			mixer_noise_reg <= mixer_noise_next;
			mixer_tone_reg <= mixer_tone_next;
			io_output_reg <= io_output_next;
			ioa_reg <= ioa_next;
			iob_reg <= iob_next;
		end if;
	end process;
	
decode_addr1 : entity work.complete_address_decoder
	generic map(width=>4)
	port map (addr_in=>ADDR(3 downto 0), addr_decoded=>addr_decoded);	
	
	process(addr_decoded,write_enable,di,
		period_channel_a_reg,period_channel_b_reg,period_channel_c_reg,
		period_noise_reg,
		vol_channel_a_reg,vol_channel_b_reg,vol_channel_c_reg,
		period_envelope_reg,
		shape_envelope_reg,
		mixer_noise_reg,
		mixer_tone_reg,
		ioa_reg,
		iob_reg,
		io_output_reg
		)
	begin
		period_channel_a_next <= period_channel_a_reg;
		period_channel_b_next <= period_channel_b_reg;
		period_channel_c_next <= period_channel_c_reg;
		period_noise_next <= period_noise_reg;
		vol_channel_a_next <= vol_channel_a_reg;
		vol_channel_b_next <= vol_channel_b_reg;
		vol_channel_c_next <= vol_channel_c_reg;		
		period_envelope_next <= period_envelope_reg;		
		shape_envelope_next <= shape_envelope_reg;
		mixer_noise_next <= mixer_noise_reg;
		mixer_tone_next <= mixer_tone_reg;
		io_output_next <= io_output_reg;
		ioa_next <= ioa_reg;
		iob_next <= iob_reg;
		envelope_count_reset <= '0';
	
		if (write_enable='1') then
			if (addr_decoded(0)='1') then
				period_channel_a_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(1)='1') then
				period_channel_a_next(11 downto 8) <= di(3 downto 0);
			end if;
			
			if (addr_decoded(2)='1') then
				period_channel_b_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(3)='1') then
				period_channel_b_next(11 downto 8) <= di(3 downto 0);
			end if;

			if (addr_decoded(4)='1') then
				period_channel_c_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(5)='1') then
				period_channel_c_next(11 downto 8) <= di(3 downto 0);
			end if;
			
			if (addr_decoded(6)='1') then
				period_noise_next <= di(4 downto 0);
			end if;
			
			if (addr_decoded(7)='1') then
				io_output_next  <= di(7 downto 6);
				mixer_noise_next <= di(5 downto 3);
				mixer_tone_next <= di(2 downto 0);
			end if;			
			
			if (addr_decoded(8)='1') then
				vol_channel_a_next <= di(4 downto 0);
			end if;
			if (addr_decoded(9)='1') then
				vol_channel_b_next <= di(4 downto 0);
			end if;
			if (addr_decoded(10)='1') then
				vol_channel_c_next <= di(4 downto 0);
			end if;			
			
			if (addr_decoded(11)='1') then
				period_envelope_next(7 downto 0) <= di;
			end if;
			if (addr_decoded(12)='1') then
				period_envelope_next(15 downto 8) <= di;
			end if;						

			if (addr_decoded(13)='1') then
				shape_envelope_next <= di(3 downto 0);
				envelope_count_reset <= '1';
			end if;			

			if (addr_decoded(14)='1') then
				ioa_next <= di;
			end if;	

			if (addr_decoded(15)='1') then
				iob_next <= di;
			end if;				
			
		end if;
	end process;
	
	process(addr_decoded,
		period_channel_a_reg,period_channel_b_reg,period_channel_c_reg,
		period_noise_reg,
		vol_channel_a_reg,vol_channel_b_reg,vol_channel_c_reg,
		period_envelope_reg,
		shape_envelope_reg,
		mixer_noise_reg,
		mixer_tone_reg,
		ioa_in,
		iob_in,
		io_output_reg		
		)
	begin
		do <= (others=>'0');
	
		if (addr_decoded(0)='1') then
			do <= period_channel_a_reg(7 downto 0);
		end if;
		if (addr_decoded(1)='1') then
			do(3 downto 0) <= period_channel_a_reg(11 downto 8);
		end if;
		
		if (addr_decoded(2)='1') then
			do <= period_channel_b_reg(7 downto 0);
		end if;
		if (addr_decoded(3)='1') then
			do(3 downto 0) <= period_channel_b_reg(11 downto 8);
		end if;

		if (addr_decoded(4)='1') then
			do <= period_channel_c_reg(7 downto 0);
		end if;
		if (addr_decoded(5)='1') then
			do(3 downto 0) <= period_channel_c_reg(11 downto 8);
		end if;
		
		if (addr_decoded(6)='1') then
			do(4 downto 0) <= period_noise_reg;
		end if;
		
		if (addr_decoded(7)='1') then
			do(7 downto 6) <= io_output_reg;
			do(5 downto 3) <= mixer_noise_reg;
			do(2 downto 0) <= mixer_tone_reg;
		end if;			
		
		if (addr_decoded(8)='1') then
			do(4 downto 0) <= vol_channel_a_reg;
		end if;
		if (addr_decoded(9)='1') then
			do(4 downto 0) <= vol_channel_b_reg;
		end if;
		if (addr_decoded(10)='1') then
			do(4 downto 0) <= vol_channel_c_reg;
		end if;			
		
		if (addr_decoded(11)='1') then
			do <= period_envelope_reg(7 downto 0);
		end if;
		if (addr_decoded(12)='1') then
			do <= period_envelope_reg(15 downto 8);
		end if;						

		if (addr_decoded(13)='1') then
			do(3 downto 0) <= shape_envelope_reg;
		end if;								
		
		if (addr_decoded(14)='1') then
			do <= ioa_in;
		end if;	

		if (addr_decoded(15)='1') then
			do <= iob_in;
		end if;				
	end process;	

	-- initial divide by 8
	core_ticker : entity work.PSG_freqdiv
	GENERIC MAP
	(
		bits => 4
	)
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => enable,
		
		BIT_OUT => core_tick,
		
		THRESHOLD => "1000"
	);	
	
	-- channels A-C, frequency divider
	channel_a_ticker : entity work.PSG_freqdiv
	GENERIC MAP
	(
		bits => 12
	)
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => core_tick,
		
		BIT_OUT => channel_a_tick,
		
		THRESHOLD => unsigned(period_channel_a_reg)
	);	
	
	channel_b_ticker : entity work.PSG_freqdiv
	GENERIC MAP
	(
		bits => 12
	)
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => core_tick,
		
		BIT_OUT => channel_b_tick,
		
		THRESHOLD => unsigned(period_channel_b_reg)
	);
	
	channel_c_ticker : entity work.PSG_freqdiv
	GENERIC MAP
	(
		bits => 12
	)
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => core_tick,
		
		BIT_OUT => channel_c_tick,
		
		THRESHOLD => unsigned(period_channel_c_reg)
	);	
	
	-- noise
	--17-bit LFSR with taps at bits 17 and 14
	--ref:https://listengine.tuxfamily.org/lists.tuxfamily.org/hatari-devel/2012/09/msg00045.html	
	
	-- noise freq->noise_tick->noise_val
	noise_preticker : entity work.PSG_freqdiv
	GENERIC MAP
	(
		bits => 2
	)	
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => core_tick,
		
		BIT_OUT => core_tick_half,
		
		THRESHOLD => "10"
	);

	noise_ticker : entity work.PSG_freqdiv
	GENERIC MAP
	(
		bits => 5
	)	
	PORT MAP
	(
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => core_tick_half,
		
		BIT_OUT => noise_tick,
		
		THRESHOLD => unsigned(period_noise_reg)
	);
	
	noise : entity work.PSG_noise
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,
		ENABLE => noise_tick,
		TICK => noise_tick,
		
		BIT_OUT => noise_val
	);

	-- mix noise and channel
	mix_a : entity work.PSG_mixer
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,
		
		NOISE => noise_val,
		CHANNEL => channel_a_tick,
		
		NOISE_OFF => mixer_noise_reg(0),
		TONE_OFF => mixer_tone_reg(0),
		
		BIT_OUT => channel_a_val
	);
	
	mix_b : entity work.PSG_mixer
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,
		
		NOISE => noise_val,
		CHANNEL => channel_b_tick,
		
		NOISE_OFF => mixer_noise_reg(1),
		TONE_OFF => mixer_tone_reg(1),		
		
		BIT_OUT => channel_b_val
	);	
	
	mix_c : entity work.PSG_mixer
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,
		
		NOISE => noise_val,
		CHANNEL => channel_c_tick,
		
		NOISE_OFF => mixer_noise_reg(2),
		TONE_OFF => mixer_tone_reg(2),		
		
		BIT_OUT => channel_c_val
	);		

	-- envelope
	envelope : entity work.PSG_envelope
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => core_tick,
		
		STEP32 => envelope32,
		COUNT_RESET => envelope_count_reset,
		SHAPE => shape_envelope_reg,
		PERIOD => period_envelope_reg,

		ENVELOPE => envelope_reg
	);		
	
	-- volume
	vol_a : entity work.PSG_volume
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,
		
		CHANNEL => channel_a_val,
		FIXED => vol_channel_a_reg,
		ENVELOPE => envelope_reg,
		
		VOL_OUT => channel_a_vol,
		CHANGED => channel_a_changed
	);		
	
	vol_b : entity work.PSG_volume
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,
		
		CHANNEL => channel_b_val,
		FIXED => vol_channel_b_reg,
		ENVELOPE => envelope_reg,
		
		VOL_OUT => channel_b_vol,
		CHANGED => channel_b_changed
	);		
	
	vol_c : entity work.PSG_volume
	PORT MAP
	( 
		CLK => clk,
		RESET_N => reset_n,		
		ENABLE => enable,
		
		CHANNEL => channel_c_val,
		FIXED => vol_channel_c_reg,
		ENVELOPE => envelope_reg,
		
		VOL_OUT => channel_c_vol,
		CHANGED => channel_c_changed
	);		
	
	-- outputs
	IOA_OUT <= ioa_reg;
	IOB_OUT <= iob_reg;
	IOA_OE <= io_output_reg(0);
	IOB_OE <= io_output_reg(1);
	channel_changed <= channel_a_changed or channel_b_changed or channel_c_changed;
	
end vhdl;


