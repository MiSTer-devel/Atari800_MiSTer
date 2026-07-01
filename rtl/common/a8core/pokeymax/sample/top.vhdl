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

ENTITY sample_top IS 
	GENERIC
	(
		enable_record : integer := 0
	);
	PORT
	(
		CLK : in std_logic;
		RESET_N : in std_logic;

		ENABLE : in std_logic;  -- end of cycle
		REQUEST : in std_logic; -- read request, provide data next cycle
		
		WRITE_ENABLE : in std_logic;
		ADDR : in std_logic_vector(4 downto 0);
		DI : in std_logic_vector(7 downto 0);

		DO : out std_logic_vector(7 downto 0);
		AUDIO0 : out signed(15 downto 0);
		AUDIO1 : out signed(15 downto 0);
		IRQ : out std_logic;

		AUDIO_IN0 : in signed(15 downto 0);
		AUDIO_IN1 : in signed(15 downto 0);
		AUDIO_IN2 : in signed(15 downto 0);
		AUDIO_IN3 : in signed(15 downto 0);

		RAM_ADDR : out std_logic_vector(15 downto 0);
		RAM_REQUEST : out std_logic;
		RAM_WRITE_ENABLE : out std_logic;
		RAM_READY : in std_logic;
		RAM_DATA : in std_logic_vector(7 downto 0);
		RAM_WRITE_DATA : out std_logic_vector(7 downto 0);

		ADPCM_STEP_ADDR : out std_logic_vector(6 downto 0);
		ADPCM_STEP_REQUEST : out std_logic;
		ADPCM_STEP_READY : in std_logic;
		ADPCM_STEP_VALUE : in std_logic_vector(14 downto 0)
	);
END sample_top;		
		
