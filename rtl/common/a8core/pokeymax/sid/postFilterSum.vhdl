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

ENTITY SID_postFilterSum IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	
	DIRECT : IN SIGNED(15 downto 0);
	FILTER_LP : IN SIGNED(17 downto 0);
	FILTER_BP : IN SIGNED(17 downto 0);
	FILTER_HP : IN SIGNED(17 downto 0);
	FILTER_SEL : IN STD_LOGIC_VECTOR(2 downto 0);

	VOLUME : IN STD_LOGIC_VECTOR(3 downto 0);

	CHANNEL_OUT : OUT SIGNED(15 downto 0)
);
END SID_postFilterSum;

ARCHITECTURE vhdl OF SID_postFilterSum IS
	signal out_reg: signed(15 downto 0);
	signal out_next: signed(15 downto 0);	
	
	function saturate(input : signed(17 downto 0)) return signed is
   		 variable ret : signed(15 downto 0);
	begin
		if (input(15) = input(16) and input(15) = input(17)) then
			ret := input(15 downto 0);
		else
			ret(15) := input(17);
			ret(14 downto 0) := (others=>not(input(17)));
		end if;
			
		return ret;
	end function saturate;		
BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			out_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			out_reg <= out_next;
		end if;
	end process;
	
	-- next state
	process(direct,filter_lp,filter_bp,filter_hp,filter_sel,volume)
		variable sum : signed(17 downto 0);
		variable post_volume : unsigned(35 downto 0);

		variable filter_sel0ext : signed(17 downto 0);
		variable filter_sel1ext : signed(17 downto 0);
		variable filter_sel2ext : signed(17 downto 0);

		variable volume_adj : signed(7 downto 0);

		variable mult_res : signed(26 downto 0);
		variable mult_res_saturated : signed(21 downto 6);
	begin
		filter_sel0ext := (others=>filter_sel(0));
		filter_sel1ext := (others=>filter_sel(1));
		filter_sel2ext := (others=>filter_sel(2));

		sum := 
			   resize(filter_lp and filter_sel0ext,18) +
			   resize(filter_bp and filter_sel1ext,18) +
			   resize(filter_hp and filter_sel2ext,18) +
			   resize(direct,18);

		--sum(filter_lp+filter+bp+filter_hp) -> up to 75%
		--direct -> up to 75%
	        -- not both at once, therefore should scale by 1.333
		volume_adj:= signed("00"&volume&"00") + signed("0000"&volume);

		-- Then apply volume
		mult_res := sum * resize(volume_adj,9);
		mult_res_saturated := saturate(mult_res(23 downto 6));
		out_next <= mult_res_saturated(21 downto 6);
	end process;	

	-- output
	channel_out <= out_reg;
		
END vhdl;
