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
use IEEE.STD_LOGIC_MISC.all;

ENTITY sample_adpcm IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

	SYNCRESET : IN STD_LOGIC_VECTOR(3 downto 0);     -- reset accumulator/step for next update

	select_channel : out std_logic_vector(1 downto 0); -- ask for current data for this channel

	store : OUT std_logic;
	data_out : OUT std_logic_vector(15 downto 0);    -- current output (signed)

	dirty : IN STD_LOGIC_VECTOR(3 downto 0);         -- channel needs updating

	data_request : out std_logic;
	data_ready : in std_logic;
	data_in : in std_logic_vector(3 downto 0);

	STEP_ADDR : out std_logic_vector(6 downto 0);    -- ask for step value
	STEP_REQUEST : out std_logic;
	STEP_READY : in std_logic;
	STEP_VALUE : in std_logic_vector(14 downto 0)
);
END sample_adpcm;

ARCHITECTURE vhdl OF sample_adpcm IS
	
        function stepadj_fn(x: std_logic_vector(2 downto 0)) return signed is
        begin
                case x is
when "000" => return to_signed(-1,5);
when "001" => return to_signed(-1,5);
when "010" => return to_signed(-1,5);
when "011" => return to_signed(-1,5);
when "100" => return to_signed(2,5);
when "101" => return to_signed(4,5);
when "110" => return to_signed(6,5);
when "111" => return to_signed(8,5);
                end case;
        end stepadj_fn;			  
		  
	signal acc0_reg : signed(15 downto 0);
	signal acc0_next : signed(15 downto 0);

	signal acc1_reg : signed(15 downto 0);
	signal acc1_next : signed(15 downto 0);

	signal acc2_reg : signed(15 downto 0);
	signal acc2_next : signed(15 downto 0);

	signal acc3_reg : signed(15 downto 0);
	signal acc3_next : signed(15 downto 0);
	
	signal acc_next : signed(15 downto 0);
	signal acc_mux : signed(15 downto 0);

	signal decstep0_reg : unsigned(6 downto 0);
	signal decstep0_next : unsigned(6 downto 0);

	signal decstep1_reg : unsigned(6 downto 0);
	signal decstep1_next : unsigned(6 downto 0);

	signal decstep2_reg : unsigned(6 downto 0);
	signal decstep2_next : unsigned(6 downto 0);

	signal decstep3_reg : unsigned(6 downto 0);
	signal decstep3_next : unsigned(6 downto 0);
	
	signal decstep_next : unsigned(6 downto 0);
	signal decstep_mux : unsigned(6 downto 0);
	
	signal write_ch0 : std_logic;
	signal write_ch1 : std_logic;
	signal write_ch2 : std_logic;
	signal write_ch3 : std_logic;
	
	signal sel : std_logic_vector(1 downto 0);

	signal syncreset_next : std_logic_vector(3 downto 0);
	signal syncreset_reg : std_logic_vector(3 downto 0);

	signal dirty_reg : std_logic_vector(3 downto 0); 
	signal dirty_next : std_logic_vector(3 downto 0);

	signal code_reg : std_logic_vector(3 downto 0); 
	signal code_next : std_logic_vector(3 downto 0); 

	signal state_reg : std_logic_vector(2 downto 0);
	signal state_next: std_logic_vector(2 downto 0); 
	constant state_ch0_mem_req   : std_logic_vector(2 downto 0) := "000";
	constant state_ch0_step_req  : std_logic_vector(2 downto 0) := "001";
	constant state_ch1_mem_req   : std_logic_vector(2 downto 0) := "010";
	constant state_ch1_step_req  : std_logic_vector(2 downto 0) := "011";
	constant state_ch2_mem_req   : std_logic_vector(2 downto 0) := "100";
	constant state_ch2_step_req  : std_logic_vector(2 downto 0) := "101";
	constant state_ch3_mem_req   : std_logic_vector(2 downto 0) := "110";
	constant state_ch3_step_req  : std_logic_vector(2 downto 0) := "111";
