library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

entity VBXE is
generic ( 
	cycle_length : integer := 16;
	mem_config : integer := 0  -- 0 bram, 1 spram, 2 sdram
);
port (
	clk : in std_logic;
	enable : in std_logic;
	clk_enable : in std_logic; -- VBXE speed -> 8x CPU
	enable_179 : in std_logic; -- Original Atari speed (based on Antic enable, always active)
	reset_n : in std_logic;
	pal : in std_logic := '1';
	addr : in std_logic_vector(4 downto 0); -- 32 registers based at $D640/$D740
	data_in: in std_logic_vector(7 downto 0); -- for register write
	wr_en : in std_logic; -- reading or writing registers?
	data_out: out std_logic_vector(7 downto 0); -- for register read

	-- Interface to SDRAM interface handled by address_decoder
	-- Too slow for any practical use!
	sdram_data_in : in std_logic_vector(7 downto 0); -- read from 512K SDRAM block
	sdram_data_out : out std_logic_vector(7 downto 0); -- write to 512K SDRAM block
	sdram_wr_en : out std_logic;
	sdram_request : out std_logic;
	sdram_request_complete : in std_logic;
	sdram_addr : out std_logic_vector(18 downto 0); -- 512K address
	
	-- Palette look up interface
	palette_get_color : in std_logic_vector(7 downto 0);
	palette_get_index : in std_logic_vector(1 downto 0);
	r_out : out std_logic_vector(7 downto 0);
	g_out : out std_logic_vector(7 downto 0);
	b_out : out std_logic_vector(7 downto 0);

	-- MEMAC
	memac_address : in std_logic_vector(15 downto 0);
	memac_write_enable : in std_logic;
	memac_cpu_access : in std_logic;
	memac_antic_access : in std_logic;
	memac_check : out std_logic;
	memac_data_in : in std_logic_vector(7 downto 0);
	memac_data_out : out std_logic_vector(7 downto 0);
	memac_request : in std_logic;
	memac_request_complete : out std_logic

);
end VBXE;

architecture vhdl of VBXE is

-- Few things for testing
--signal blit_data_reg : std_logic_vector(7 downto 0);
--signal blit_data_next : std_logic_vector(7 downto 0);

--signal blit_counter_reg : std_logic_vector(7 downto 0);
--signal blit_counter_next : std_logic_vector(7 downto 0);
--signal blit_counter : std_logic_vector(7 downto 0);

--signal blit_data_read_reg : std_logic_vector(7 downto 0);
--signal blit_data_read_next : std_logic_vector(7 downto 0);
--signal blit_data_read : std_logic_vector(7 downto 0);

--signal blit_data_dir_reg : std_logic_vector(7 downto 0);
--signal blit_data_dir_next : std_logic_vector(7 downto 0);

-- Actual things needed by VBXE
signal vram_addr : std_logic_vector(18 downto 0);
signal vram_addr_reg : std_logic_vector(18 downto 0);
signal vram_addr_next : std_logic_vector(18 downto 0);
signal vram_request : std_logic;
signal vram_request_complete : std_logic;
signal vram_wr_en : std_logic;
signal vram_data_in : std_logic_vector(7 downto 0);
signal vram_data : std_logic_vector(7 downto 0);
signal vram_data_next : std_logic_vector(7 downto 0);
signal vram_data_reg : std_logic_vector(7 downto 0);

signal vram_request_reg : std_logic;
signal vram_request_next : std_logic;
signal vram_wr_en_temp : std_logic;

signal data_color0_r : std_logic_vector(6 downto 0);
signal index_color0_r : std_logic_vector(7 downto 0);
signal data_color1_r : std_logic_vector(6 downto 0);
signal index_color1_r : std_logic_vector(7 downto 0);
signal data_color2_r : std_logic_vector(6 downto 0);
signal index_color2_r : std_logic_vector(7 downto 0);
signal data_color3_r : std_logic_vector(6 downto 0);
signal index_color3_r : std_logic_vector(7 downto 0);

