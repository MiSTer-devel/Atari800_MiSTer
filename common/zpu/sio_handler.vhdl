---------------------------------------------------------------------------
-- (c) 2017 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_MISC.all;

-- Now USB is handled by ZPU its dropping SIO commands on the floor while polling USB
-- Capture the SIO command here, so it can poll the latest command instead
-- All other processing is direct to pokey...

-- memory map
-- 0 = transmit (w)
-- 1 = tx fifo status (r)
-- 2 = fetch/receive (r) - requests next data - i.e. first read trash
-- 3 = rx fifo status (r)
-- 4 = divisor (w) - applied after transmit done
-- 5 = framing error (auto clear) (r) (command&serial)
ENTITY sio_handler IS
PORT 
( 
	CLK : IN STD_LOGIC;
	ADDR : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
	CPU_DATA_IN : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
	EN : IN STD_LOGIC;
	WR_EN : IN STD_LOGIC;
	
	RESET_N : IN STD_LOGIC;

	-- clock for pokey
	POKEY_ENABLE : in std_logic;

	-- ATARI interface (in future we can also turbo load by directly hitting memory...)
	SIO_DATA_IN  : out std_logic;
	SIO_COMMAND : in std_logic;
	SIO_DATA_OUT : in std_logic;
	SIO_CLK_OUT : in std_logic;
	
	-- CPU interface
	DATA_OUT : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
);
END sio_handler;

ARCHITECTURE vhdl OF sio_handler IS

	signal sio_data_out_reg : std_logic;
	signal sio_data_out_next : std_logic;

	signal sio_command_next : std_logic;
	signal sio_command_reg : std_logic;
	signal sio_command_count_next : std_logic_vector(6 downto 0);
	signal sio_command_count_reg : std_logic_vector(6 downto 0);
	signal sio_command_framing_error_reg : std_logic;
	signal sio_command_framing_error_next : std_logic;
	signal sio_command_rising : std_logic;

	signal receive_write : std_logic;

	signal addr_decoded : std_logic_vector(15 downto 0);

	signal receive_enable : std_logic;
	signal transmit_enable : std_logic;
	
	signal fifo_tx_write : std_logic;	
	signal fifo_tx_full : std_logic;
	signal fifo_tx_empty : std_logic;	
	signal fifo_tx_advance : std_logic;
	signal fifo_tx_data : std_logic_vector(7 downto 0);	
	signal fifo_tx_count : std_logic_vector(7 downto 0);
	
	signal fifo_rx_data : std_logic_vector(14 downto 0);
	signal fifo_rx_full : std_logic;
	signal fifo_rx_empty : std_logic;	
	signal fifo_rx_advance : std_logic;
	signal fifo_rx_count : std_logic_vector(7 downto 0);

	signal divisor_next : std_logic_vector(7 downto 0);
	signal divisor_reg : std_logic_vector(7 downto 0);	

	signal pending_divisor_next : std_logic_vector(7 downto 0);
	signal pending_divisor_reg : std_logic_vector(7 downto 0);	
	
	signal transmit_divisor_count_next : std_logic_vector(7 downto 0);
	signal transmit_divisor_count_reg : std_logic_vector(7 downto 0);	

	signal receive_divisor_count_next : std_logic_vector(7 downto 0);
	signal receive_divisor_count_reg : std_logic_vector(7 downto 0);	
	signal receive_divisor_next : std_logic_vector(7 downto 0);
	signal receive_divisor_reg : std_logic_vector(7 downto 0);	
	
	signal sio_clk_out_reg : std_logic;

	signal data_out_next : std_logic_vector(15 downto 0);
	signal data_out_reg : std_logic_vector(15 downto 0);	 -- have to return results NEXT cycle!

	constant P2S_STATE_WAIT    : std_logic_vector(3 downto 0) := "0000";
	constant P2S_STATE_STOP    : std_logic_vector(3 downto 0) := "0001";
	constant P2S_STATE_SHIFT_0 : std_logic_vector(3 downto 0) := "1000";
	constant P2S_STATE_SHIFT_1 : std_logic_vector(3 downto 0) := "1001";
	constant P2S_STATE_SHIFT_2 : std_logic_vector(3 downto 0) := "1010";
	constant P2S_STATE_SHIFT_3 : std_logic_vector(3 downto 0) := "1011";
	constant P2S_STATE_SHIFT_4 : std_logic_vector(3 downto 0) := "1100";
	constant P2S_STATE_SHIFT_5 : std_logic_vector(3 downto 0) := "1101";
	constant P2S_STATE_SHIFT_6 : std_logic_vector(3 downto 0) := "1110";
	constant P2S_STATE_SHIFT_7 : std_logic_vector(3 downto 0) := "1111";
	signal p2s_state_next : std_logic_vector(3 downto 0);
	signal p2s_state_reg : std_logic_vector(3 downto 0);
	signal p2s_shift_next : std_logic_vector(7 downto 0);
	signal p2s_shift_reg : std_logic_vector(7 downto 0);
	signal p2s_transmit_next : std_logic;
	signal p2s_transmit_reg : std_logic;
	signal p2s_idle : std_logic;

	constant S2P_STATE_WAIT    : std_logic_vector(3 downto 0) := "0000";
	constant S2P_STATE_STOP    : std_logic_vector(3 downto 0) := "0001";
	constant S2P_STATE_SHIFT_0 : std_logic_vector(3 downto 0) := "1000";
	constant S2P_STATE_SHIFT_1 : std_logic_vector(3 downto 0) := "1001";
	constant S2P_STATE_SHIFT_2 : std_logic_vector(3 downto 0) := "1010";
	constant S2P_STATE_SHIFT_3 : std_logic_vector(3 downto 0) := "1011";
	constant S2P_STATE_SHIFT_4 : std_logic_vector(3 downto 0) := "1100";
	constant S2P_STATE_SHIFT_5 : std_logic_vector(3 downto 0) := "1101";
	constant S2P_STATE_SHIFT_6 : std_logic_vector(3 downto 0) := "1110";
	constant S2P_STATE_SHIFT_7 : std_logic_vector(3 downto 0) := "1111";
	signal s2p_state_next : std_logic_vector(3 downto 0);
	signal s2p_state_reg : std_logic_vector(3 downto 0);
	signal s2p_shift_next : std_logic_vector(6 downto 0);
	signal s2p_shift_reg : std_logic_vector(6 downto 0);
	signal s2p_write : std_logic;
	signal s2p_framing_error_reg : std_logic;
	signal s2p_framing_error_next : std_logic;
	signal s2p_start : std_logic;

	signal framing_error_clear : std_logic;
	
