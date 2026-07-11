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

ENTITY SID_f_distortion_mux IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

	state1 : in SIGNED(17 downto 8);
	state2 : in SIGNED(17 downto 8);
	state3 : in SIGNED(17 downto 8);
	state4 : in SIGNED(17 downto 8);
	SIDTYPE12 : in std_logic;
	SIDTYPE34 : in std_logic;
	f_raw12 : in UNSIGNED(12 downto 0);
	f_raw34 : in UNSIGNED(12 downto 0);
	f_distorted1 : out unsigned(12 downto 0);
	f_distorted2 : out unsigned(12 downto 0);
	f_distorted3 : out unsigned(12 downto 0);
	f_distorted4 : out unsigned(12 downto 0)
);
END SID_f_distortion_mux;

ARCHITECTURE vhdl OF SID_f_distortion_mux IS
	signal FILTER_STATE : signed(17 downto 8);
	signal F : unsigned(12 downto 0);
	signal F_DISTORTED : unsigned(12 downto 0);

	signal F_DISTORTED1_NEXT : unsigned(12 downto 0);
	signal F_DISTORTED2_NEXT : unsigned(12 downto 0);
	signal F_DISTORTED3_NEXT : unsigned(12 downto 0);
	signal F_DISTORTED4_NEXT : unsigned(12 downto 0);
	signal F_DISTORTED1_REG : unsigned(12 downto 0);
	signal F_DISTORTED2_REG : unsigned(12 downto 0);
	signal F_DISTORTED3_REG : unsigned(12 downto 0);
	signal F_DISTORTED4_REG : unsigned(12 downto 0);

	signal state_next : std_logic_vector(1 downto 0);
	signal state_reg : std_logic_vector(1 downto 0);
begin
	f_distortion : entity work.SID_f_distortion
	port map
	(
		clk=>clk,
		reset_n=>reset_n,
		state=>FILTER_STATE(17 downto 8),
		f_raw=>F,
		f_distorted=>F_DISTORTED
	);

	process(clk,reset_n)
	begin
		if (reset_n='0') then
			state_reg <= (others=>'0');
			F_DISTORTED1_REG <= (others=>'0');
			F_DISTORTED2_REG <= (others=>'0');
			F_DISTORTED3_REG <= (others=>'0');
			F_DISTORTED4_REG <= (others=>'0');
		elsif (clk'event and clk='1') then
			state_reg <= state_next;
			F_DISTORTED1_REG <= F_DISTORTED1_NEXT;
			F_DISTORTED2_REG <= F_DISTORTED2_NEXT;
			F_DISTORTED3_REG <= F_DISTORTED3_NEXT;
			F_DISTORTED4_REG <= F_DISTORTED4_NEXT;
		end if;
	end process;

	process(
		state_reg,
		sidtype12,sidtype34,
		state1,state2,state3,state4,
		f_raw12,f_raw34,
		F_DISTORTED,
		F_DISTORTED1_REG,
		F_DISTORTED2_REG,
		F_DISTORTED3_REG,
		F_DISTORTED4_REG)
	begin
		state_next <= state_reg;
		F_DISTORTED1_NEXT <= F_DISTORTED1_REG;
		F_DISTORTED2_NEXT <= F_DISTORTED2_REG;
		F_DISTORTED3_NEXT <= F_DISTORTED3_REG;
		F_DISTORTED4_NEXT <= F_DISTORTED4_REG;

		F <= (others=>'0');
		FILTER_STATE <= (others=>'0');

		case state_reg is
		when "00"=>
			F <= f_raw12;
			FILTER_STATE <= state1;
			if (sidtype34 = '0') then
				F_DISTORTED4_NEXT <= F_RAW34;
			else
				F_DISTORTED4_NEXT <= F_DISTORTED;
			end if;
			state_next <= "01";
		when "01" =>
			F <= f_raw12;
			FILTER_STATE <= state2;
			if (sidtype12 = '0') then
				F_DISTORTED1_NEXT <= F_RAW12;
			else
				F_DISTORTED1_NEXT <= F_DISTORTED;
			end if;
			state_next <= "10";
		when "10" =>
			F <= f_raw34;
			FILTER_STATE <= state3;
			if (sidtype12 = '0') then
				F_DISTORTED2_NEXT <= F_RAW12;
			else
				F_DISTORTED2_NEXT <= F_DISTORTED;
			end if;
			state_next <= "11";
		when "11" =>
			F <= f_raw34;
			FILTER_STATE <= state4;
			if (sidtype34 = '0') then
				F_DISTORTED3_NEXT <= F_RAW34;
			else
				F_DISTORTED3_NEXT <= F_DISTORTED;
			end if;
			state_next <= "00";
		when others=>
			state_next <= "00";
		end case;
	end process;

	F_DISTORTED1 <= F_DISTORTED1_REG;
	F_DISTORTED2 <= F_DISTORTED2_REG;
	F_DISTORTED3 <= F_DISTORTED3_REG;
	F_DISTORTED4 <= F_DISTORTED4_REG;

end vhdl;