signal data_color0_g : std_logic_vector(6 downto 0);
signal index_color0_g : std_logic_vector(7 downto 0);
signal data_color1_g : std_logic_vector(6 downto 0);
signal index_color1_g : std_logic_vector(7 downto 0);
signal data_color2_g : std_logic_vector(6 downto 0);
signal index_color2_g : std_logic_vector(7 downto 0);
signal data_color3_g : std_logic_vector(6 downto 0);
signal index_color3_g : std_logic_vector(7 downto 0);

signal data_color0_b : std_logic_vector(6 downto 0);
signal index_color0_b : std_logic_vector(7 downto 0);
signal data_color1_b : std_logic_vector(6 downto 0);
signal index_color1_b : std_logic_vector(7 downto 0);
signal data_color2_b : std_logic_vector(6 downto 0);
signal index_color2_b : std_logic_vector(7 downto 0);
signal data_color3_b : std_logic_vector(6 downto 0);
signal index_color3_b : std_logic_vector(7 downto 0);
signal vbxe_pal : std_logic;

signal csel_reg : std_logic_vector(7 downto 0);
signal csel_next : std_logic_vector(7 downto 0);
signal psel_reg : std_logic_vector(7 downto 0);
signal psel_next : std_logic_vector(7 downto 0);
--signal csel_temp : std_logic_vector(7 downto 0);
--signal psel_temp : std_logic_vector(7 downto 0);
--signal cr_data : std_logic_vector(6 downto 0);
--signal cr_request : std_logic := '0';
--signal cg_data : std_logic_vector(6 downto 0);
--signal cg_request : std_logic := '0';
--signal cb_data : std_logic_vector(6 downto 0);
--signal cb_request : std_logic := '0';

signal cr_reg : std_logic_vector(6 downto 0);
signal cr_next : std_logic_vector(6 downto 0);
signal cr_request_reg : std_logic;
signal cr_request_next : std_logic;
signal cg_reg : std_logic_vector(6 downto 0);
signal cg_next : std_logic_vector(6 downto 0);
signal cg_request_reg : std_logic;
signal cg_request_next : std_logic;
signal cb_reg : std_logic_vector(6 downto 0);
signal cb_next : std_logic_vector(6 downto 0);
signal cb_request_reg : std_logic;
signal cb_request_next : std_logic;

signal memc_reg : std_logic_vector(7 downto 0);
signal memc_next : std_logic_vector(7 downto 0);
signal mems_reg : std_logic_vector(7 downto 0);
signal mems_next : std_logic_vector(7 downto 0);
signal memb_reg : std_logic_vector(7 downto 0);
signal memb_next : std_logic_vector(7 downto 0);

signal memc_window_address_start : std_logic_vector(15 downto 0);
signal memc_window_address_end : std_logic_vector(15 downto 0);
signal memac_check_a : std_logic;
signal memac_check_b : std_logic;
signal memac_check_next : std_logic_vector(1 downto 0);
signal memac_check_reg : std_logic_vector(1 downto 0);

signal dma_state_reg : std_logic_vector(3 downto 0);
signal dma_state_next : std_logic_vector(3 downto 0);
signal memac_request_complete_reg : std_logic;
signal memac_request_complete_next : std_logic;
signal memac_request_reg : std_logic_vector(1 downto 0);
signal memac_request_next : std_logic_vector(1 downto 0);
signal memac_data_reg : std_logic_vector(7 downto 0);
signal memac_data_next : std_logic_vector(7 downto 0);

signal vram_op_reg : std_logic_vector(1 downto 0);
signal vram_op_next : std_logic_vector(1 downto 0);

signal clock_shift_reg : std_logic_vector(cycle_length-1 downto 0);
signal clock_shift_next : std_logic_vector(cycle_length-1 downto 0);

begin

-- TODO VBXE switch, reg base, and PAL should be globally latched in on system reset
-- Do this in Atari800.sv
vbxe_pal <= pal;

