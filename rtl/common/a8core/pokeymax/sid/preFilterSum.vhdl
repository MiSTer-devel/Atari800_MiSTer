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

ENTITY SID_preFilterSum IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	ENABLE : IN STD_LOGIC;

	BIAS_CHANNEL : IN STD_LOGIC;
	
	CHANNEL_MUX : IN SIGNED(15 downto 0);
	CHANNEL_C_CUTDIRECT : IN STD_LOGIC;
	FILTER_EN : IN STD_LOGIC_VECTOR(3 downto 0);

	CHANNEL_MUX_SEL : OUT STD_LOGIC_VECTOR(2 downto 0);
	PREFILTER_OUT : OUT SIGNED(15 downto 0); 
	DIRECT_OUT : OUT SIGNED(15 downto 0)     -- Only chdis/4 amplitude
);
END SID_preFilterSum;

ARCHITECTURE vhdl OF SID_preFilterSum IS
	signal prefilter_reg: signed(15 downto 0);
	signal prefilter_next: signed(15 downto 0);
	signal direct_reg: signed(15 downto 0);
	signal direct_next: signed(15 downto 0);
	signal acc_reg: signed(17 downto 0);
	signal acc_next: signed(17 downto 0);	
	signal phase_reg : unsigned(2 downto 0);
	signal phase_next : unsigned(2 downto 0);
	
	signal channel_sel : std_logic_vector(2 downto 0);

	function logic_to_unsigned(a : std_logic; b : integer) return unsigned is
   		 variable ret : unsigned(3 downto 0);
	begin
		ret(3 downto 0) := (others=>'0');
		ret(b) := a;
	    return ret;
	end function logic_to_unsigned;
BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			prefilter_reg <= (others=>'0');
			direct_reg <= (others=>'0');
			acc_reg <= (others=>'0');
			phase_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			prefilter_reg <= prefilter_next;
			direct_reg <= direct_next;
			acc_reg <= acc_next;
			phase_reg <= phase_next;
		end if;
	end process;
	
	-- next state
	process(phase_reg,acc_reg,prefilter_reg,direct_reg,enable,channel_c_cutdirect,filter_en,channel_mux,bias_channel)
		variable filter_en0_ext : std_logic_vector(2 downto 0);
		variable filter_en1_ext : std_logic_vector(2 downto 0);
		variable filter_en2_ext : std_logic_vector(2 downto 0);
		variable filter_en2cd_ext : std_logic_vector(2 downto 0);
		variable filter_en3_ext : std_logic_vector(2 downto 0);
		
		variable adder_result : signed(17 downto 0);

		variable bias : unsigned(3 downto 0);
	begin
		prefilter_next <= prefilter_reg;
		direct_next <= direct_reg;
		acc_next <= acc_reg;
		phase_next <= phase_reg;
				
		filter_en0_ext := (others=>filter_en(0));
		filter_en1_ext := (others=>filter_en(1));
		filter_en2_ext := (others=>filter_en(2));
		filter_en2cd_ext := (others=>filter_en(2) or channel_c_cutdirect);		
		filter_en3_ext := (others=>filter_en(3));
		
		channel_sel <= (others=>'0');
		
		phase_next <= phase_reg+1;
		
		adder_result := acc_reg + resize(channel_mux,18);	
		acc_next <= adder_result;	
		
		case phase_reg is
		when "000" =>
			channel_sel <= "001" and filter_en0_ext;
		when "001" =>
			channel_sel <= "010" and filter_en1_ext;
		when "010" =>
			channel_sel <= "011" and filter_en2_ext;		
		when "011" =>
			channel_sel <= "100" and filter_en3_ext;		
			prefilter_next	<= adder_result(17 downto 2);
			acc_next <= (others=>'0'); --base for direct
			bias:=
				logic_to_unsigned(not(filter_en(0)) and bias_channel,0) + 
				logic_to_unsigned(not(filter_en(1)) and bias_channel,0) +
				logic_to_unsigned(not(filter_en2cd_ext(0)) and bias_channel,0);
			acc_next(16 downto 13) <= signed(std_logic_vector(bias));
		when "100" =>
			channel_sel <= "001" and not(filter_en0_ext);
		when "101" =>
			channel_sel <= "010" and not(filter_en1_ext);
		when "110" =>
			channel_sel <= "011" and not(filter_en2cd_ext);
		when "111" =>
			channel_sel <= "100" and not(filter_en3_ext);
			phase_next <= (others=>'0');
			direct_next <= adder_result(17 downto 2);
			acc_next <= (others=>'0'); --base for filter
			bias:=
				logic_to_unsigned(filter_en(0) and bias_channel,0) + 
				logic_to_unsigned(filter_en(1) and bias_channel,0) +
				logic_to_unsigned(filter_en(2) and bias_channel,0);
			acc_next(16 downto 13) <= signed(std_logic_vector(bias));
		when others =>
		end case;		
		
	end process;	
		
	-- output
	CHANNEL_MUX_SEL <= channel_sel;
	prefilter_out <= prefilter_reg;
	direct_out <= direct_reg;
		
END vhdl;