ARCHITECTURE vhdl OF sample_top IS
	signal CH1_REG : std_logic_vector(12 downto 0);
	signal CH0_REG : std_logic_vector(12 downto 0);
	signal CH1_NEXT : std_logic_vector(12 downto 0);
	signal CH0_NEXT : std_logic_vector(12 downto 0);
	signal CH3_REG : std_logic_vector(12 downto 0);
	signal CH2_REG : std_logic_vector(12 downto 0);
	signal CH3_NEXT : std_logic_vector(12 downto 0);
	signal CH2_NEXT : std_logic_vector(12 downto 0);

    signal ram_cpu_addr_next : std_logic_vector(15 downto 0);
    signal ram_cpu_addr_reg : std_logic_vector(15 downto 0);
    signal ram_cpu_write_enable : std_logic;
    signal ram_record_enabled_reg : std_logic_vector(3 downto 0);
    signal ram_record_enabled_next : std_logic_vector(3 downto 0);
    signal data_to_write : std_logic_vector(7 downto 0);

	signal ch0_start_addr_reg : std_logic_vector(15 downto 0);
	signal ch0_start_addr_next : std_logic_vector(15 downto 0);
	signal ch0_len_reg : std_logic_vector(15 downto 0);
	signal ch0_len_next : std_logic_vector(15 downto 0);
	signal ch0_period_reg : std_logic_vector(11 downto 0);
	signal ch0_period_next : std_logic_vector(11 downto 0);
	signal ch0_volume_reg : std_logic_vector(5 downto 0);
	signal ch0_volume_next : std_logic_vector(5 downto 0);

	signal ch1_start_addr_reg : std_logic_vector(15 downto 0);
	signal ch1_start_addr_next : std_logic_vector(15 downto 0);
	signal ch1_len_reg : std_logic_vector(15 downto 0);
	signal ch1_len_next : std_logic_vector(15 downto 0);
	signal ch1_period_reg : std_logic_vector(11 downto 0);
	signal ch1_period_next : std_logic_vector(11 downto 0);
	signal ch1_volume_reg : std_logic_vector(5 downto 0);
	signal ch1_volume_next : std_logic_vector(5 downto 0);

	signal ch2_start_addr_reg : std_logic_vector(15 downto 0);
	signal ch2_start_addr_next : std_logic_vector(15 downto 0);
	signal ch2_len_reg : std_logic_vector(15 downto 0);
	signal ch2_len_next : std_logic_vector(15 downto 0);
	signal ch2_period_reg : std_logic_vector(11 downto 0);
	signal ch2_period_next : std_logic_vector(11 downto 0);
	signal ch2_volume_reg : std_logic_vector(5 downto 0);
	signal ch2_volume_next : std_logic_vector(5 downto 0);

	signal ch3_start_addr_reg : std_logic_vector(15 downto 0);
	signal ch3_start_addr_next : std_logic_vector(15 downto 0);
	signal ch3_len_reg : std_logic_vector(15 downto 0);
	signal ch3_len_next : std_logic_vector(15 downto 0);
	signal ch3_period_reg : std_logic_vector(11 downto 0);
	signal ch3_period_next : std_logic_vector(11 downto 0);
	signal ch3_volume_reg : std_logic_vector(5 downto 0);
	signal ch3_volume_next : std_logic_vector(5 downto 0);
	
	signal dma_on_reg : std_logic_vector(3 downto 0);
	signal dma_on_next : std_logic_vector(3 downto 0);
	signal dma_on : std_logic;
	signal channel_reg : std_logic_vector(2 downto 0);
	signal channel_next : std_logic_vector(2 downto 0);
	signal ch0_addr : std_logic_vector(16 downto 0);
	signal ch1_addr : std_logic_vector(16 downto 0);
	signal ch2_addr : std_logic_vector(16 downto 0);
	signal ch3_addr : std_logic_vector(16 downto 0);

	signal irq_en_reg : std_logic_vector(3 downto 0);
	signal irq_en_next : std_logic_vector(3 downto 0);
	signal irq_trigger : std_logic_vector(3 downto 0);
	signal data_request : std_logic_vector(3 downto 0);
	signal irq_clear_n : std_logic_vector(3 downto 0);
	signal irq_active_reg : std_logic_vector(3 downto 0);
	signal irq_active_next : std_logic_vector(3 downto 0);

	signal adpcm_decoded : std_logic_vector(15 downto 0);
	signal adpcm_reg : std_logic_vector(3 downto 0);
	signal adpcm_next : std_logic_vector(3 downto 0);
	signal adpcm_data_request : std_logic;
	signal adpcm_data_in : std_logic_vector(3 downto 0);
	signal adpcm_on : std_logic;
	signal adpcm_channel : std_logic_vector(1 downto 0);
	signal adpcm_store : std_logic;
	signal adpcm_step_request_raw : std_logic;
	signal adpcm_step_ready_adj : std_logic;

	signal bits8_reg : std_logic_vector(3 downto 0);
	signal bits8_next : std_logic_vector(3 downto 0);
	signal bits8 : std_logic;

	signal addr_decoded5 : std_logic_vector(31 downto 0);	

	signal data_nibble : std_logic;

	signal store_data : std_logic_vector(12 downto 0);
	signal store_source : std_logic_vector(3 downto 0);
	signal store_channel : std_logic_vector(1 downto 0);
	signal store : std_logic;

	signal ram_request_next : std_logic_vector(2 downto 0);
	signal ram_request_reg : std_logic_vector(2 downto 0);
	signal ram_address_next : std_logic_vector(16 downto 0);
	signal ram_address_reg : std_logic_vector(16 downto 0);
	signal ram_data_to_write_reg : std_logic_vector(7 downto 0);
	signal ram_data_to_write_next : std_logic_vector(7 downto 0);