memc_window_address_start <= memc_reg(7 downto 4) & x"000";
memc_window_address_end <=
	memc_reg(7 downto 4) & x"FFF" when memc_reg(1 downto 0) = "00" else
	x"1FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"0" else
	x"2FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"1" else
	x"3FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"2" else
	x"4FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"3" else
	x"5FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"4" else
	x"6FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"5" else
	x"7FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"6" else
	x"8FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"7" else
	x"9FFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"8" else
	x"AFFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"9" else
	x"BFFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"A" else
	x"CFFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"B" else
	x"DFFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"C" else
	x"EFFF" when memc_reg(1 downto 0) = "01" and memc_reg(7 downto 4) = x"D" else
	x"FFFF" when memc_reg(1 downto 0) = "01" else
	x"3FFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"0" else
	x"4FFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"1" else
	x"5FFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"2" else
	x"6FFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"3" else
	x"7FFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"4" else
	x"8FFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"5" else
	x"9FFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"6" else
	x"AFFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"7" else
	x"BFFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"8" else
	x"CFFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"9" else
	x"DFFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"A" else
	x"EFFF" when memc_reg(1 downto 0) = "10" and memc_reg(7 downto 4) = x"B" else
	x"FFFF" when memc_reg(1 downto 0) = "10" else
	x"7FFF" when memc_reg(1 downto 0) = "11" and memc_reg(7 downto 4) = x"0" else
	x"8FFF" when memc_reg(1 downto 0) = "11" and memc_reg(7 downto 4) = x"1" else
	x"9FFF" when memc_reg(1 downto 0) = "11" and memc_reg(7 downto 4) = x"2" else
	x"AFFF" when memc_reg(1 downto 0) = "11" and memc_reg(7 downto 4) = x"3" else
	x"BFFF" when memc_reg(1 downto 0) = "11" and memc_reg(7 downto 4) = x"4" else
	x"CFFF" when memc_reg(1 downto 0) = "11" and memc_reg(7 downto 4) = x"5" else
	x"DFFF" when memc_reg(1 downto 0) = "11" and memc_reg(7 downto 4) = x"6" else
	x"EFFF" when memc_reg(1 downto 0) = "11" and memc_reg(7 downto 4) = x"7" else
	x"FFFF";

index_color0_r <= palette_get_color;
index_color0_g <= palette_get_color;
index_color0_b <= palette_get_color;
index_color1_r <= palette_get_color;
index_color1_g <= palette_get_color;
index_color1_b <= palette_get_color;
index_color2_r <= palette_get_color;
index_color2_g <= palette_get_color;
index_color2_b <= palette_get_color;
index_color3_r <= palette_get_color;
index_color3_g <= palette_get_color;
index_color3_b <= palette_get_color;

r_out <=
	data_color0_r & '0' when palette_get_index = "00" else
	data_color1_r & '0' when palette_get_index = "01" else
	data_color2_r & '0' when palette_get_index = "10" else
	data_color3_r & '0' when palette_get_index = "11" else
	x"FF";
g_out <=
	data_color0_g & '0' when palette_get_index = "00" else
	data_color1_g & '0' when palette_get_index = "01" else
	data_color2_g & '0' when palette_get_index = "10" else
	data_color3_g & '0' when palette_get_index = "11" else
	x"FF";
b_out <=
	data_color0_b & '0' when palette_get_index = "00" else
	data_color1_b & '0' when palette_get_index = "01" else
	data_color2_b & '0' when palette_get_index = "10" else
	data_color3_b & '0' when palette_get_index = "11" else
	x"FF";

gen_sdram: if mem_config = 2 generate

sdram_addr <= vram_addr;
sdram_request <= vram_request;
sdram_wr_en <= vram_wr_en;
vram_request_complete <= sdram_request_complete;
vram_data_in <= sdram_data_in;
sdram_data_out <= vram_data_next;

end generate;

gen_nosdram: if mem_config < 2 generate