begin
	-- register
	process(clk,reset_n)
	begin
		if (reset_n = '0') then
			sio_data_out_reg <= '1';
			sio_command_reg <= '1';
			sio_command_count_reg <= (others=>'0');
			sio_command_framing_error_reg <= '0';
			divisor_reg <= (others=>'0');
			pending_divisor_reg <= (others=>'0');
			transmit_divisor_count_reg <= (others=>'0');
			receive_divisor_count_reg <= (others=>'0');
			receive_divisor_reg <= (others=>'0');
			s2p_state_reg <= S2P_STATE_WAIT;
			s2p_shift_reg <= (others=>'1');
			s2p_framing_error_reg <= '0';
			p2s_state_reg <= P2S_STATE_WAIT;
			p2s_shift_reg <= (others=>'1');
			p2s_transmit_reg <= '1';
			data_out_reg <= (others=>'0');
			sio_clk_out_reg <='0';
		elsif (clk'event and clk='1') then
			sio_data_out_reg <= sio_data_out_next;
			sio_command_reg <= sio_command_next;
			sio_command_count_reg <= sio_command_count_next;
			sio_command_framing_error_reg <= sio_command_framing_error_next;
			divisor_reg <= divisor_next;
			pending_divisor_reg <= pending_divisor_next;
			transmit_divisor_count_reg <= transmit_divisor_count_next;
			receive_divisor_count_reg <= receive_divisor_count_next;
			receive_divisor_reg <= receive_divisor_next;
			s2p_state_reg <= s2p_state_next;
			s2p_shift_reg <= s2p_shift_next;
			s2p_framing_error_reg <= s2p_framing_error_next;
			p2s_state_reg <= p2s_state_next;
			p2s_shift_reg <= p2s_shift_next;
			p2s_transmit_reg <= p2s_transmit_next;
			data_out_reg <= data_out_next;
			sio_clk_out_reg <= sio_clk_out;
		end if;
	end process;

	-- decode address
	decode_addr1 : entity work.complete_address_decoder
		generic map(width=>4)
		port map (addr_in=>addr(3 downto 0), addr_decoded=>addr_decoded);
				
	-- Writes to registers
	process(cpu_data_in,wr_en,addr_decoded, addr, pending_divisor_reg)
	begin
		fifo_tx_write <= '0';
		pending_divisor_next <= pending_divisor_reg;

		if (wr_en = '1') then
			if (addr_decoded(0) = '1') then
				fifo_tx_write <= '1';
			end if;	
			if (addr_decoded(4) = '1') then
				pending_divisor_next <= cpu_data_in(7 downto 0);
			end if;
		end if;
	end process;

	-- Only change divisor once we are done transmitting
	process(divisor_reg,pending_divisor_reg,p2s_idle)
	begin
		divisor_next<=divisor_reg;

		if (not(pending_divisor_reg = divisor_reg) and p2s_idle='1') then
			divisor_next <= pending_divisor_reg;
		end if;
	end process;

	-- Count command packets rather than storing command position in fifo
	process(s2p_start,sio_command_reg,sio_command,sio_command_count_reg,sio_command_framing_error_reg,framing_error_clear)
	begin
		sio_command_next <= sio_command;
		sio_command_count_next <= sio_command_count_reg;
		sio_command_framing_error_next <= sio_command_framing_error_reg;
		sio_command_rising <= '0';

		if (sio_command_reg='1') then -- not a command
			sio_command_count_next <= (others=>'0');
		end if;

		if (s2p_start='1' and sio_command_reg='0') then
			sio_command_count_next <= std_logic_vector(unsigned(sio_command_count_reg)+1);
		end if;

		if (sio_command_reg='0' and sio_command='1') then -- rising edge
			sio_command_rising <= '1';
			if (sio_command_count_reg /= "0000101") then 
				sio_command_framing_error_next <= '1'; 
			end if;
		end if;

		if (framing_error_clear='1') then
			sio_command_framing_error_next <= '0';
		end if;
	end process;
	
	-- Read from registers
	process(en,addr_decoded, fifo_rx_data, fifo_tx_full, fifo_tx_empty, fifo_tx_count, fifo_rx_full, fifo_rx_empty, fifo_rx_count, s2p_framing_error_reg, sio_command_framing_error_reg, receive_divisor_reg)
	begin
		data_out_next <= X"0000";
		fifo_rx_advance <= '0';
		framing_error_clear <= '0';

		if (en = '1') then
			if (addr_decoded(1) = '1') then
				data_out_next(9 downto 0) <= fifo_tx_full&fifo_tx_empty&fifo_tx_count;
			end if;
			if (addr_decoded(2) = '1') then
				if fifo_rx_empty = '0' then
					data_out_next(14 downto 0) <= fifo_rx_data; -- assumed to be already valid
					fifo_rx_advance <= '1'; -- data read, next byte please
				end if;
			end if;
			if (addr_decoded(3) = '1') then
				data_out_next(9 downto 0) <= fifo_rx_full&fifo_rx_empty&fifo_rx_count;
			end if;
			if (addr_decoded(4) = '1') then
				data_out_next(7 downto 0) <= receive_divisor_reg;
			end if;
			if (addr_decoded(5) = '1') then
				data_out_next(1 downto 0) <= sio_command_framing_error_reg&s2p_framing_error_reg;
				framing_error_clear <= '1';
			end if;
		end if;
		
	end process;

	-- serial enable generation
	process(divisor_reg,pokey_enable,transmit_divisor_count_reg,sio_data_out_reg, sio_data_out_next, s2p_state_reg)
	begin
		transmit_divisor_count_next <= transmit_divisor_count_reg;
		transmit_enable <= '0';

		if (pokey_enable='1') then
			transmit_divisor_count_next <= std_logic_vector(unsigned(transmit_divisor_count_reg)-to_unsigned(1,1));
			if or_reduce(transmit_divisor_count_reg)='0' then
				transmit_divisor_count_next <= divisor_reg;
				transmit_enable <= '1';
			end if;
		end if;
	end process;

	process(sio_clk_out, sio_clk_out_reg)
	begin
		-- 0->1 pokey transmit
		-- 1->0 receive...

		receive_enable <= '0';
		if (sio_clk_out_reg='1' and sio_clk_out='0') then
			receive_enable <= '1';
		end if;

	end process;

	process(pokey_enable,receive_enable,receive_divisor_reg,receive_divisor_count_reg)
	begin
		receive_divisor_next <= receive_divisor_reg;
		receive_divisor_count_next <= receive_divisor_count_reg;

		if (pokey_enable='1') then
			receive_divisor_count_next <= std_logic_vector(unsigned(receive_divisor_count_reg)+1);
		end if;

		if (receive_enable='1') then
			receive_divisor_next <= receive_divisor_count_reg;
			receive_divisor_count_next <= (others=>'0');
		end if;

	end process;

	-- Transmit fifo (7-0= data)
--transmit_fifo : work.std_fifo
--	generic_map (
--		DATA_WIDTH => 8,
--		FIFO_DEPTH => 256
--	)
--	port_map (
--		CLK => CLK,
--		RST => RESET,
--		WriteEn => fifo_tx_write,
--		DataIn => cpu_data_in(7 downto 0),
--		ReadEn => fifo_tx_advance,
--		DataOut => fifo_tx_data,
--		Empty => fifo_tx_empty,
--		Full => fifo_tx_full
--	);


transmit_fifo : work.fifo_transmit
	PORT MAP
	(
		clock		=> clk,
		data		=> cpu_data_in(7 downto 0),
		rdreq		=> fifo_tx_advance,
		wrreq		=> fifo_tx_write,
		empty		=> fifo_tx_empty,
		full		=> fifo_tx_full,
		q		=> fifo_tx_data,
		usedw		=> fifo_tx_count
	);

	-- parallel to serial converter
	process(p2s_state_reg, p2s_transmit_reg,p2s_shift_reg,fifo_tx_data,fifo_tx_empty,transmit_enable)
	begin
		p2s_state_next <= p2s_state_reg;
		p2s_transmit_next <= p2s_transmit_reg;
		p2s_shift_next <= p2s_shift_reg;
		fifo_tx_advance <= '0';
		p2s_idle <= '0';

		if transmit_enable='1' then
			p2s_shift_next <= '1'&p2s_shift_reg(7 downto 1);
			case p2s_state_reg is
				when P2S_STATE_WAIT =>
					p2s_idle <= fifo_tx_empty;
					if fifo_tx_empty='0' then
						p2s_state_next <= P2S_STATE_SHIFT_0;
						fifo_tx_advance <= '1';
						p2s_shift_next <= fifo_tx_data; -- already valid (depends on fifo type: todo)
						p2s_transmit_next <= '0'; --start
					end if;
				when P2S_STATE_SHIFT_0 =>
					p2s_transmit_next <= p2s_shift_reg(0);
					p2s_state_next <= P2S_STATE_SHIFT_1;
				when P2S_STATE_SHIFT_1 =>
					p2s_transmit_next <= p2s_shift_reg(0);
					p2s_state_next <= P2S_STATE_SHIFT_2;
				when P2S_STATE_SHIFT_2 =>
					p2s_transmit_next <= p2s_shift_reg(0);
					p2s_state_next <= P2S_STATE_SHIFT_3;
				when P2S_STATE_SHIFT_3 =>
					p2s_transmit_next <= p2s_shift_reg(0);
					p2s_state_next <= P2S_STATE_SHIFT_4;
				when P2S_STATE_SHIFT_4 =>
					p2s_transmit_next <= p2s_shift_reg(0);
					p2s_state_next <= P2S_STATE_SHIFT_5;
				when P2S_STATE_SHIFT_5 =>
					p2s_transmit_next <= p2s_shift_reg(0);
					p2s_state_next <= P2S_STATE_SHIFT_6;
				when P2S_STATE_SHIFT_6 =>
					p2s_transmit_next <= p2s_shift_reg(0);
					p2s_state_next <= P2S_STATE_SHIFT_7;
				when P2S_STATE_SHIFT_7 =>
					p2s_transmit_next <= p2s_shift_reg(0);
					p2s_state_next <= P2S_STATE_STOP;
				when P2S_STATE_STOP =>
					p2s_transmit_next <= '1'; --stop
					p2s_state_next <= P2S_STATE_WAIT; -- send stop bit, check fifo
				when others => 
					p2s_transmit_next <= '1'; --stop
					p2s_state_next <= P2S_STATE_WAIT; -- send stop bit, check fifo
			end case;
		end if;
	end process;

	-- Receive fifo (8=command, 7-0=data)
--receive_fifo : work.std_fifo
--	generic_map (
--		DATA_WIDTH => 9,
--		FIFO_DEPTH => 256
--	)
--	port_map (
--		CLK => CLK,
--		RST => RESET,
--		WriteEn => s2p_write,
--		DataIn => sio_command&s2p_data,
--		ReadEn => fifo_rx_advance,
--		DataOut => fifo_rx_data,
--		Empty => fifo_rx_empty,
--		Full => fifo_rx_full
--	);


	sio_data_out_next <= sio_data_out;

	receive_write <= s2p_write or sio_command_rising;

receive_fifo : entity work.fifo_receive
	PORT MAP
	(
		clock		=> clk,
		data		=> sio_command_count_reg&sio_data_out_reg&s2p_shift_reg(6 downto 0),
		rdreq		=> fifo_rx_advance,
		wrreq		=> receive_write,
		empty		=> fifo_rx_empty,
		full		=> fifo_rx_full,
		q		=> fifo_rx_data,
		usedw		=> fifo_rx_count
	);

	-- serial to parallel converter
	-- 0 = start bit (space)
	-- 8 data bits
	-- 1 = stop bit (mask)
	-- Note:sio_data_out_reg = computer out, zpu in...
	process(s2p_state_reg,s2p_shift_reg,receive_enable,sio_data_out_reg,framing_error_clear, s2p_framing_error_reg)
	begin
		s2p_state_next <= s2p_state_reg;
		s2p_shift_next <= s2p_shift_reg;
		s2p_framing_error_next <= s2p_framing_error_reg;

		s2p_start <= '0';
		s2p_write <= '0';

		if (framing_error_clear='1') then
			s2p_framing_error_next <= '0';
		end if;
		
		if (receive_enable='1') then
			s2p_shift_next <= sio_data_out_reg&s2p_shift_reg(6 downto 1);

			case s2p_state_reg is
				when S2P_STATE_WAIT =>
					if (sio_data_out_reg='0') then -- start bit -- TODO - sync clock??
						s2p_state_next <= S2P_STATE_SHIFT_0;
						s2p_start <= '1';
					end if;
				when S2P_STATE_SHIFT_0 =>
					s2p_state_next <= S2P_STATE_SHIFT_1;
				when S2P_STATE_SHIFT_1 =>
					s2p_state_next <= S2P_STATE_SHIFT_2;
				when S2P_STATE_SHIFT_2 =>
					s2p_state_next <= S2P_STATE_SHIFT_3;
				when S2P_STATE_SHIFT_3 =>
					s2p_state_next <= S2P_STATE_SHIFT_4;
				when S2P_STATE_SHIFT_4 =>
					s2p_state_next <= S2P_STATE_SHIFT_5;
				when S2P_STATE_SHIFT_5 =>
					s2p_state_next <= S2P_STATE_SHIFT_6;
				when S2P_STATE_SHIFT_6 =>
					s2p_state_next <= S2P_STATE_SHIFT_7;
				when S2P_STATE_SHIFT_7 =>
					s2p_write <= '1';
					s2p_state_next <= S2P_STATE_STOP;
				when S2P_STATE_STOP =>
					s2p_framing_error_next <= s2p_framing_error_reg or not(sio_data_out_reg);
					s2p_state_next <= S2P_STATE_WAIT;
				when others =>
					s2p_state_next <= S2P_STATE_WAIT;
			end case;
		end if;

	end process;
	
	-- output
	sio_data_in <= p2s_transmit_reg;
	data_out <= data_out_reg;

end vhdl;


