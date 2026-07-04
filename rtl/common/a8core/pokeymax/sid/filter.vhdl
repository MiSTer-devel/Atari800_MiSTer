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
use ieee.math_real.all;

-- Fixed point implementation of a variable state filter
-- A handy filter 3 op amps that can do low pass, band pass and high pass at once
-- SID used this, but had ... some shortcuts that made it rather imperfect
-- This implementation is correct (I hope!), but will need some tweaks to replicate the broken
-- sound of the 6581

-- Example F computation for completely linear filter response:
-- i.e. 0.21 fixed point (We have 18 lowest bits of that)
--
--	CLKSPEED : IN integer; --In Hz 58333333
--	FMIN : IN integer;   --In Hz (30)
--	FMAX : IN integer   --In Hz (12500 on 8580)
--	process(CUTOFF_FREQUENCY)
--		constant f_min : real := 2.0*sin(MATH_PI*real(FMIN)/real(CLKSPEED));
--		constant f_max : real := 2.0*sin(MATH_PI*real(FMAX)/real(CLKSPEED));
--
--		variable f_offset : unsigned(17 downto 0); --0.21(000,18)
--		variable f_scale : unsigned(17 downto 0); --0.21(000,18)
--
--		variable F_MULT : UNSIGNED(35 DOWNTO 0);
--	begin
--		--f = 2*sin(pi*10000/inrate);
--		--CUTOFF_FREQUENCY : IN STD_LOGIC_VECTOR(10 downto 0);
--		--CLKSPEED : IN integer; --In Hz
--		--FMIN : IN integer;   --In Hz
--		--FMAX : IN integer;   --In Hz
--
--		f_offset := to_unsigned(integer(f_min*2.0**21.0),18);
--		f_scale  := to_unsigned(integer(2.0**21.0*((f_max-f_min)/2.0**11.0)),18);
--
--		-- TODO: Could use a real curve captured from a chip? Lets start with it correctly then...
--		f_mult := f_scale * resize(unsigned(CUTOFF_FREQUENCY),18);
--	       	f_next <= f_mult(17 downto 0) + f_offset;
--	end process;

ENTITY SID_filter IS
PORT 
( 
	CLK : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;

	SIDTYPE : IN STD_LOGIC;
	INPUT : IN SIGNED(15 downto 0);

	LOWPASS : OUT SIGNED(17 downto 0);
	BANDPASS : OUT SIGNED(17 downto 0);
	HIGHPASS : OUT SIGNED(17 downto 0);

	F_BP : IN UNSIGNED(12 downto 0);
	F_HP : IN UNSIGNED(12 downto 0);
	Q : IN SIGNED(17 downto 0)
);
END SID_filter;

-- matlab pseudocode...
--  f = 2*sin(pi*fCutoff/clkrate);
--
--  Q = 0.707;    % 0.5 to infinity
--    q = 1.0 / Q;
--    sum3 = 0;
--    sum2 = 0;
--    for i=1:numel(indata)
--      input = indata(i);
--
--      multq = sum2 * q;
--
--      sum1 = input + (-multq) + (-sum3);
--
--      mult1 = f * sum1;
--      sum2 = mult1 + sum2;
--
--      mult2 = f * sum2;
--      sum3 = mult2 + sum3;
--
--      res(ceil(i*outrate/inrate)) = sum3;
--    end

--
-- 6581
--    sum1: Vhp = (Vbp * _1_div_Q - Vlp - Vi) * attenuation; //at=0.5
--    sum2: Vbp -= Vhp * type3_w0(Vhp);
--    sum3: Vlp -= Vbp * type3_w0(Vbp);
--
--    Subst Vbn = -Vbp
--    sum1: Vhp = (-Vbn * _1_div_Q - Vlp - Vi) * attenuation; //at=0.5
--    sum2: Vbn += Vhp * type3_w0(Vhp);
--    sum3: Vlp += Vbn * type3_w0(Vbp);
--    So invert bp on output and attentuate internally
-- 
-- 8580
--    sum1: Vhp = -Vbp * _1_div_Q - Vlp - Vi;
--    sum2: Vbp += Vhp * type4_w0_cache;
--    sum3: Vlp += Vbp * type4_w0_cache;
--
-- changes:
-- sum1: ALL:input -> -input 
-- sum1: 6581: +multq
-- sum1: 6581: /2
-- sum2: 6581: -hp
-- sum3: 6581: -bp