sdram_addr <= (others => '0');
sdram_data_out <= (others => '0');
sdram_wr_en <= '0';
sdram_request <= '0';

end generate;

gen_bram: if mem_config = 0 generate

vbxe_vram : entity work.internalromram
GENERIC MAP ( internal_ram => 262144 ) -- 524288
PORT MAP (
	clock   => clk,
	reset_n => reset_n,

	RAM_ADDR => '0' & vram_addr(17 downto 0), -- vram_addr(18 downto 0)
	RAM_WR_ENABLE => vram_wr_en,
	RAM_DATA_IN => vram_data,
	RAM_REQUEST_COMPLETE => vram_request_complete,
	RAM_REQUEST => vram_request,
	RAM_DATA => vram_data_in
);

end generate;

gen_spram: if mem_config = 1 generate

vbxe_vram: entity work.spram
generic map(addr_width => 18, data_width => 8)
port map
(
	clock => clk,
	address => vram_addr(17 downto 0),
	data => vram_data,
	wren => vram_wr_en_temp, 
	q => vram_data_in
);

vram_wr_en_temp <= vram_wr_en and vram_request;
vram_request_next <= vram_request and not(vram_wr_en);
vram_request_complete <= vram_wr_en_temp or vram_request_reg;

end generate;

vram_addr <= vram_addr_next;
vram_request <= vram_op_next(0);
vram_wr_en <= vram_op_next(1);
vram_data <= vram_data_next;

memac_check_a <= '1' when
	(unsigned(memac_address) >= unsigned(memc_window_address_start)) and
	(unsigned(memac_address) <= unsigned(memc_window_address_end)) and
	((mems_reg(7) and ((memc_reg(3) and memac_cpu_access) or (memc_reg(2) and memac_antic_access))) = '1')
	else '0';

memac_check_b <= 
	not(memac_address(15)) and memac_address(14) and ((memb_reg(7) and memac_cpu_access) or (memb_reg(6) and memac_antic_access));

memac_check <= memac_check_a or memac_check_b;

process(clock_shift_reg, memac_request_reg, memac_request, memac_write_enable, memac_check_reg, memac_check_a, memac_check_b)
begin
	memac_request_next <= memac_request_reg;
	memac_check_next <= memac_check_reg;
	if (memac_request ='1') then
		memac_request_next(0) <= '1';
	end if;
	if (memac_write_enable = '1') then
		memac_request_next(1) <= '1';
	end if;
	if (memac_check_a = '1') then
		memac_check_next(0) <= '1';
	end if;
	if (memac_check_b = '1') then
		memac_check_next(1) <= '1';
	end if;	
	if (clock_shift_reg(cycle_length-1) = '1') then
		memac_request_next <= "00";
		memac_check_next <= "00";
	end if;
end process;

memac_data_out <= memac_data_next;
memac_request_complete <= memac_request_complete_next;

colors0_r: entity work.dpram
generic map(9,7,"rtl/vbxe/colors_r.mif")
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => vbxe_pal & csel_next, -- color index
	data_a => cr_next, -- color value
	wren_a => cr_request_next and not(psel_next(1)) and not(psel_next(0)), 
	-- To read - get color values for display
	address_b => vbxe_pal & index_color0_r,
	q_b => data_color0_r
);

colors1_r: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cr_next, -- color value
	wren_a => cr_request_next and not(psel_next(1)) and psel_next(0), 
	-- To read - get color values for display
	address_b => index_color1_r,
	q_b => data_color1_r
);

colors2_r: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cr_next, -- color value
	wren_a => cr_request_next and psel_next(1) and not(psel_next(0)), 
	-- To read - get color values for display
	address_b => index_color2_r,
	q_b => data_color2_r
);

colors3_r: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cr_next, -- color value
	wren_a => cr_request_next and psel_next(1) and psel_next(0), 
	-- To read - get color values for display
	address_b => index_color3_r,
	q_b => data_color3_r
);