BEGIN
	-- register
	process(clk,reset_n)
	begin
		if (reset_n='0') then
			acc0_reg <= (others=>'0');
			acc1_reg <= (others=>'0');
			acc2_reg <= (others=>'0');
			acc3_reg <= (others=>'0');
			decstep0_reg <= (others=>'0');
			decstep1_reg <= (others=>'0');
			decstep2_reg <= (others=>'0');
			decstep3_reg <= (others=>'0');
			syncreset_reg <= (others=>'0');
			dirty_reg <= (others=>'0');
			code_reg <= (others=>'0');
			state_reg <= state_ch0_mem_req;
		elsif (clk'event and clk='1') then
			acc0_reg <= acc0_next;
			acc1_reg <= acc1_next;
			acc2_reg <= acc2_next;
			acc3_reg <= acc3_next;
			decstep0_reg <= decstep0_next;
			decstep1_reg <= decstep1_next;
			decstep2_reg <= decstep2_next;
			decstep3_reg <= decstep3_next;
			syncreset_reg <= syncreset_next;
			dirty_reg <= dirty_next;
			code_reg <= code_next;
			state_reg <= state_next;
		end if;
	end process;

	process(state_reg, dirty, dirty_reg, code_reg, data_in, data_ready, step_ready)
	begin
		code_next <= code_reg;
		dirty_next <= dirty_reg or dirty;
		state_next <= state_reg;

		data_request <= '0';
		step_request <= '0';
		sel <= (others=>'0');
		write_ch0 <= '0';
		write_ch1 <= '0';
		write_ch2 <= '0';
		write_ch3 <= '0';

		store <= step_ready;
		if (data_ready='1') then
			code_next <= data_in;
		end if;

		case state_reg is
			when state_ch0_mem_req =>
				sel <= "00";
				data_request <= dirty_reg(0);
				if (data_ready='1') then
					code_next <= data_in;
					state_next <= state_ch0_step_req;
				end if;
				if (dirty_reg(0)='0') then
					state_next <= state_ch1_mem_req;
				end if;
			when state_ch0_step_req =>
				step_request <= '1';
				sel <= "00";
				write_ch0 <= step_ready;
				if (step_ready='1') then
					state_next <= state_ch1_mem_req;
					dirty_next(0) <= '0';
				end if;

			when state_ch1_mem_req =>
				sel <= "01";
				data_request <= dirty_reg(1);
				if (data_ready='1') then
					code_next <= data_in;
					state_next <= state_ch1_step_req;
				end if;
				if (dirty_reg(1)='0') then
					state_next <= state_ch2_mem_req;
				end if;
			when state_ch1_step_req =>
				step_request <= '1';
				sel <= "01";
				write_ch1 <= step_ready;
				if (step_ready='1') then
					state_next <= state_ch2_mem_req;
					dirty_next(1) <= '0';
				end if;

			when state_ch2_mem_req =>
				sel <= "10";
				data_request <= dirty_reg(2);
				if (data_ready='1') then
					code_next <= data_in;
					state_next <= state_ch2_step_req;
				end if;
				if (dirty_reg(2)='0') then
					state_next <= state_ch3_mem_req;
				end if;
			when state_ch2_step_req =>
				step_request <= '1';
				sel <= "10";
				write_ch2 <= step_ready;
				if (step_ready='1') then
					state_next <= state_ch3_mem_req;
					dirty_next(2) <= '0';
				end if;

			when state_ch3_mem_req =>
				sel <= "11";
				data_request <= dirty_reg(3);
				if (data_ready='1') then
					code_next <= data_in;
					state_next <= state_ch3_step_req;
				end if;
				if (dirty_reg(3)='0') then
					state_next <= state_ch0_mem_req;
				end if;
			when state_ch3_step_req =>
				step_request <= '1';
				sel <= "11";
				write_ch3 <= step_ready;
				if (step_ready='1') then
					state_next <= state_ch0_mem_req;
					dirty_next(3) <= '0';
				end if;
			when others =>	
				state_next <= state_ch0_mem_req;
		end case;
	end process;

	process(acc0_reg, acc1_reg, acc2_reg, acc3_reg,
		decstep0_reg, decstep1_reg, decstep2_reg, decstep3_reg,
	       	acc_next, decstep_next,
				write_ch0,write_ch1,write_ch2,write_ch3)
	begin
		acc0_next <= acc0_reg;
		acc1_next <= acc1_reg;
		acc2_next <= acc2_reg;
		acc3_next <= acc3_reg;
		decstep0_next <= decstep0_reg;
		decstep1_next <= decstep1_reg;
		decstep2_next <= decstep2_reg;
		decstep3_next <= decstep3_reg;
	
	   if (write_ch0='1') then
			acc0_next <= acc_next;			
			decstep0_next <= decstep_next;			
		end if;
		
	   if (write_ch1='1') then
			acc1_next <= acc_next;			
			decstep1_next <= decstep_next;			
		end if;

	  if (write_ch2='1') then
			acc2_next <= acc_next;			
			decstep2_next <= decstep_next;			
		end if;

	   if (write_ch3='1') then
			acc3_next <= acc_next;			
			decstep3_next <= decstep_next;			
		end if;		
	end process;

	process(sel,syncreset_reg, syncreset, step_ready,
		acc0_reg, acc1_reg, acc2_reg, acc3_reg, 
		decstep0_reg, decstep1_reg, decstep2_reg, decstep3_reg
	)
		variable rst : std_logic;
	begin
		acc_mux <= (others=>'0');
		decstep_mux <= (others=>'0');

		syncreset_next <= (syncreset or syncreset_reg);
		
		rst := '0';

		case sel is
		when "00" =>
			acc_mux <= acc0_reg;
			decstep_mux <= decstep0_reg;
			rst := syncreset_reg(0) or syncreset(0);
			syncreset_next(0) <= (syncreset_reg(0) or syncreset(0)) and not(step_ready);
		when "01" =>
			acc_mux <= acc1_reg;
			decstep_mux <= decstep1_reg;
			rst := syncreset_reg(1) or syncreset(1);
			syncreset_next(1) <= (syncreset_reg(1) or syncreset(1)) and not(step_ready);
		when "10" =>
			acc_mux <= acc2_reg;
			decstep_mux <= decstep2_reg;
			rst := syncreset_reg(2) or syncreset(2);			
			syncreset_next(2) <= (syncreset_reg(2) or syncreset(2)) and not(step_ready);
		when "11" =>
			acc_mux <= acc3_reg;
			decstep_mux <= decstep3_reg;
			rst := syncreset_reg(3) or syncreset(3);
			syncreset_next(3) <= (syncreset_reg(3) or syncreset(3)) and not(step_ready);
		when others =>
		end case;
		
		if (rst='1') then
			acc_mux <= (others=>'0');
			decstep_mux <= (others=>'0');
		end if;
	end process;

	process(acc_mux,decstep_mux,
		code_reg, step_value)

		variable code : std_logic_vector(3 downto 0);
		variable codeadj : signed(8 downto 0);
		variable stepsize : signed(17 downto 0);
		variable vlue : signed(26 downto 0);
		variable vlue8 : signed(16 downto 0);
		variable decstepnext : signed(7 downto 0);
		variable acc_sum : signed(16 downto 0);
		variable oflow : boolean;
	begin
		acc_next <= acc_mux;
		decstep_next <= decstep_mux;
		
		codeadj:= (others=>'0');

		codeadj := resize(signed('0'&code_reg(2 downto 0)),8)&"1";
		
		stepsize := resize(signed('0'&step_value),18);

		vlue :=codeadj*stepsize;

		if (code_reg(3)='0') then
			vlue8 := vlue(19 downto 3);
		else
			vlue8 := -vlue(19 downto 3);
		end if;

		acc_sum := resize(acc_mux,17) + vlue8;
		oflow := acc_sum(16)/=acc_sum(15);
		if oflow then
                    if acc_sum(16) = '0' then
                    -- positive overflow
                        acc_next <= to_signed(32767, 16);
                    else
                    -- negative overflow
                        acc_next <= to_signed(-32768, 16);
                    end if;
                else
                    acc_next <= acc_sum(15 downto 0);
                end if;

		decstepnext := resize(stepadj_fn(code_reg(2 downto 0)),8) + signed(resize(decstep_mux,8));
		if (decstepnext>88) then
			decstepnext := to_signed(88,8);
		elsif (decstepnext<0) then
			decstepnext := to_signed(0,8);
		end if;
		decstep_next <= unsigned(decstepnext(6 downto 0));			
	end process;

	data_out <= std_logic_vector(acc_mux);

	select_channel <= sel;
	step_addr <= std_logic_vector(decstep_mux);
	
end vhdl;

