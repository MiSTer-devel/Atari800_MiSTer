---------------------------------------------------------------------------
-- (c) 2020 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

-- Generic unsigned-input to signed-output DC blocker.
-- AUDIO_IN is treated as offset-binary unsigned audio:
--   0                 -> most negative signed value
--   2**(BITS-1)       -> zero
--   2**BITS - 1       -> most positive signed value
--
-- Filter:
--   y  = x - dc_old
--   dc = dc_old + (y / 2**K)
--
-- AUDIO_OUT is registered and saturated to BITS bits.
ENTITY dc_blocker_pm IS
GENERIC
(
	BITS       : positive := 16;
	EXTRA_BITS : positive := 4;
	K          : natural  := 10
);
PORT
(
	CLK          : IN  std_logic;
	RESET_N      : IN  std_logic;
	ENABLE_CYCLE : IN  std_logic;

	AUDIO_IN    : IN  unsigned(BITS-1 downto 0);
	AUDIO_OUT   : OUT signed(BITS-1 downto 0)
);
END dc_blocker_pm;

ARCHITECTURE vhdl OF dc_blocker_pm IS
	constant ACC_WIDTH : positive := BITS + EXTRA_BITS;

	subtype acc_t is signed(ACC_WIDTH-1 downto 0);

	function midpoint return acc_t is
		variable r : acc_t := (others => '0');
	begin
		r(BITS-1) := '1';
		return r;
	end function;

	function saturate_to_bits(v : acc_t) return signed is
		variable r        : signed(BITS-1 downto 0);
		variable overflow : boolean := false;
		variable max_val  : signed(BITS-1 downto 0) := (others => '1');
		variable min_val  : signed(BITS-1 downto 0) := (others => '0');
	begin
		max_val(BITS-1) := '0';
		min_val(BITS-1) := '1';

		-- A value fits into BITS signed bits when all bits above BITS-1
		-- match the sign bit that will remain after truncation.
		for i in BITS to ACC_WIDTH-1 loop
			if v(i) /= v(BITS-1) then
				overflow := true;
			end if;
		end loop;

		if overflow then
			if v(ACC_WIDTH-1) = '0' then
				r := max_val;
			else
				r := min_val;
			end if;
		else
			r := v(BITS-1 downto 0);
		end if;

		return r;
	end function;

	constant MIDPOINT_VALUE : acc_t := midpoint;

	signal dc_reg          : acc_t;
	signal dc_next         : acc_t;
	signal audio_out_reg  : signed(BITS-1 downto 0);
	signal audio_out_next : signed(BITS-1 downto 0);
BEGIN
	process(AUDIO_IN, ENABLE_CYCLE, dc_reg)
		variable x_ext : acc_t;
		variable err   : acc_t;
		variable adj   : acc_t;
	begin
		x_ext := signed(resize(AUDIO_IN, ACC_WIDTH)) - MIDPOINT_VALUE;
		err   := x_ext - dc_reg;
		adj   := shift_right(err, K);

		dc_next         <= dc_reg;
		audio_out_next <= saturate_to_bits(err);

		if ENABLE_CYCLE = '1' then
			dc_next <= dc_reg + adj;
		end if;
	end process;

	process(CLK, RESET_N)
	begin
		if RESET_N = '0' then
			dc_reg         <= (others => '0');
			audio_out_reg <= (others => '0');
		elsif CLK'event and CLK = '1' then
			dc_reg         <= dc_next;
			audio_out_reg <= audio_out_next;
		end if;
	end process;

	AUDIO_OUT <= audio_out_reg;
END vhdl;