colors0_g: entity work.dpram
generic map(9,7,"rtl/vbxe/colors_g.mif")
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => vbxe_pal & csel_next, -- color index
	data_a => cg_next, -- color value
	wren_a => cg_request_next and not(psel_next(1)) and not(psel_next(0)), 
	-- To read - get color values for display
	address_b => vbxe_pal & index_color0_g,
	q_b => data_color0_g
);

colors1_g: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cg_next, -- color value
	wren_a => cg_request_next and not(psel_next(1)) and psel_next(0), 
	-- To read - get color values for display
	address_b => index_color1_g,
	q_b => data_color1_g
);

colors2_g: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cg_next, -- color value
	wren_a => cg_request_next and psel_next(1) and not(psel_next(0)), 
	-- To read - get color values for display
	address_b => index_color2_g,
	q_b => data_color2_g
);

colors3_g: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cg_next, -- color value
	wren_a => cg_request_next and psel_next(1) and psel_next(0), 
	-- To read - get color values for display
	address_b => index_color3_g,
	q_b => data_color3_g
);

colors0_b: entity work.dpram
generic map(9,7,"rtl/vbxe/colors_b.mif")
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => vbxe_pal & csel_next, -- color index
	data_a => cb_next, -- color value
	wren_a => cb_request_next and not(psel_next(1)) and not(psel_next(0)), 
	-- To read - get color values for display
	address_b => vbxe_pal & index_color0_b,
	q_b => data_color0_b
);

colors1_b: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cb_next, -- color value
	wren_a => cb_request_next and not(psel_next(1)) and psel_next(0), 
	-- To read - get color values for display
	address_b => index_color1_b,
	q_b => data_color1_b
);

colors2_b: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cb_next, -- color value
	wren_a => cb_request_next and psel_next(1) and not(psel_next(0)), 
	-- To read - get color values for display
	address_b => index_color2_b,
	q_b => data_color2_b
);

colors3_b: entity work.dpram
generic map(addr_width => 8, data_width => 7)
port map
(
	clock => clk,
	-- To write - palette updating through registers
	address_a => csel_next, -- color index
	data_a => cb_next, -- color value
	wren_a => cb_request_next and psel_next(1) and psel_next(0), 
	-- To read - get color values for display
	address_b => index_color3_b,
	q_b => data_color3_b
);

-- write registers
process(addr, wr_en, data_in, csel_reg, psel_reg, cr_reg, cg_reg, cb_reg, cr_request_reg, cg_request_reg, cb_request_reg, memc_reg, mems_reg, memb_reg)
begin
		--blit_data_next <= blit_data_reg;
		--blit_data_dir_next <= blit_data_dir_reg;
		csel_next <= csel_reg;
		psel_next <= psel_reg;
		cr_request_next <= '0';
		cg_request_next <= '0';
		cb_request_next <= '0';
		cr_next <= cr_reg;
		cg_next <= cg_reg;
		cb_next <= cb_reg;
		memc_next <= memc_reg;
		mems_next <= mems_reg;
		memb_next <= memb_reg;
		if wr_en = '1' then
			case addr is
				-- For testing
				--when "00010" =>
				--	blit_data_dir_next <= data_in;
				-- For testing
				--when "00011" =>
				--	blit_data_next <= data_in;
				-- Palette registers
				when "00100" => -- $44 csel
					csel_next <= data_in;
				when "00101" => -- $45 psel
					psel_next <= data_in;
				when "00110" => -- $46 cr
					cr_next <= data_in(7 downto 1);
					cr_request_next <= '1';
				when "00111" => -- $47 cg
					cg_next <= data_in(7 downto 1);
					cg_request_next <= '1';
				when "01000" => -- $48 cb
					cb_next <= data_in(7 downto 1);
					cb_request_next <= '1';
				-- MEMAC registers
				when "11101" => -- $5D memac_b_control
					memb_next <= data_in;
				when "11110" => -- $5E memac_control
					memc_next <= data_in;
				when "11111" => -- $5F memac_banksel
					mems_next <= data_in;
				when others =>
					null;
			end case;
		end if;
		if cb_request_reg = '1' then -- TODO cb_request_next? Propably, but then not csel_reg!
			csel_next <= std_logic_vector(unsigned(csel_reg) + 1);
		end if;