BEGIN

	decode_addr2 : entity work.complete_address_decoder
		generic map(width=>5)
		port map (addr_in=>ADDR(4 downto 0), addr_decoded=>addr_decoded5);

	process(addr_decoded5,CH0_REG,CH1_REG,CH2_REG,CH3_REG,
		ram_cpu_addr_reg,ram_data, 
		irq_en_reg,irq_active_reg,
		adpcm_reg,bits8_reg,
		ram_record_enabled_reg)
	begin
		DO <= (others=>'0');
	
		if (addr_decoded5(0)='1') then
			DO <= CH0_REG(12 downto 5);
		end if;
	
		if (addr_decoded5(1)='1') then
			DO <= CH1_REG(12 downto 5);
		end if;
	
		if (addr_decoded5(2)='1') then
			DO <= CH2_REG(12 downto 5);
		end if;
	
		if (addr_decoded5(3)='1') then
			DO <= CH3_REG(12 downto 5);
		end if;
	
		if (addr_decoded5(4)='1') then
			DO <= ram_cpu_addr_reg(7 downto 0);
		end if;
		if (addr_decoded5(5)='1') then
			DO <= ram_cpu_addr_reg(15 downto 8);
		end if;
		if (addr_decoded5(6)='1') then --manual addr inc
			DO <= ram_data;
		end if;
		if (addr_decoded5(17)='1') then
			DO(3 downto 0) <= irq_en_reg;
		end if;
		if (addr_decoded5(18)='1') then
			DO(3 downto 0) <= irq_active_reg;
		end if;
		if (addr_decoded5(19)='1') then
			DO(3 downto 0) <= adpcm_reg;
			DO(7 downto 4) <= bits8_reg;
		end if;
		if (enable_record = 1) then
 			if (addr_decoded5(20)='1') then
 				DO(3 downto 0) <= ram_record_enabled_reg;
 			end if;
 		end if;
	end process;

	process(adpcm_channel,adpcm_store,addr,bits8,dma_on,adpcm_on,write_enable)
	begin
		store <= '0';
		store_channel <= (others=>'0');
		store_source <= (others=>'0');

		if (write_enable='0' and dma_on='1') then
			store_channel <= adpcm_channel;
			store <= adpcm_store;
		elsif (write_enable='1') then
			store_channel <= ADDR(1 downto 0);
			store <= not(or_reduce(ADDR(4 downto 2)));
		end if;
		store_source(3) <= bits8;
		store_source(2) <= dma_on;
		store_source(1) <= adpcm_on;
		store_source(0) <= write_enable;
	end process;

	process(store_source,data_nibble,
		di,adpcm_decoded,ram_data)
	begin
		store_data <= (others=>'0');
		case store_source is
			when "0001"|"0011"|"0101"|"0111"|"1001"|"1011"|"1101"|"1111" =>
				store_data(12) <= not(di(7));
				store_data(11 downto 5) <= di(6 downto 0);
			when "0110"|"1110" =>
				store_data <= adpcm_decoded(15 downto 3);
			when "1100" =>
				store_data(12 downto 5) <= ram_data(7 downto 0);
			when "0100" =>
				if (data_nibble='0') then
					store_data(12 downto 9) <= ram_data(7 downto 4);
				else
					store_data(12 downto 9) <= ram_data(3 downto 0);
				end if;

			when others=>
		end case;
	end process;

	process( CH0_REG,CH1_REG,CH2_REG,CH3_REG,DI,store,store_data,store_channel)
	begin
		CH0_NEXT <= CH0_REG;
		CH1_NEXT <= CH1_REG;
		CH2_NEXT <= CH2_REG;
		CH3_NEXT <= CH3_REG;
	
		if (store='1') then
			case store_channel is
				when "00"=>
					CH0_NEXT <= store_data;
				when "01" =>
					CH1_NEXT <= store_data;
				when "10" =>
					CH2_NEXT <= store_data;
				when "11" => 
					CH3_NEXT <= store_data;
				when others =>
			end case;
		end if;
	end process;
	
	adpcm_decoder : entity work.sample_adpcm
		port map 
		(
			clk=>clk,
			reset_n=>reset_n,
			syncreset=>irq_trigger,

			select_channel=>adpcm_channel,

			store=>adpcm_store,

			data_out=>adpcm_decoded,

			dirty=>data_request,

			data_request => adpcm_data_request,
			data_ready => ram_request_reg(1) and RAM_READY,
			data_in => adpcm_data_in,

			step_addr => adpcm_step_addr,
			step_request => adpcm_step_request_raw,
			step_ready => adpcm_step_ready_adj,
			step_value => adpcm_step_value
		);
		--data_in=>ram_data, 
		--update=>data_request,
		--fetch=>dma,
		--data_nibble=>ch3_addr(0)&ch2_addr(0)&ch1_addr(0)&ch0_addr(0),
		-- TODO -> feed in data slower and each nibble
	adpcm_data_in <= ram_data(7 downto 4) when data_nibble='0' else ram_data(3 downto 0);

	adpcm_step_request <= adpcm_on and dma_on and adpcm_step_request_raw;
	adpcm_step_ready_adj <= (not(adpcm_on and dma_on) and adpcm_step_request_raw) or adpcm_step_ready;
	
	process(ADDR, addr_decoded5, WRITE_ENABLE, DI,
	ram_cpu_addr_reg,
	ch0_start_addr_reg, ch0_len_reg, ch0_period_reg, ch0_volume_reg,
	ch1_start_addr_reg, ch1_len_reg, ch1_period_reg, ch1_volume_reg,
	ch2_start_addr_reg, ch2_len_reg, ch2_period_reg, ch2_volume_reg,
	ch3_start_addr_reg, ch3_len_reg, ch3_period_reg, ch3_volume_reg,
	dma_on_reg,dma_on,
	channel_reg,
	irq_en_reg,irq_active_reg,irq_trigger,irq_clear_n,
	adpcm_reg, bits8_reg,
	ram_record_enabled_reg
	)
	begin
		ram_cpu_write_enable <= '0';
		ram_cpu_addr_next <= ram_cpu_addr_reg;
	
		ch0_start_addr_next <= ch0_start_addr_reg;
		ch0_len_next <= ch0_len_reg;
		ch0_period_next <= ch0_period_reg;
		ch0_volume_next <= ch0_volume_reg;
	
		ch1_start_addr_next <= ch1_start_addr_reg;
		ch1_len_next <= ch1_len_reg;
		ch1_period_next <= ch1_period_reg;
		ch1_volume_next <= ch1_volume_reg;
	
		ch2_start_addr_next <= ch2_start_addr_reg;
		ch2_len_next <= ch2_len_reg;
		ch2_period_next <= ch2_period_reg;
		ch2_volume_next <= ch2_volume_reg;
	
		ch3_start_addr_next <= ch3_start_addr_reg;
		ch3_len_next <= ch3_len_reg;
		ch3_period_next <= ch3_period_reg;
		ch3_volume_next <= ch3_volume_reg;
	
		dma_on_next <= dma_on_reg;
		bits8_next <= bits8_reg;
	
		channel_next <= channel_reg;
	
		irq_clear_n <= (others=>'1');
		irq_en_next <= irq_en_reg;
		irq_active_next <= (irq_active_reg or irq_trigger) and irq_en_reg and irq_clear_n;
	
		adpcm_next <= adpcm_reg;

		ram_record_enabled_next <= ram_record_enabled_reg;

		if (write_enable='1') then
			if (addr_decoded5(4)='1') then
				ram_cpu_addr_next(7 downto 0) <= DI;
			end if;
			if (addr_decoded5(5)='1') then
				ram_cpu_addr_next(15 downto 8) <= DI;
			end if;
			if (addr_decoded5(6)='1') then --manual addr inc
				ram_cpu_write_enable <= '1';
			end if;
			if (addr_decoded5(7)='1') then --auto addr inc
				ram_cpu_write_enable <= '1';
				ram_cpu_addr_next <= ram_cpu_addr_reg + 1;
			end if;

			if (addr_decoded5(8)='1') then
				channel_next(2 downto 0) <= DI(2 downto 0);
			end if;

			case channel_reg is
				when "001" =>
					if (addr_decoded5(9)='1') then
						ch0_start_addr_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(10)='1') then
						ch0_start_addr_next(15 downto 8) <= DI;
					end if;
					if (addr_decoded5(11)='1') then
						ch0_len_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(12)='1') then
						ch0_len_next(15 downto 8) <= DI;
					end if;
					if (addr_decoded5(13)='1') then
						ch0_period_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(14)='1') then
						ch0_period_next(11 downto 8) <= DI(3 downto 0);
					end if;
					if (addr_decoded5(15)='1') then
						ch0_volume_next(5 downto 0) <= DI(5 downto 0);
					end if;
				when "010" =>
					if (addr_decoded5(9)='1') then
						ch1_start_addr_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(10)='1') then
						ch1_start_addr_next(15 downto 8) <= DI;
					end if;
					if (addr_decoded5(11)='1') then
						ch1_len_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(12)='1') then
						ch1_len_next(15 downto 8) <= DI;
					end if;
					if (addr_decoded5(13)='1') then
						ch1_period_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(14)='1') then
						ch1_period_next(11 downto 8) <= DI(3 downto 0);
					end if;
					if (addr_decoded5(15)='1') then
						ch1_volume_next(5 downto 0) <= DI(5 downto 0);
					end if;
				when "011" =>
					if (addr_decoded5(9)='1') then
						ch2_start_addr_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(10)='1') then
						ch2_start_addr_next(15 downto 8) <= DI;
					end if;
					if (addr_decoded5(11)='1') then
						ch2_len_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(12)='1') then
						ch2_len_next(15 downto 8) <= DI;
					end if;
					if (addr_decoded5(13)='1') then
						ch2_period_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(14)='1') then
						ch2_period_next(11 downto 8) <= DI(3 downto 0);
					end if;
					if (addr_decoded5(15)='1') then
						ch2_volume_next(5 downto 0) <= DI(5 downto 0);
					end if;
				when "100" =>
					if (addr_decoded5(9)='1') then
						ch3_start_addr_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(10)='1') then
						ch3_start_addr_next(15 downto 8) <= DI;
					end if;
					if (addr_decoded5(11)='1') then
						ch3_len_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(12)='1') then
						ch3_len_next(15 downto 8) <= DI;
					end if;
					if (addr_decoded5(13)='1') then
						ch3_period_next(7 downto 0) <= DI;
					end if;
					if (addr_decoded5(14)='1') then
						ch3_period_next(11 downto 8) <= DI(3 downto 0);
					end if;
					if (addr_decoded5(15)='1') then
						ch3_volume_next(5 downto 0) <= DI(5 downto 0);
					end if;
				when others =>
			end case;
			if (addr_decoded5(16)='1') then
				dma_on_next <= DI(3 downto 0);
			end if;
			if (addr_decoded5(17)='1') then
				irq_en_next <= DI(3 downto 0);
			end if;
			if (addr_decoded5(18)='1') then
				irq_clear_n <= DI(3 downto 0); --write 0 to disable
			end if;
			if (addr_decoded5(19)='1') then
				adpcm_next <= DI(3 downto 0); 
				bits8_next <= DI(7 downto 4); 
			end if;
			if (enable_record = 1) then
				if (addr_decoded5(20)='1') then
					ram_record_enabled_next <= DI(3 downto 0);
				end if;
			end if;
		end if;
	end process;
	
	ch0_inst: entity work.sample_channel
	PORT MAP
	( 
		CLK => CLK,
		RESET_N => RESET_N,
		ENABLE => ENABLE,
	
		syncreset => (dma_on_next(0) xor dma_on_reg(0)),
		start_addr => ch0_start_addr_reg,
		len => ch0_len_reg,
		period => ch0_period_reg,
		
		twocycles => adpcm_reg(0) or not(bits8_reg(0)),
		
		addr => ch0_addr,
		irq => irq_trigger(0),
		req => data_request(0)
	);
	
	ch1_inst: entity work.sample_channel
	PORT MAP
	( 
		CLK => CLK,
		RESET_N => RESET_N,
		ENABLE => ENABLE,
	
		syncreset => (dma_on_next(1) xor dma_on_reg(1)),
		start_addr => ch1_start_addr_reg,
		len => ch1_len_reg,
		period => ch1_period_reg,
		
		twocycles => adpcm_reg(1) or not(bits8_reg(1)),
		
		addr => ch1_addr,
		irq => irq_trigger(1),
		req => data_request(1)
	);
	
	ch2_inst: entity work.sample_channel
	PORT MAP
	( 
		CLK => CLK,
		RESET_N => RESET_N,
		ENABLE => ENABLE,
	
		syncreset => (dma_on_next(2) xor dma_on_reg(2)),
		start_addr => ch2_start_addr_reg,
		len => ch2_len_reg,
		period => ch2_period_reg,
		
		twocycles => adpcm_reg(2) or not(bits8_reg(2)),
		
		addr => ch2_addr,
		irq => irq_trigger(2),
		req => data_request(2)
	);
	
	ch3_inst: entity work.sample_channel
	PORT MAP
	( 
		CLK => CLK,
		RESET_N => RESET_N,
		ENABLE => ENABLE,
	
		syncreset => (dma_on_next(3) xor dma_on_reg(3)),
		start_addr => ch3_start_addr_reg,
		len => ch3_len_reg,
		period => ch3_period_reg,
		
		twocycles => adpcm_reg(3) or not(bits8_reg(3)),
		
		addr => ch3_addr,
		irq => irq_trigger(3),
		req => data_request(3)
	);
	
	process (ch0_reg,ch1_reg,ch2_reg,ch3_reg,
		ch0_volume_reg,ch1_volume_reg,ch2_volume_reg,ch3_volume_reg)
		variable l : signed(26 downto 0);
		variable r : signed(26 downto 0);
	begin
		l :=     resize(signed(CH0_REG),18)*resize(signed('0'&ch0_volume_reg),9);
		l := l + resize(signed(CH3_REG),18)*resize(signed('0'&ch3_volume_reg),9);
		r :=     resize(signed(CH1_REG),18)*resize(signed('0'&ch1_volume_reg),9);
	    r := r + resize(signed(CH2_REG),18)*resize(signed('0'&ch2_volume_reg),9);

		-- TODO: probably need to register here?
		AUDIO0(15 downto 0) <= l(19 downto 4);
		AUDIO1(15 downto 0) <= r(19 downto 4);
	
		-- TODO: modulation?
		-- TODO: samples from rom and put in voice samples after core?
		-- TODO: 4 bit mode?
	
		-- options to set: per channel: modulate volume(4),modulate period(4),sample bits(4)
	end process;
	
	process(ch0_addr,ch1_addr,ch2_addr,ch3_addr,
		ram_cpu_addr_reg,
		adpcm_channel,
		request,
		dma_on_reg,
		adpcm_reg,
		bits8_reg,
		adpcm_data_request,
		ram_request_reg,ram_address_reg,ram_data_to_write_reg,ram_data,ram_ready,
		ram_record_enabled_reg,
		DI,RAM_CPU_WRITE_ENABLE,
		AUDIO_IN0,AUDIO_IN1,AUDIO_IN2,AUDIO_IN3)
	begin

		ram_address_next <= ram_address_reg;
		ram_request_next <= ram_request_reg;
		ram_data_to_write_next <= ram_data_to_write_reg;

		if ram_ready = '0' then
			ram_request_next <= "01" & adpcm_data_request;
			case adpcm_channel is
				when "00" =>
        			ram_address_next <= ch0_addr;
					if (enable_record=1) then
						if (ram_record_enabled_reg(0) ='1') then
					      ram_data_to_write_next <= std_logic_vector(AUDIO_IN0(15 downto 8));
					      ram_request_next(2) <= '1';
						end if;
					end if;
				when "01" =>
        			ram_address_next <= ch1_addr;
					if (enable_record=1) then
						if (ram_record_enabled_reg(1) ='1') then
					      ram_data_to_write_next <= std_logic_vector(AUDIO_IN1(15 downto 8));
					      ram_request_next(2) <= '1';
						end if;
					end if;
				when "10" =>
        			ram_address_next <= ch2_addr;
					if (enable_record=1) then
						if (ram_record_enabled_reg(2) ='1') then
					      ram_data_to_write_next <= std_logic_vector(AUDIO_IN2(15 downto 8));
					      ram_request_next(2) <= '1';
						end if;
					end if;
				when "11" =>
        			ram_address_next <= ch3_addr;
					if (enable_record=1) then
						if (ram_record_enabled_reg(3) ='1') then
					      ram_data_to_write_next <= std_logic_vector(AUDIO_IN3(15 downto 8));
					      ram_request_next(2) <= '1';
						end if;
					end if;
			end case;
	
			if (request='1') then
				ram_address_next(16 downto 1) <= ram_cpu_addr_reg;
				ram_request_next <= RAM_CPU_WRITE_ENABLE & "01";
				ram_data_to_write_next <= DI;
			end if;
		else
			ram_request_next <= "000";
		end if;
	end process;

	data_nibble <= ram_address_reg(0);
	adpcm_on <= adpcm_reg(to_integer(unsigned(adpcm_channel)));
	dma_on <= dma_on_reg(to_integer(unsigned(adpcm_channel)));
	bits8 <= bits8_reg(to_integer(unsigned(adpcm_channel)));

	RAM_REQUEST <= ram_request_reg(0);
	RAM_ADDR <= ram_address_reg(16 downto 1);
	RAM_WRITE_DATA <= ram_data_to_write_reg;
	RAM_WRITE_ENABLE <= ram_request_reg(2);

	process(clk,reset_n)
	begin
		if (reset_n='0') then
			CH0_REG <= (others=>'0');
			CH1_REG <= (others=>'0');
			CH2_REG <= (others=>'0');
			CH3_REG <= (others=>'0');
			ram_cpu_addr_reg <= (others=>'0');
	
			ch0_start_addr_reg <= (others=>'0');
			ch0_len_reg <= (others=>'0');
			ch0_period_reg <= (others=>'0');
			ch0_volume_reg <= (others=>'1');
	
			ch1_start_addr_reg <= (others=>'0');
			ch1_len_reg <= (others=>'0');
			ch1_period_reg <= (others=>'0');
			ch1_volume_reg <= (others=>'1');
	
			ch2_start_addr_reg <= (others=>'0');
			ch2_len_reg <= (others=>'0');
			ch2_period_reg <= (others=>'0');
			ch2_volume_reg <= (others=>'1');
	
			ch3_start_addr_reg <= (others=>'0');
			ch3_len_reg <= (others=>'0');
			ch3_period_reg <= (others=>'0');
			ch3_volume_reg <= (others=>'1');
	
			dma_on_reg <= (others=>'0');
			irq_en_reg <= (others=>'0');
			irq_active_reg <= (others=>'0');
			channel_reg <= (others=>'0');
			
			adpcm_reg <= (others=>'0');
			ram_request_reg <= "000";
			ram_address_reg <= (others=>'0');
			ram_data_to_write_reg <= (others=>'0');

			bits8_reg <= (others=>'1');

			if (enable_record = 1) then
				ram_record_enabled_reg  <= (others=>'0');
			end if;
	
		elsif (clk'event and clk='1') then
			CH0_REG <= CH0_NEXT;
			CH1_REG <= CH1_NEXT;
			CH2_REG <= CH2_NEXT;
			CH3_REG <= CH3_NEXT;
			ram_cpu_addr_reg <= ram_cpu_addr_next;
	
			ch0_start_addr_reg <= ch0_start_addr_next;
			ch0_len_reg <= ch0_len_next;
			ch0_period_reg <= ch0_period_next;
			ch0_volume_reg <= ch0_volume_next;
	
			ch1_start_addr_reg <= ch1_start_addr_next;
			ch1_len_reg <= ch1_len_next;
			ch1_period_reg <= ch1_period_next;
			ch1_volume_reg <= ch1_volume_next;
	
			ch2_start_addr_reg <= ch2_start_addr_next;
			ch2_len_reg <= ch2_len_next;
			ch2_period_reg <= ch2_period_next;
			ch2_volume_reg <= ch2_volume_next;
	
			ch3_start_addr_reg <= ch3_start_addr_next;
			ch3_len_reg <= ch3_len_next;
			ch3_period_reg <= ch3_period_next;
			ch3_volume_reg <= ch3_volume_next;
	
			dma_on_reg <= dma_on_next;
			irq_en_reg <= irq_en_next;
			irq_active_reg <= irq_active_next;
			channel_reg <= channel_next;
	
			adpcm_reg <= adpcm_next;
			ram_request_reg <= ram_request_next;
			ram_address_reg <= ram_address_next;
			ram_data_to_write_reg <= ram_data_to_write_next;

			bits8_reg <= bits8_next;
        		 
			if (enable_record = 1) then
				ram_record_enabled_reg <= ram_record_enabled_next;
			end if;
		end if;
	end process;
	
	IRQ <= or_reduce(irq_active_reg);

END vhdl;