-- as fixed point
--    sum1 = int64(0);
--    sum2 = int64(0);
--    sum3 = int64(0);
--    q = 1.0 / Q;
--    q = int64(round(q*65536));%2.16u
--    indata = indata/2; %rescale to -0.5 to 0.5
--    indata2 = int64(round(indata*2^24));
--    f = int64(round(f*2^21)); %0.21u
--    for i=1:numel(indata2)
--      input = indata2(i);%18.24
--
--      multq = (sum2/2^6) * q; %18.24s * 2.16u
--      %multq: 20.34s
--      %multq->18.24s
--      multq = multq/(2^10);
--      sum1 = input + (-multq) + (-sum3); %all 18.24s
--      mult1 = f * sum1/(2^6); %0.21u * 18.18s
--      %mult1: 15.39s
--      %mult1->18.24s
--      mult1 = mult1/(2^15);
--      sum2 = mult1 + sum2; %all 18.24s
--      mult2 = f * (sum2/2^6); %0.21u * 18.18s
--      %mult2: 15.39s
--      %mult2->18.24s
--      mult2 = mult2/(2^15);
--      sum3 = mult2 + sum3; %all 18.24s
--
--      res(ceil(i*outrate/inrate)) = sum3/(2^6);
--    end
--    res = res/2^18;
--    res = res*2;

ARCHITECTURE vhdl OF SID_filter IS
	signal multq_reg : signed(53 downto 0);
	signal multq_next : signed(53 downto 0);

	signal mult1_reg : signed(53 downto 0);
	signal mult1_next : signed(53 downto 0);

	signal mult2_reg : signed(53 downto 0);
	signal mult2_next : signed(53 downto 0);

	signal highpass_reg : signed(41 downto 0);
	signal bandpass_reg : signed(41 downto 0);
	signal lowpass_reg : signed(41 downto 0);
	signal highpass_next : signed(41 downto 0);
	signal bandpass_next : signed(41 downto 0);
	signal lowpass_next : signed(41 downto 0);

BEGIN
	-- register
	process(clk, reset_n)
	begin
		if (reset_n = '0') then
			multq_reg <= (others=>'0');
			mult1_reg <= (others=>'0');
			mult2_reg <= (others=>'0');
			highpass_reg <= (others=>'0');
			bandpass_reg <= (others=>'0');
			lowpass_reg <= (others=>'0');
		elsif (clk'event and clk='1') then
			multq_reg <= multq_next;
			mult1_reg <= mult1_next;
			mult2_reg <= mult2_next;
			highpass_reg <= highpass_next;
			bandpass_reg <= bandpass_next;
			lowpass_reg <= lowpass_next;
		end if;
	end process;

	-- next state
	process(input,q,f_bp,f_hp,multq_reg,mult1_reg,mult2_reg,highpass_reg,bandpass_reg,lowpass_reg,sidtype)
		variable multq : signed(41 downto 0);
		variable mult1 : signed(41 downto 0);
		variable mult2 : signed(41 downto 0);
		variable inputadj : signed(41 downto 0);

		variable multqtmp : signed(53 downto 0);
		variable mult1tmp : signed(54 downto 0);
		variable mult2tmp : signed(54 downto 0);

		variable highpass_tmp : signed(41 downto 0);
	begin
		multqtmp := bandpass_reg(41 downto 6) * q; --18.18s * 3.15u
		multq_next <= multqtmp(53 downto 0);
		--multq: 21.33s
		--multq->18.24s
		multq := multq_reg(50 downto 9);
		inputadj(23 downto 0) := (others=>'0');
		inputadj(41 downto 24) := resize(input,18);

		highpass_tmp := -(inputadj + lowpass_reg + multq);
		if (sidtype='0') then
			highpass_next <= highpass_tmp; --all 18.24s
		else -- attenuate hp for 6581
			highpass_next <= shift_right(highpass_tmp,1); --all 18.24s
		end if;

		mult1tmp := signed('0'&resize(f_hp,18)) * highpass_reg(41 downto 6); --0.21u * 18.18s
		mult1_next <= mult1tmp(53 downto 0);
		--mult1: 15.39s
		--mult1->18.24s
		mult1 := resize(mult1_reg(51 downto 15),42);
		bandpass_next <= mult1 + bandpass_reg; --all 18.24s

		mult2tmp := signed('0'&resize(f_bp,18)) * bandpass_reg(41 downto 6); -- 0.21u * 18.18s
		mult2_next <= mult2tmp(53 downto 0);
		--mult2: 15.39s
		--mult2->18.24s
		mult2 := resize(mult2_reg(51 downto 15),42);
		lowpass_next <= mult2 + lowpass_reg; --all 18.24s	
	end process;	

	--output
	lowpass <= lowpass_reg(41 downto 24);
	bandpass <= bandpass_reg(41 downto 24) when sidtype='0' else -bandpass_reg(41 downto 24); -- invert bp for 6581
	highpass <= highpass_reg(41 downto 24);
		
END vhdl;