end process;

-- Read registers
process(addr, memc_reg, mems_reg)
begin
	case addr is
		when "00000" => -- $40 core version -> FX
			data_out <= X"10";
		when "00001" => -- $41 minor version
			data_out <= X"26";
		--when "00010" => -- 
		--	data_out <= blit_counter_reg;
		--when "00011" => -- 
		--	data_out <= blit_data_read_reg;
		--when "00100" => -- read csel
		--	data_out <= csel_reg;
		--when "00101" => -- read psel
		--	data_out <= psel_reg;
		-- MEMAC A registers are readable
		when "11110" => -- $5E memac_control
			data_out <= memc_reg;
		when "11111" => -- $5F memac_banksel
			data_out <= mems_reg;
		when others =>
			data_out <= X"FF";
	end case;
end process;

process(clk,reset_n)
begin
	if reset_n = '0' then
		vram_request_reg <= '0';
		csel_reg <= (others => 'U');
		psel_reg <= (others => 'U');
		cr_reg <= (others => 'U');
		cg_reg <= (others => 'U');
		cb_reg <= (others => 'U');
		cr_request_reg <= '0';
		cg_request_reg <= '0';
		cb_request_reg <= '0';
		memc_reg <= "UUUU00UU";
		mems_reg <= "0UUUUUUU";
		memb_reg <= "00UUUUUU";
		dma_state_reg <= "1111";
		memac_request_complete_reg <= '0';
		memac_request_reg <= "00";
		vram_op_reg <= "00";
		vram_data_reg <= (others => '0');
		vram_addr_reg <= (others => '0');
		memac_check_reg <= "00";
		clock_shift_reg <= (others => '0');
		memac_data_reg <= (others => '0');
	elsif rising_edge(clk) then
		vram_request_reg <= vram_request_next;
		csel_reg <= csel_next;
		psel_reg <= psel_next;
		cr_reg <= cr_next;
		cg_reg <= cg_next;
		cb_reg <= cb_next;
		cr_request_reg <= cr_request_next;
		cg_request_reg <= cg_request_next;
		cb_request_reg <= cb_request_next;
		memc_reg <= memc_next;
		mems_reg <= mems_next;
		memb_reg <= memb_next;
		dma_state_reg <= dma_state_next;
		memac_request_complete_reg <= memac_request_complete_next;
		memac_request_reg <= memac_request_next;
		vram_op_reg <= vram_op_next;
		vram_data_reg <= vram_data_next;
		vram_addr_reg <= vram_addr_next;
		memac_check_reg <= memac_check_next;
		clock_shift_reg <= clock_shift_next;
		memac_data_reg <= memac_data_next;
	end if;
end process;

-- VBXE DMA state machine
process
--(clk, reset_n)
(clock_shift_reg,
dma_state_reg, memac_request_complete_reg, vram_op_reg, vram_data_reg, vram_addr_reg, 
memac_data_reg,
memac_data_in,
memac_request_next, memac_check_next,
memc_reg, memc_window_address_start,
memb_reg,
vram_data_in,
vram_request_complete,
memac_address
)
begin
	dma_state_next <= dma_state_reg;
	memac_request_complete_next <= memac_request_complete_reg;
	vram_op_next <= vram_op_reg;
	vram_data_next <= vram_data_reg;
	vram_addr_next <= vram_addr_reg;
	memac_data_next <= memac_data_reg;

	case dma_state_reg(2 downto 0) is 
	when "000" =>
		dma_state_next <= "0001";
	when "001" =>
		if (memac_request_next = "01") then
			vram_op_next <= "01";
			if memac_check_next(0) = '1' then
				-- TODO This can be done slightly shorter
				case memc_reg(1 downto 0) is
				when "00" =>
					vram_addr_next <= mems_reg(6 downto 0) & std_logic_vector(unsigned(memac_address) - unsigned(memc_window_address_start))(11 downto 0);
				when "01" =>
					vram_addr_next <= mems_reg(6 downto 1) & std_logic_vector(unsigned(memac_address) - unsigned(memc_window_address_start))(12 downto 0);
				when "10" =>
					vram_addr_next <= mems_reg(6 downto 2) & std_logic_vector(unsigned(memac_address) - unsigned(memc_window_address_start))(13 downto 0);
				when "11" =>
					vram_addr_next <= mems_reg(6 downto 3) & std_logic_vector(unsigned(memac_address) - unsigned(memc_window_address_start))(14 downto 0);
				end case;
			else -- memac_check_b = '1'
				vram_addr_next <= memb_reg(4 downto 0) & memac_address(13 downto 0);
			end if;
			if vram_request_complete = '1' then -- TODO won't ever happen for reading? Or?
				memac_data_next <= vram_data_in;
				memac_request_complete_next <= '1';
				dma_state_next(3) <= '0';
			else
				dma_state_next(3) <= '1';
			end if;
		else 
			dma_state_next(3) <= '0';
		end if;
		dma_state_next(2 downto 0) <= "010";
	when "010" =>
		if dma_state_reg(3) = '1' then
			if (vram_request_complete = '1') then
				memac_data_next <= vram_data_in;
				memac_request_complete_next <= '1';
				dma_state_next <= "0011";
			end if;
		else
			dma_state_next <= "0011";
		end if;
	when "011" =>
		if (memac_request_next = "11") then
			vram_op_next <= "11";
			vram_data_next <= memac_data_in;
			if memac_check_next(0) = '1' then
				case memc_reg(1 downto 0) is
				when "00" =>
					vram_addr_next <= mems_reg(6 downto 0) & std_logic_vector(unsigned(memac_address) - unsigned(memc_window_address_start))(11 downto 0);
				when "01" =>
					vram_addr_next <= mems_reg(6 downto 1) & std_logic_vector(unsigned(memac_address) - unsigned(memc_window_address_start))(12 downto 0);
				when "10" =>
					vram_addr_next <= mems_reg(6 downto 2) & std_logic_vector(unsigned(memac_address) - unsigned(memc_window_address_start))(13 downto 0);
				when "11" =>
					vram_addr_next <= mems_reg(6 downto 3) & std_logic_vector(unsigned(memac_address) - unsigned(memc_window_address_start))(14 downto 0);
				end case;
			else -- memac_check_b = '1'
				vram_addr_next <= memb_reg(4 downto 0) & memac_address(13 downto 0);
			end if;
			if vram_request_complete = '1' then
				memac_request_complete_next <= '1';
				dma_state_next(3) <= '0';
			else
				dma_state_next(3) <= '1';
			end if;
		else 
			dma_state_next(3) <= '0';
		end if;
		dma_state_next(2 downto 0) <= "100";
	when "100" =>
		if dma_state_reg(3) = '1' then
			if (vram_request_complete = '1') then
				memac_request_complete_next <= '1';
				dma_state_next <= "1111";
			end if;
		else
			dma_state_next <= "1111";
		end if;
	when others =>
		vram_op_next <= "00";
		-- dma_state_next <= "0000";
	end case;
	if clock_shift_reg(cycle_length-1) = '1' then
		memac_request_complete_next <= '0';
		dma_state_next <= "0000";
	end if;
end process;

process(enable_179, clock_shift_reg)
begin
	clock_shift_next(cycle_length-1 downto 0) <= clock_shift_reg(cycle_length-2 downto 0) & '0';

	if (enable_179 = '1') then
		clock_shift_next(cycle_length-1 downto 1) <= (others=>'0');
		clock_shift_next(0) <= '1';
	end if;
end process;

end vhdl;