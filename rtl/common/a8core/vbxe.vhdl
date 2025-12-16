--------------------------------------------------------------------------
-- (c) 2025 Wojciech Mostowski, firstname.lastname at gmail.com
--
-- The main part of VBXE: memory DMA, MEMAC, XDL processing, image output.
--
-- This VBXE implementation is a recreation of the original design
-- from the publicly available documents - the VBXE programmer's manual
-- by Tomasz Piórek and the Altirra Hardware Reference Manual by
-- Avery Lee. The original VBXE core and Atari board was designed and
-- implemented by Tomasz Piórek and Agnieszka Bartkowicz back starting
-- in 2008. All efforts have been made to keep this as compatible as
-- possible with the original, but there are surely small inaccuracies,
-- bugs, and for sure this implementation is not cycle exact with the
-- original. I am happy for this to be reused in any way suitable by
-- anyone as long as (a) I am informed by email about it, (b) no interests
-- or rights of the original authors of VBXE are violated.
--------------------------------------------------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

entity VBXE is
generic ( 
	cycle_length : integer := 16
);
port (
	clk : in std_logic;
	enable : in std_logic;
	ntsc_fix : in std_logic := '0';
	soft_reset : in std_logic;
	enable_179 : in std_logic; -- Original Atari speed (based on Antic enable, always active)
	reset_n : in std_logic;
	pal : in std_logic := '1';
	addr : in std_logic_vector(4 downto 0); -- 32 registers based at $D640/$D740
	data_in: in std_logic_vector(7 downto 0); -- for register write
	wr_en : in std_logic; -- reading or writing registers?
	data_out: out std_logic_vector(7 downto 0); -- for register read

	-- Palette look up interface
	palette_get_color : in std_logic_vector(7 downto 0);
	palette_get_index : in std_logic_vector(1 downto 0);
	r_out : out std_logic_vector(7 downto 0);
	g_out : out std_logic_vector(7 downto 0);
	b_out : out std_logic_vector(7 downto 0);

	-- Palette upload
	VBXE_UPLOAD_PALETTE_RGB : IN STD_LOGIC_VECTOR(2 downto 0);
	VBXE_UPLOAD_PALETTE_INDEX : IN STD_LOGIC_VECTOR(7 downto 0);
	VBXE_UPLOAD_PALETTE_COLOR : IN STD_LOGIC_VECTOR(6 downto 0);

	-- MEMAC
	memac_address : in std_logic_vector(15 downto 0);
	memac_write_enable : in std_logic;
	memac_cpu_access : in std_logic;
	memac_antic_access : in std_logic;
	memac_check : out std_logic;
	memac_data_in : in std_logic_vector(7 downto 0);
	memac_data_out : out std_logic_vector(7 downto 0);
	memac_request : in std_logic;
	memac_request_complete : out std_logic;
	memac_dma_enable : out std_logic;
	memac_dma_address : in std_logic_vector(25 downto 0);
	-- Blitter irq
	irq_n : out std_logic;
	
	gtia_highres : in std_logic;
	gtia_highres_mod : out std_logic;
	gtia_active_hr : in std_logic_vector(1 downto 0);
	gtia_active_hr_mod : out std_logic_vector(1 downto 0);
	gtia_prior : in std_logic_vector(7 downto 0);
	gtia_prior_raw : in std_logic_vector(7 downto 0);
	gtia_pf0 : in std_logic_vector(7 downto 0);
	gtia_pf1 : in std_logic_vector(7 downto 0);
	gtia_pf2 : in std_logic_vector(7 downto 0);
	gtia_pf3 : in std_logic_vector(7 downto 0);
	map_pf0 : out std_logic_vector(7 downto 0);
	map_pf1 : out std_logic_vector(7 downto 0);
	map_pf2 : out std_logic_vector(7 downto 0);
	pf_palette : out std_logic_vector(1 downto 0);
	ov_palette : out std_logic_vector(1 downto 0);
	ov_pixel : out std_logic_vector(7 downto 0);
	ov_pixel_active : out std_logic;
	xcolor : out std_logic;

	video_clock_antic_highres : in std_logic;
	video_clock_antic_lowres : in std_logic;
	video_clock_vbxe : in std_logic;
	gtia_hpos : in std_logic_vector(7 downto 0);	
	vsync : in std_logic
);
end VBXE;

architecture vhdl of VBXE is

component delay_line is
generic(COUNT : natural := 1);
PORT
(
	CLK : IN STD_LOGIC;
	SYNC_RESET : IN STD_LOGIC;
	DATA_IN : IN STD_LOGIC;
	ENABLE : IN STD_LOGIC;
	RESET_N : IN STD_LOGIC;
	DATA_OUT : OUT STD_LOGIC
);
end component;	

signal vram_addr : std_logic_vector(18 downto 0);
signal vram_addr_reg : std_logic_vector(18 downto 0);
signal vram_addr_next : std_logic_vector(18 downto 0);
signal vram_request : std_logic;
signal vram_request_complete : std_logic;
signal vram_wr_en : std_logic;
signal vram_data_in_low : std_logic_vector(2 downto 0);
signal vram_data_in_high : std_logic_vector(4 downto 0);
signal vram_data_in : std_logic_vector(7 downto 0);
signal vram_data : std_logic_vector(7 downto 0);
signal vram_data_next : std_logic_vector(7 downto 0);
signal vram_data_reg : std_logic_vector(7 downto 0);

signal vram_request_reg : std_logic;
signal vram_request_next : std_logic;
signal vram_wr_en_temp : std_logic;

signal color_index_in : std_logic_vector(9 downto 0);
signal color_index_out : std_logic_vector(9 downto 0);

signal data_color_r : std_logic_vector(6 downto 0);
signal data_color_g : std_logic_vector(6 downto 0);
signal data_color_b : std_logic_vector(6 downto 0);

signal csel_reg : std_logic_vector(7 downto 0);
signal csel_next : std_logic_vector(7 downto 0);
signal psel_reg : std_logic_vector(1 downto 0);
signal psel_next : std_logic_vector(1 downto 0);

signal cr_reg : std_logic_vector(6 downto 0);
signal cr_next : std_logic_vector(6 downto 0);
signal cr_request : std_logic;
signal cg_reg : std_logic_vector(6 downto 0);
signal cg_next : std_logic_vector(6 downto 0);
signal cg_request : std_logic;
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

signal p0_reg : std_logic_vector(7 downto 0);
signal p0_next : std_logic_vector(7 downto 0);
signal p1_reg : std_logic_vector(7 downto 0);
signal p1_next : std_logic_vector(7 downto 0);
signal p2_reg : std_logic_vector(7 downto 0);
signal p2_next : std_logic_vector(7 downto 0);
signal p3_reg : std_logic_vector(7 downto 0);
signal p3_next : std_logic_vector(7 downto 0);

signal memc_window_address_start : std_logic_vector(15 downto 0);
signal memc_window_address_end : std_logic_vector(15 downto 0);
signal memac_check_a : std_logic;
signal memac_check_b : std_logic;
--signal memac_dma_check_a : std_logic;
--signal memac_dma_check_b : std_logic;
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

signal blitter_addr_reg : std_logic_vector(18 downto 0);
signal blitter_addr_next : std_logic_vector(18 downto 0);
signal blitter_status : std_logic_vector(1 downto 0);
signal blitter_collision : std_logic_vector(7 downto 0);
signal blitter_enable : std_logic;
signal blitter_request : std_logic_vector(1 downto 0);
signal blitter_vram_wren : std_logic;
signal blitter_vram_data : std_logic_vector(7 downto 0);
signal blitter_vram_data_in_reg : std_logic_vector(7 downto 0);
signal blitter_vram_data_in_next : std_logic_vector(7 downto 0);
signal blitter_vram_address : std_logic_vector(18 downto 0);
signal blitter_irq : std_logic;
signal blitter_irqc : std_logic;
signal blitter_irqen_reg : std_logic;
signal blitter_irqen_next : std_logic;
signal blitter_pending_reg : std_logic;
signal blitter_pending_next : std_logic;

signal xdl_addr_next : std_logic_vector(18 downto 0);
signal xdl_addr_reg : std_logic_vector(18 downto 0);
signal xdl_fetch_next : std_logic_vector(18 downto 0);
signal xdl_fetch_reg : std_logic_vector(18 downto 0);
signal xdl_enabled_next : std_logic;
signal xdl_enabled_reg : std_logic;
signal xdl_pending_next : std_logic;
signal xdl_pending_reg : std_logic;
signal xdl_cmd_reg : std_logic_vector(15 downto 0);
signal xdl_cmd_next : std_logic_vector(15 downto 0);
signal xdl_read_state_reg : integer range 0 to 24;
signal xdl_read_state_next : integer range 0 to 24;
signal xdl_active_reg : std_logic;
signal xdl_active_next : std_logic;
signal xdl_rptl_reg : unsigned(7 downto 0);
signal xdl_rptl_next : unsigned(7 downto 0);
signal xdl_ovaddr_reg : unsigned(18 downto 0);
signal xdl_ovaddr_next : unsigned(18 downto 0);
signal xdl_ovaddr_step_reg : unsigned(11 downto 0);
signal xdl_ovaddr_step_next : unsigned(11 downto 0);
signal xdl_ovscr_h_reg : unsigned(2 downto 0);
signal xdl_ovscr_h_next : unsigned(2 downto 0);
signal xdl_ovscr_v_reg : unsigned(2 downto 0);
signal xdl_ovscr_v_next : unsigned(2 downto 0);
signal xdl_chbase_reg : std_logic_vector(7 downto 0);
signal xdl_chbase_next : std_logic_vector(7 downto 0);
signal xdl_mapaddr_reg : unsigned(18 downto 0);
signal xdl_mapaddr_next : unsigned(18 downto 0);
signal xdl_mapaddr_step_reg : unsigned(11 downto 0);
signal xdl_mapaddr_step_next : unsigned(11 downto 0);
signal xdl_mapscr_h_reg : unsigned(4 downto 0);
signal xdl_mapscr_h_next : unsigned(4 downto 0);
signal xdl_mapscr_v_reg : unsigned(4 downto 0);
signal xdl_mapscr_v_next : unsigned(4 downto 0);
signal xdl_map_wd_reg : unsigned(4 downto 0);
signal xdl_map_wd_next : unsigned(4 downto 0);
signal xdl_map_ht_reg : unsigned(4 downto 0);
signal xdl_map_ht_next : unsigned(4 downto 0);
signal xdl_ov_size_reg : std_logic_vector(1 downto 0);
signal xdl_ov_size_next : std_logic_vector(1 downto 0);
signal xdl_ov_pal_reg : std_logic_vector(1 downto 0);
signal xdl_ov_pal_next : std_logic_vector(1 downto 0);
signal xdl_pf_pal_reg : std_logic_vector(1 downto 0);
signal xdl_pf_pal_next : std_logic_vector(1 downto 0);
signal xdl_gp_reg : std_logic_vector(7 downto 0);
signal xdl_gp_next : std_logic_vector(7 downto 0);

signal xdl_map_vcount_reg : unsigned(4 downto 0);
signal xdl_map_vcount_next : unsigned(4 downto 0);
signal xdl_map_read_reg : std_logic;
signal xdl_map_read_next : std_logic;
signal xdl_map_active_reg : std_logic;
signal xdl_map_active_next : std_logic;
signal xdl_map_fetch_reg : unsigned(18 downto 0);
signal xdl_map_fetch_next : unsigned(18 downto 0);
signal xdl_map_fetch_init_reg : unsigned(18 downto 0);
signal xdl_map_fetch_init_next : unsigned(18 downto 0);
signal xdl_map_read_count_reg : unsigned(7 downto 0); -- integer range 0 to 172;
signal xdl_map_read_count_next : unsigned(7 downto 0); -- integer range 0 to 172;

type xdl_map_buffer_type is array(0 to 171) of std_logic_vector(7 downto 0);
signal xdl_map_buffer : xdl_map_buffer_type;

signal xdl_map_buffer_data_in_reg : std_logic_vector(7 downto 0);
signal xdl_map_buffer_data_in_next : std_logic_vector(7 downto 0);
signal xdl_map_buffer_data_out : std_logic_vector(31 downto 0);
signal xdl_map_buffer_wren : std_logic;

signal xdl_map_buffer_index_reg : unsigned(5 downto 0);
signal xdl_map_buffer_index_next : unsigned(5 downto 0);

signal xdl_map_sindex_reg : unsigned(4 downto 0);
signal xdl_map_sindex_next : unsigned(4 downto 0);

signal xdl_field_start : std_logic;
signal xdl_field_end : std_logic;
signal xdl_field_end2 : std_logic;

signal xdl_map_live_start : std_logic;
signal xdl_map_live_end : std_logic;

signal xdl_map_live_reg : std_logic;
signal xdl_map_live_next : std_logic;

signal xdl_ov_active_reg : std_logic;
signal xdl_ov_active_next : std_logic;
signal xdl_ov_live_start : std_logic;
signal xdl_ov_live_end : std_logic;

signal xdl_ov_live_reg : std_logic;
signal xdl_ov_live_next : std_logic;

signal xdl_ov_glive_start : std_logic;
signal xdl_ov_glive_end : std_logic;
signal xdl_ov_tlive_start : std_logic;
signal xdl_ov_tlive_end : std_logic;
signal xdl_ov_tlive2_start : std_logic;
signal xdl_ov_tlive2_end : std_logic;

signal xdl_ov_tlive_reg : std_logic;
signal xdl_ov_tlive_next : std_logic;

signal xdl_ov_vcount_reg : unsigned(2 downto 0);
signal xdl_ov_vcount_next : unsigned(2 downto 0);

signal xdl_ov_fetch_reg : unsigned(18 downto 0);
signal xdl_ov_fetch_next : unsigned(18 downto 0);
signal xdl_ov_fetch_init_reg : unsigned(18 downto 0);
signal xdl_ov_fetch_init_next : unsigned(18 downto 0);

signal xdl_vdelay_reg : integer range 0 to 63;
signal xdl_vdelay_next : integer range 0 to 63;

signal xdl_pixel_buffer_windex_reg : integer range 0 to 15;
signal xdl_pixel_buffer_windex_next : integer range 0 to 15;
signal xdl_pixel_sindex_reg : integer range 0 to 23;
signal xdl_pixel_sindex_next : integer range 0 to 23;

type xdl_pixel_type is array(0 to 15) of std_logic_vector(7 downto 0);
type xdl_trans_type is array(0 to 15) of std_logic;

signal xdl_pixels_reg : xdl_pixel_type;
signal xdl_pixels_next : xdl_pixel_type;
signal xdl_ptrans_reg : xdl_trans_type;
signal xdl_ptrans_next : xdl_trans_type;

signal xdl_ov_text_reg : std_logic;
signal xdl_ov_text_next : std_logic;
signal xdl_char_code_reg : std_logic_vector(7 downto 0);
signal xdl_char_code_next : std_logic_vector(7 downto 0);
signal xdl_char_attr_reg : std_logic_vector(7 downto 0);
signal xdl_char_attr_next : std_logic_vector(7 downto 0);
signal xdl_ov_hi_reg : std_logic;
signal xdl_ov_hi_next : std_logic;
signal xdl_ov_lo_reg : std_logic;
signal xdl_ov_lo_next : std_logic;

signal xdl_pf_palette : std_logic_vector(1 downto 0);
signal xdl_ov_palette : std_logic_vector(1 downto 0);
signal xdl_ov_pixel : std_logic_vector(7 downto 0);
signal xdl_ov_pixel_active : std_logic;

signal xdl_vcount_reg : integer range 0 to 255;
signal xdl_vcount_next : integer range 0 to 255;

signal xcolor_reg : std_logic;
signal xcolor_next : std_logic;
signal no_trans_reg : std_logic;
signal no_trans_next : std_logic;
signal trans15_reg : std_logic;
signal trans15_next : std_logic;

signal vram_op_reg : std_logic_vector(1 downto 0);
signal vram_op_next : std_logic_vector(1 downto 0);

signal clock_shift_reg : std_logic_vector(cycle_length-1 downto 0);
signal clock_shift_next : std_logic_vector(cycle_length-1 downto 0);

signal cr_wren : std_logic;
signal cg_wren : std_logic;
signal cb_wren : std_logic;

signal cr_data_in : std_logic_vector(6 downto 0);
signal cg_data_in : std_logic_vector(6 downto 0);
signal cb_data_in : std_logic_vector(6 downto 0);

signal colmask_reg : std_logic_vector(7 downto 0);
signal colmask_next : std_logic_vector(7 downto 0);
signal coldetect_reg : std_logic_vector(7 downto 0);
signal coldetect_next : std_logic_vector(7 downto 0);
signal colclear : std_logic;

begin

process(gtia_pf0,gtia_pf1,gtia_pf2,gtia_pf3,gtia_highres,gtia_active_hr,gtia_prior,gtia_prior_raw,
	enable,xdl_active_reg,xdl_map_live_reg,xdl_map_wd_reg,xdl_map_sindex_reg,xdl_map_buffer_data_out,
	xdl_ov_pal_reg,xdl_pf_pal_reg,xdl_gp_reg,xdl_ov_text_reg,xdl_pixels_reg,xdl_ptrans_reg,xdl_pixel_sindex_reg,
	p0_reg,p1_reg,p2_reg,p3_reg,xdl_map_buffer_index_reg,coldetect_reg,colclear,gtia_hpos,xdl_map_active_reg,
	xdl_mapscr_h_reg,xdl_ov_active_reg,xdl_ovscr_h_reg,video_clock_antic_highres,xdl_ov_live_reg,
	colmask_reg,no_trans_reg,trans15_reg,video_clock_vbxe)
	variable flip_23 : boolean;
	variable ov_prior : std_logic_vector(7 downto 0);
	variable gtia_prior_adj : std_logic_vector(7 downto 0);
begin
	xdl_map_buffer_index_next <= xdl_map_buffer_index_reg;
	xdl_map_sindex_next <= xdl_map_sindex_reg;
	xdl_pixel_sindex_next <= xdl_pixel_sindex_reg;
	coldetect_next <= coldetect_reg;
	gtia_highres_mod <= gtia_highres;
	gtia_active_hr_mod <= gtia_active_hr;
	map_pf0 <= gtia_pf0;
	map_pf1 <= gtia_pf1;
	map_pf2 <= gtia_pf2;
	xdl_pf_palette <= "00";
	xdl_ov_palette <= "00";
	xdl_ov_pixel <= (others => '0');
	xdl_ov_pixel_active <= '0';
	gtia_prior_adj := gtia_prior;
	ov_prior := x"00";
	flip_23 := false;
	if colclear = '1' then
		coldetect_next <= (others => '0');
	end if;
	if (xdl_active_reg = '1') and (enable = '1') then
		xdl_pf_palette <= xdl_pf_pal_reg;
		xdl_ov_palette <= xdl_ov_pal_reg;
		ov_prior := xdl_gp_reg;
		if (gtia_hpos = x"10") then -- arbitrary, as long as it's before anything gets displayed
			if (xdl_map_active_reg = '1') then
				xdl_map_buffer_index_next <= (others => '0');
				xdl_map_sindex_next <= xdl_mapscr_h_reg;
			end if;
			if (xdl_ov_active_reg = '1') then
				if xdl_ov_text_reg = '1' then
					xdl_pixel_sindex_next <= to_integer(xdl_ovscr_h_reg);
				else
					xdl_pixel_sindex_next <= 0;
				end if;
			end if;
		end if;
		if xdl_map_live_reg = '1' then
			map_pf0 <= xdl_map_buffer_data_out(31 downto 24);
			map_pf1 <= xdl_map_buffer_data_out(23 downto 16);
			if (gtia_highres xor xdl_map_buffer_data_out(2)) = '1' then
				case xdl_map_wd_reg(4 downto 3) is
				when "00" =>
				if xdl_map_buffer_data_out(31-to_integer(xdl_map_sindex_reg(2 downto 0))) = '1' then
					flip_23 := true;
				end if;
				when "01" =>
				if xdl_map_buffer_data_out(31-to_integer(xdl_map_sindex_reg(3 downto 1))) = '1' then
					flip_23 := true;
				end if;
				when others =>
				if xdl_map_buffer_data_out(31-to_integer(xdl_map_sindex_reg(4 downto 2))) = '1' then
					flip_23 := true;
				end if;
				end case;
				if gtia_highres = '0' then
					gtia_highres_mod <= '1';
					if gtia_prior_raw(4) = '1' then
						gtia_active_hr_mod <= "01";
					elsif gtia_prior_raw(5) = '1' then
						gtia_active_hr_mod <= "10";
					elsif gtia_prior_raw(6) = '1' then
						gtia_active_hr_mod <= "11";
					elsif gtia_prior_raw(7) = '1' then
						gtia_active_hr_mod <= "00";
					end if;
				end if;
			end if;
			if flip_23 then
				map_pf2 <= gtia_pf3;
			else
				map_pf2 <= xdl_map_buffer_data_out(15 downto 8);
				if (gtia_highres and xdl_map_buffer_data_out(2)) = '1' then
					gtia_active_hr_mod <= "00";
					case gtia_active_hr is
					when "00" =>
						map_pf2 <= xdl_map_buffer_data_out(31 downto 24);
						gtia_prior_adj(6 downto 4) := "001";
					when "01" =>
						map_pf2 <= xdl_map_buffer_data_out(23 downto 16);
						gtia_prior_adj(6 downto 4) := "010";
					when "10" => null;
					when "11" => map_pf2 <= gtia_pf3;
					end case;
				end if;  
			end if;
			xdl_pf_palette <= xdl_map_buffer_data_out(7 downto 6);
			xdl_ov_palette <= xdl_map_buffer_data_out(5 downto 4);
			case xdl_map_buffer_data_out(1 downto 0) is
				when "00" => ov_prior := p0_reg;
				when "01" => ov_prior := p1_reg;
				when "10" => ov_prior := p2_reg;
				when "11" => ov_prior := p3_reg;
			end case;
			if (video_clock_antic_highres = '1') then
				if xdl_map_sindex_reg = xdl_map_wd_reg then
					xdl_map_sindex_next <= "00000";
					xdl_map_buffer_index_next <= xdl_map_buffer_index_reg + 1;
				else
					xdl_map_sindex_next <= xdl_map_sindex_reg + 1;
				end if;
			end if;
		end if;
		
		if (xdl_ov_live_reg = '1') and (or_reduce(gtia_prior_adj and ov_prior) = '1') then
			xdl_ov_pixel <= xdl_pixels_reg(xdl_pixel_sindex_reg);
			xdl_ov_pixel_active <= not(xdl_ptrans_reg(xdl_pixel_sindex_reg));
			if xdl_ptrans_reg(xdl_pixel_sindex_reg) = '0' then
				if colmask_reg(to_integer(unsigned(xdl_pixels_reg(xdl_pixel_sindex_reg)(7 downto 5)))) = '1' then
					coldetect_next <= coldetect_reg or ((xdl_map_buffer_data_out(3) and xdl_map_active_reg) & gtia_prior_adj(6 downto 0));
				end if;
			end if;
			if (no_trans_reg = '0') and (trans15_reg = '1') and (xdl_pixels_reg(xdl_pixel_sindex_reg)(3 downto 0) = x"F") then
				xdl_ov_pixel_active <= '0';
			end if;
		end if;
		if (xdl_ov_live_reg = '1') and (video_clock_vbxe = '1') then
			if xdl_pixel_sindex_reg = 15 then
				xdl_pixel_sindex_next <= 0;
			else
				xdl_pixel_sindex_next <= xdl_pixel_sindex_reg + 1;
			end if;
		end if;
	end if;
end process;

xcolor <= xcolor_reg;
ov_palette <= xdl_ov_palette;
pf_palette <= xdl_pf_palette;
ov_pixel <= xdl_ov_pixel;
ov_pixel_active <= xdl_ov_pixel_active;

irq_n <= not(enable and blitter_irqen_reg and blitter_irq);

blitter: entity work.VBXE_blitter
port map (
	clk => clk,
	reset_n => reset_n,
	soft_reset => soft_reset,
	blitter_enable => blitter_enable,
	blitter_start_request => blitter_request(0),
	blitter_stop_request => blitter_request(1),
	blitter_address => blitter_addr_reg,
	blitter_vram_data_in => blitter_vram_data_in_next,
	blitter_vram_wren => blitter_vram_wren,
	blitter_vram_data => blitter_vram_data,
	blitter_vram_address => blitter_vram_address,
	blitter_status => blitter_status,
	blitter_collision => blitter_collision,
	blitter_irq => blitter_irq,
	blitter_irqc => blitter_irqc
);


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

r_out <= data_color_r & '0';
g_out <= data_color_g & '0';
b_out <= data_color_b & '0';

vbxe_vram_low_bits: entity work.spram
generic map(addr_width => 19, data_width => 3, mem_depth => 8192)
port map
(
	clock => clk,
	address => vram_addr(18 downto 0),
	data => vram_data(2 downto 0),
	wren => vram_wr_en_temp, 
	q => vram_data_in_low
);

vbxe_vram_high_bits: entity work.spram
generic map(addr_width => 19, data_width => 5, mem_depth => 2048)
port map
(
	clock => clk,
	address => vram_addr(18 downto 0),
	data => vram_data(7 downto 3),
	wren => vram_wr_en_temp, 
	q => vram_data_in_high
);

vram_data_in <= vram_data_in_high & vram_data_in_low;

vram_wr_en_temp <= vram_wr_en and vram_request;
vram_request_next <= vram_request and not(vram_wr_en);
vram_request_complete <= vram_wr_en_temp or vram_request_reg;

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

-- A solution to an intricate problem -- a MEMAC access from either the CPU or Antic
-- needs to be properly timed, MEMAC can serve one request per Atari cycle, the DMA 
-- state machine resets everything for a new MEMAC round roughly around the ANTIC
-- enable signal and serves the MEMAC request shortly after. This way, when the "actual"
-- Atari asks for MEMAC data we will serve it on the same cycle, and at a particular relative
-- time compared to when the request was made. Now, ZPU/DMA is not Atari clock synchronized/aware,
-- and can drop a request that is potentially MEMAC on the address decoder at any time, 
-- not only when the Atari does it. Long story short - DMA request that is potentially 
-- accessing MEMAC memory needs to come later than any potential CPU or Antic request
-- (so that those get priority and DMA is pushed to the next Atari cycle) but at the same time 
-- early enough so that the DMA engine can catch it and service it on the same Atari cycle.
-- (The priorities implemented in the address decoder do not help much because we can only service
-- one MEMAC request per Atari cycle). Fine if:

memac_dma_enable <=
	not(enable) or -- VBXE is not active 
	or_reduce(memac_dma_address(25 downto 18)) -- The DMA access is not to the Atari
	or clock_shift_reg(1) -- we are at the earliest possible cycle not to push out other reqests
	or not(mems_reg(7) or memb_reg(7) or memb_reg(6)); -- MEMAC is disabled

-- This does not work, not sure why, but just checking for registers should be fine
-- (i.e. no slowdown of DMA access for programs not using VBXE)
--memac_dma_check_a <= '1' when
--	(unsigned(memac_dma_address(15 downto 0)) >= unsigned(memc_window_address_start)) and
--	(unsigned(memac_dma_address(15 downto 0)) <= unsigned(memc_window_address_end)) and
--	((mems_reg(7) and (memc_reg(3) or memc_reg(2))) = '1')
--	else '0';

--memac_dma_check_b <= 
--	not(memac_dma_address(15)) and memac_dma_address(14) and (memb_reg(7) or memb_reg(6));

color_index_in <= 
	"00" & VBXE_UPLOAD_PALETTE_INDEX 
	when (VBXE_UPLOAD_PALETTE_RGB(0) or VBXE_UPLOAD_PALETTE_RGB(1) or VBXE_UPLOAD_PALETTE_RGB(2)) = '1' else
	(psel_next & csel_next);

cr_wren <= VBXE_UPLOAD_PALETTE_RGB(0) or cr_request;
cg_wren <= VBXE_UPLOAD_PALETTE_RGB(1) or cg_request;
cb_wren <= VBXE_UPLOAD_PALETTE_RGB(2) or cb_request_next;

cr_data_in <= VBXE_UPLOAD_PALETTE_COLOR when VBXE_UPLOAD_PALETTE_RGB(0) = '1' else cr_next;
cg_data_in <= VBXE_UPLOAD_PALETTE_COLOR when VBXE_UPLOAD_PALETTE_RGB(1) = '1' else cg_next;
cb_data_in <= VBXE_UPLOAD_PALETTE_COLOR when VBXE_UPLOAD_PALETTE_RGB(2) = '1' else cb_next;

color_index_out <= (palette_get_index & palette_get_color);

colors0_r: entity work.dpram
generic map(10,7,"rtl/vbxe/pal_r.mif")
port map
(
	clock => clk,
	address_a => color_index_in,
	data_a => cr_data_in,
	wren_a => cr_wren,
	address_b => color_index_out,
	q_b => data_color_r
);

colors0_g: entity work.dpram
generic map(10,7,"rtl/vbxe/pal_g.mif")
port map
(
	clock => clk,
	address_a => color_index_in,
	data_a => cg_data_in,
	wren_a => cg_wren,
	address_b => color_index_out,
	q_b => data_color_g
);

colors0_b: entity work.dpram
generic map(10,7,"rtl/vbxe/pal_b.mif")
port map
(
	clock => clk,
	address_a => color_index_in,
	data_a => cb_data_in,
	wren_a => cb_wren,
	address_b => color_index_out,
	q_b => data_color_b
);

-- write registers
process(addr, wr_en, soft_reset, data_in, csel_reg, psel_reg, cr_reg, cg_reg, cb_reg, cb_request_reg, memc_reg, mems_reg, memb_reg, trans15_reg, no_trans_reg,
	blitter_addr_reg, blitter_status, blitter_irqen_reg, xdl_enabled_reg, xcolor_reg, pal, xdl_addr_reg, p0_reg, p1_reg, p2_reg, p3_reg, colmask_reg)
begin
		csel_next <= csel_reg;
		psel_next <= psel_reg;
		cr_request <= '0';
		cg_request <= '0';
		cb_request_next <= '0';
		cr_next <= cr_reg;
		cg_next <= cg_reg;
		cb_next <= cb_reg;
		memc_next <= memc_reg;
		mems_next <= mems_reg;
		memb_next <= memb_reg;
		blitter_addr_next <= blitter_addr_reg;
		blitter_request <= "00";
		blitter_irqen_next <= blitter_irqen_reg;
		blitter_irqc <= '0';
		xdl_enabled_next <= xdl_enabled_reg;
		xcolor_next <= xcolor_reg;
		trans15_next <= trans15_reg;
		no_trans_next <= no_trans_reg;
		xdl_addr_next <= xdl_addr_reg;
		p0_next <= p0_reg;
		p1_next <= p1_reg;
		p2_next <= p2_reg;
		p3_next <= p3_reg;
		colmask_next <= colmask_reg;
		colclear <= '0';
		if wr_en = '1' then
			case addr is
				-- XDL
				when "00000" =>
					xdl_enabled_next <= data_in(0);
					xcolor_next <= data_in(1);
					no_trans_next <= data_in(2);
					trans15_next <= data_in(3);
				when "00001" =>
					xdl_addr_next(7 downto 0) <= data_in;
				when "00010" =>
					xdl_addr_next(15 downto 8) <= data_in;
				when "00011" =>
					xdl_addr_next(18 downto 16) <= data_in(2 downto 0);
				-- Palette registers
				when "00100" => -- $44 csel
					csel_next <= data_in;
				when "00101" => -- $45 psel
					psel_next <= data_in(1 downto 0);
				when "00110" => -- $46 cr
					cr_next <= data_in(7 downto 1);
					cr_request <= '1';
				when "00111" => -- $47 cg
					cg_next <= data_in(7 downto 1);
					cg_request <= '1';
				when "01000" => -- $48 cb
					cb_next <= data_in(7 downto 1);
					cb_request_next <= '1';
				when "01001" => -- $49 collision mask
					colmask_next <= data_in;
				when "01010" => -- $4A collision clear
					colclear <= '1';
				-- Blitter
				when "10000" => -- $50 bl_adr0
					blitter_addr_next(7 downto 0) <= data_in;
				when "10001" => -- $51 bl_adr1
					blitter_addr_next(15 downto 8) <= data_in;
				when "10010" => -- $52 bl_adr2
					blitter_addr_next(18 downto 16) <= data_in(2 downto 0);
				when "10011" => -- $53 blitter_start
					blitter_request(0) <= not(blitter_status(0) or blitter_status(1)) and data_in(0);
					blitter_request(1) <= not(data_in(0));
				when "10100" => -- $54 irq_control
					blitter_irqen_next <= data_in(0);
					blitter_irqc <= '1';
				-- P0 - P3
				when "10101" =>  -- $55
					p0_next <= data_in;
				when "10110" =>  -- $56
					p1_next <= data_in;
				when "10111" =>  -- $57
					p2_next <= data_in;
				when "11000" =>  -- $58
					p3_next <= data_in;
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
		if cb_request_reg = '1' then
			csel_next <= std_logic_vector(unsigned(csel_reg) + 1);
		end if;
		if soft_reset = '1' then
			xdl_enabled_next <= '0';
			xcolor_next <= '0';
			no_trans_next <= '0';
			trans15_next <= '0';
			memc_next(3 downto 2) <= "00";
			mems_next(7) <= '0';
			memb_next(7 downto 6) <= "00";
			blitter_irqen_next <= '0';
			blitter_request <= "00";
			colclear <= '1';
			colmask_next <= (others => '0');
		end if;
end process;

-- Read registers
process(addr, memc_reg, mems_reg, blitter_status, blitter_collision, blitter_irq, blitter_irqen_reg, coldetect_reg)
begin
	case addr is
		when "00000" => -- $40 core version -> FX
			data_out <= X"10";
		when "00001" => -- $41 minor version
			data_out <= X"26";
		when "01010" => -- $4A raster collision detection
			data_out <= coldetect_reg;
		when "10000" => -- $50 collision_code
			data_out <= blitter_collision;
		when "10011" => -- $53 blitter busy
			data_out <= "000000" & blitter_status(1 downto 0);
		when "10100" => -- $54 irq status
			data_out <= "0000000" & (blitter_irq and blitter_irqen_reg);
		-- MEMAC A registers are readable
		when "11110" => -- $5E memac_control
			data_out <= memc_reg;
		when "11111" => -- $5F memac_banksel
			data_out <= mems_reg;
		when others =>
			data_out <= X"FF";
	end case;
end process;

process(clk, reset_n)
begin
	if (reset_n = '0') then
		vram_request_reg <= '0';
		csel_reg <= (others => 'U');
		psel_reg <= (others => 'U');
		cr_reg <= (others => 'U');
		cg_reg <= (others => 'U');
		cb_reg <= (others => 'U');
		cb_request_reg <= '0';
		p0_reg <= (others => '0'); -- TODO what is the default here? Altirra sets this to 0?
		p1_reg <= (others => '0');
		p2_reg <= (others => '0');
		p3_reg <= (others => '0');
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
		blitter_addr_reg <= (others => 'U');
		blitter_irqen_reg <= '0';
		blitter_vram_data_in_reg <= (others => 'U'); 
		blitter_pending_reg <= '0';
		xdl_addr_reg <= (others => 'U');
		xdl_fetch_reg <= (others => 'U');
		xdl_enabled_reg <= '0';
		xdl_pending_reg <= '0';
		xdl_cmd_reg <= (others => '0');
		xdl_read_state_reg <= 0;

		xdl_active_reg <= '0';
		xdl_cmd_reg <= (others => '0');
		xdl_rptl_reg <= (others => '0');
		xdl_ovaddr_reg <= (others => '0');
		xdl_ovaddr_step_reg <= (others => '0');
		xdl_ovscr_h_reg <= "000";
		xdl_ovscr_v_reg <= "000";
		xdl_chbase_reg <= (others => '0');
		xdl_mapaddr_reg <= (others => '0');
		xdl_mapaddr_step_reg <= (others => '0');
		xdl_mapscr_h_reg <= "00000";
		xdl_mapscr_v_reg <= "00000";
		xdl_map_wd_reg <= "00000";
		xdl_map_ht_reg <= "00000";
		xdl_ov_size_reg <= "00";
		xdl_ov_pal_reg <= "00";
		xdl_pf_pal_reg <= "00";
		xdl_gp_reg <= (others => '1');

		xdl_map_vcount_reg <= "00000";
		xdl_map_read_reg <= '0';
		xdl_map_active_reg <= '0';
		xdl_map_fetch_reg <= (others => '0');
		xdl_map_fetch_init_reg <= (others => '0');
		xdl_map_read_count_reg <= (others => '0');
		xdl_map_buffer_index_reg <= (others => '0');
		xdl_map_sindex_reg <= "00000";
		xdl_map_buffer_data_in_reg <= (others => '0');
		xdl_map_live_reg <= '0';
		xdl_vdelay_reg <= 0;
		xcolor_reg <= '0';
		no_trans_reg <= '0';
		trans15_reg <= '0';
		xdl_ov_active_reg <= '0';
		xdl_ov_live_reg <= '0';
		xdl_ov_tlive_reg <= '0';
		xdl_ov_vcount_reg <= "000";
		xdl_ov_fetch_reg <= (others => '0');
		xdl_ov_fetch_init_reg <= (others => '0');
		xdl_ov_text_reg <= '0';
		xdl_ov_hi_reg <= '0';
		xdl_ov_lo_reg <= '0';

		xdl_pixel_sindex_reg <= 0;
		xdl_pixel_buffer_windex_reg <= 0;
		xdl_pixels_reg <= (others => (others => '0'));
		xdl_ptrans_reg <= (others => '0');
		xdl_char_code_reg <= (others => '0');
		xdl_char_attr_reg <= (others => '0');
		xdl_vcount_reg <= 0;

		colmask_reg <= (others => '0');
		coldetect_reg <= (others => '0');

	elsif rising_edge(clk) then
		vram_request_reg <= vram_request_next;
		csel_reg <= csel_next;
		psel_reg <= psel_next;
		cr_reg <= cr_next;
		cg_reg <= cg_next;
		cb_reg <= cb_next;
		cb_request_reg <= cb_request_next;
		memc_reg <= memc_next;
		mems_reg <= mems_next;
		memb_reg <= memb_next;
		p0_reg <= p0_next;
		p1_reg <= p1_next;
		p2_reg <= p2_next;
		p3_reg <= p3_next;

		dma_state_reg <= dma_state_next;
		memac_request_complete_reg <= memac_request_complete_next;
		memac_request_reg <= memac_request_next;
		vram_op_reg <= vram_op_next;
		vram_data_reg <= vram_data_next;
		vram_addr_reg <= vram_addr_next;
		memac_check_reg <= memac_check_next;
		clock_shift_reg <= clock_shift_next;
		memac_data_reg <= memac_data_next;
		blitter_addr_reg <= blitter_addr_next;
		blitter_irqen_reg <= blitter_irqen_next;
		blitter_vram_data_in_reg <= blitter_vram_data_in_next;
		blitter_pending_reg <= blitter_pending_next;
		xdl_addr_reg <= xdl_addr_next;
		xdl_fetch_reg <= xdl_fetch_next;
		xdl_enabled_reg <= xdl_enabled_next;
		xdl_pending_reg <= xdl_pending_next;
		xdl_cmd_reg <= xdl_cmd_next;
		xdl_read_state_reg <= xdl_read_state_next;

		xdl_active_reg <= xdl_active_next;
		xdl_cmd_reg <= xdl_cmd_next;
		xdl_rptl_reg <= xdl_rptl_next;
		xdl_ovaddr_reg <= xdl_ovaddr_next;
		xdl_ovaddr_step_reg <= xdl_ovaddr_step_next;
		xdl_ovscr_h_reg <= xdl_ovscr_h_next;
		xdl_ovscr_v_reg <= xdl_ovscr_v_next;
		xdl_chbase_reg <= xdl_chbase_next;
		xdl_mapaddr_reg <= xdl_mapaddr_next;
		xdl_mapaddr_step_reg <= xdl_mapaddr_step_next;
		xdl_mapscr_h_reg <= xdl_mapscr_h_next;
		xdl_mapscr_v_reg <= xdl_mapscr_v_next;
		xdl_map_wd_reg <= xdl_map_wd_next;
		xdl_map_ht_reg <= xdl_map_ht_next;
		xdl_ov_size_reg <= xdl_ov_size_next;
		xdl_ov_pal_reg <= xdl_ov_pal_next;
		xdl_pf_pal_reg <= xdl_pf_pal_next;
		xdl_gp_reg <= xdl_gp_next;

		xdl_map_vcount_reg <= xdl_map_vcount_next;
		xdl_map_read_reg <= xdl_map_read_next;
		xdl_map_active_reg <= xdl_map_active_next;
		xdl_map_fetch_reg <= xdl_map_fetch_next;
		xdl_map_fetch_init_reg <= xdl_map_fetch_init_next;
		xdl_map_read_count_reg <= xdl_map_read_count_next;
		xdl_map_buffer_index_reg <= xdl_map_buffer_index_next;
		xdl_map_sindex_reg <= xdl_map_sindex_next;
		xdl_map_buffer_data_in_reg <= xdl_map_buffer_data_in_next;

		xdl_map_live_reg <= xdl_map_live_next;
		xdl_vdelay_reg <= xdl_vdelay_next;
		xcolor_reg <= xcolor_next;
		no_trans_reg <= no_trans_next;
		trans15_reg <= trans15_next;
		xdl_ov_active_reg <= xdl_ov_active_next;
		xdl_ov_live_reg <= xdl_ov_live_next;
		xdl_ov_tlive_reg <= xdl_ov_tlive_next;
		xdl_ov_vcount_reg <= xdl_ov_vcount_next;
		xdl_ov_fetch_reg <= xdl_ov_fetch_next;
		xdl_ov_fetch_init_reg <= xdl_ov_fetch_init_next;
		xdl_ov_text_reg <= xdl_ov_text_next;
		xdl_ov_hi_reg <= xdl_ov_hi_next;
		xdl_ov_lo_reg <= xdl_ov_lo_next;

		xdl_pixel_sindex_reg <= xdl_pixel_sindex_next;
		xdl_pixel_buffer_windex_reg <= xdl_pixel_buffer_windex_next;
		xdl_pixels_reg <= xdl_pixels_next;
		xdl_ptrans_reg <= xdl_ptrans_next;

		xdl_char_code_reg <= xdl_char_code_next;
		xdl_char_attr_reg <= xdl_char_attr_next;
		xdl_vcount_reg <= xdl_vcount_next;

		colmask_reg <= colmask_next;
		coldetect_reg <= coldetect_next;
	end if;
end process;

process(clk)
begin
	if rising_edge(clk) then
		if xdl_map_buffer_wren = '1' then
			xdl_map_buffer(to_integer(xdl_map_read_count_reg)) <= xdl_map_buffer_data_in_next;
		else
			xdl_map_buffer_data_out <=
			xdl_map_buffer(to_integer(xdl_map_buffer_index_reg & "00")) &
			xdl_map_buffer(to_integer(xdl_map_buffer_index_reg & "01")) &
			xdl_map_buffer(to_integer(xdl_map_buffer_index_reg & "10")) &
			xdl_map_buffer(to_integer(xdl_map_buffer_index_reg & "11"));
		end if;
	end if;
end process;

process(xdl_active_reg, video_clock_antic_lowres, xdl_ov_size_reg, gtia_hpos)
begin
	xdl_field_start <= '0';
	xdl_field_end <= '0';
	xdl_field_end2 <= '0';
	if (xdl_active_reg = '1') and (video_clock_antic_lowres = '1') then
		if gtia_hpos = x"D6" then xdl_field_end2 <= '1'; end if;
		case xdl_ov_size_reg is
			-- All these are 4 less than the actual places to allow for character buffering
			-- 4 = 8 highres pixels = 16 vbxe highres pixel
			when "00" | "11" => -- Narrow
				if gtia_hpos = x"3C" then xdl_field_start <= '1'; end if;
				if gtia_hpos = x"BC" then xdl_field_end <= '1'; end if;
			when "01" => -- Normal
				if gtia_hpos = x"2C" then xdl_field_start <= '1'; end if;
				if gtia_hpos = x"CC" then xdl_field_end <= '1'; end if;
			when "10" => -- Wide
				if gtia_hpos = x"28" then xdl_field_start <= '1'; end if;
				if gtia_hpos = x"D0" then xdl_field_end <= '1'; end if;
		end case;
	end if;
end process;


map_live_delay_start : delay_line
	generic map (COUNT=>19) -- 3 + 8 + 8
	port map(clk=>clk,sync_reset=>'0',data_in=>xdl_field_start,enable=>video_clock_vbxe,reset_n=>reset_n,data_out=>xdl_map_live_start);

map_live_delay_end : delay_line
	generic map (COUNT=>19) -- 3 + 8 + 8
	port map(clk=>clk,sync_reset=>'0',data_in=>xdl_field_end,enable=>video_clock_vbxe,reset_n=>reset_n,data_out=>xdl_map_live_end);

map_glive_delay_start : delay_line
	generic map (COUNT=>11)
	port map(clk=>clk,sync_reset=>'0',data_in=>xdl_field_start,enable=>video_clock_vbxe,reset_n=>reset_n,data_out=>xdl_ov_glive_start);

map_glive_delay_end : delay_line
	generic map (COUNT=>11)
	port map(clk=>clk,sync_reset=>'0',data_in=>xdl_field_end,enable=>video_clock_vbxe,reset_n=>reset_n,data_out=>xdl_ov_glive_end);

map_tlive_delay_start : delay_line
	generic map (COUNT=>11)
	port map(clk=>clk,sync_reset=>'0',data_in=>xdl_field_start,enable=>video_clock_vbxe,reset_n=>reset_n,data_out=>xdl_ov_tlive_start);

map_tlive_delay_end : delay_line
	generic map (COUNT=>19) -- previous plus 8 to catch one more character (for scrolling)
	port map(clk=>clk,sync_reset=>'0',data_in=>xdl_field_end,enable=>video_clock_vbxe,reset_n=>reset_n,data_out=>xdl_ov_tlive_end);

-- For h scroll values of 5,6,7
map_tlive2_delay_start : delay_line
	generic map (COUNT=>3)
	port map(clk=>clk,sync_reset=>'0',data_in=>xdl_field_start,enable=>video_clock_vbxe,reset_n=>reset_n,data_out=>xdl_ov_tlive2_start);

map_tlive2_delay_end : delay_line
	generic map (COUNT=>11) -- previous plus 8 to catch one more character (for scrolling)
	port map(clk=>clk,sync_reset=>'0',data_in=>xdl_field_end,enable=>video_clock_vbxe,reset_n=>reset_n,data_out=>xdl_ov_tlive2_end);

xdl_ov_live_start <= xdl_map_live_start;
xdl_ov_live_end <= xdl_map_live_end;

process(xdl_map_live_reg, xdl_map_live_start, xdl_map_live_end, xdl_ov_live_reg, xdl_ov_live_start, xdl_ov_live_end, xdl_ov_tlive_reg,
	xdl_ov_tlive_start, xdl_ov_tlive_end, xdl_ov_tlive2_start, xdl_ov_tlive2_end, xdl_ov_glive_start, xdl_ov_glive_end, xdl_map_active_reg,
	xdl_ov_active_reg, xdl_ov_text_reg, xdl_ovscr_h_reg)
begin
	xdl_map_live_next <= xdl_map_live_reg;
	xdl_ov_live_next <= xdl_ov_live_reg;
	xdl_ov_tlive_next <= xdl_ov_tlive_reg;
	if (xdl_map_active_reg = '1') then
		if xdl_map_live_start = '1' then
			xdl_map_live_next <= '1';
		end if;
		if xdl_map_live_end = '1' then
			xdl_map_live_next <= '0';
		end if;
	end if;
	if (xdl_ov_active_reg = '1') then
		if xdl_ov_live_start = '1' then
			xdl_ov_live_next <= '1';
		end if;
		if xdl_ov_live_end = '1' then
			xdl_ov_live_next <= '0';
		end if;
		if xdl_ov_text_reg = '0' then
			if xdl_ov_glive_start = '1' then
				xdl_ov_tlive_next <= '1';
			end if;
			if xdl_ov_glive_end = '1' then
				xdl_ov_tlive_next <= '0';
			end if;
		else
			case xdl_ovscr_h_reg is
				when "101" | "110" | "111" =>
					if xdl_ov_tlive2_start = '1' then
						xdl_ov_tlive_next <= '1';
					end if;
					if xdl_ov_tlive2_end = '1' then
						xdl_ov_tlive_next <= '0';
					end if;
				-- when "000" | "001" | "010" | "011" | "100" =>
				when others => 
					if xdl_ov_tlive_start = '1' then
						xdl_ov_tlive_next <= '1';
					end if;
					if xdl_ov_tlive_end = '1' then
						xdl_ov_tlive_next <= '0';
					end if;
			end case;
		end if;
	end if;
end process;

-- VBXE DMA state machine
process(clock_shift_reg,
	dma_state_reg, memac_request_complete_reg, vram_op_reg, vram_data_reg, vram_addr_reg, memac_data_reg,memac_data_in,memac_request_next, memac_check_next,
	memc_reg,mems_reg,memb_reg,vram_data_in,vram_request_complete,memac_address, blitter_vram_address,blitter_vram_data,blitter_vram_wren,blitter_vram_data_in_reg,
	blitter_status,blitter_pending_reg, xdl_ovscr_h_reg, xdl_ovscr_v_reg,
	xdl_map_active_reg, xdl_ov_active_reg, xdl_ov_text_reg, xdl_fetch_reg, xdl_pending_reg, xdl_read_state_reg, xdl_cmd_reg, xdl_active_reg,
	xdl_rptl_reg, xdl_ovaddr_reg, xdl_ovaddr_step_reg, xdl_chbase_reg, xdl_mapaddr_reg, xdl_mapaddr_step_reg,
	xdl_mapscr_h_reg, xdl_mapscr_v_reg, xdl_map_wd_reg, xdl_map_ht_reg, xdl_ov_size_reg, xdl_ov_pal_reg, xdl_pf_pal_reg, xdl_gp_reg, xdl_map_vcount_reg,
	xdl_map_read_reg, xdl_map_fetch_reg, xdl_map_fetch_init_reg, xdl_map_read_count_reg, xdl_map_buffer_data_in_reg, xdl_vdelay_reg,
	xdl_ov_vcount_reg, xdl_ov_fetch_reg, xdl_ov_fetch_init_reg, xdl_ov_hi_reg, xdl_ov_lo_reg, xdl_pixels_reg,
	xdl_ptrans_reg, xdl_pixel_buffer_windex_reg, xdl_char_attr_reg, xdl_char_code_reg, no_trans_reg, xdl_vcount_reg, xdl_ov_tlive_reg, vsync, pal,
	xdl_enabled_reg, xdl_field_end2, xdl_addr_reg, ntsc_fix)

variable blitter_notify : boolean := false;
variable xdl_or_blitter_notify : boolean := false;
variable xdl_read_required : boolean := false;

begin
	blitter_enable <= '0';
	blitter_vram_data_in_next <= blitter_vram_data_in_reg;
	dma_state_next <= dma_state_reg;
	memac_request_complete_next <= memac_request_complete_reg;
	vram_op_next <= vram_op_reg;
	vram_data_next <= vram_data_reg;
	vram_addr_next <= vram_addr_reg;
	memac_data_next <= memac_data_reg;
	blitter_pending_next <= blitter_pending_reg;

	xdl_fetch_next <= xdl_fetch_reg;
	xdl_pending_next <= xdl_pending_reg;
	xdl_read_state_next <= xdl_read_state_reg;
	xdl_cmd_next <= xdl_cmd_reg;

	xdl_active_next <= xdl_active_reg;
	xdl_cmd_next <= xdl_cmd_reg;
	xdl_rptl_next <= xdl_rptl_reg;
	xdl_ovaddr_next <= xdl_ovaddr_reg;
	xdl_ovaddr_step_next <= xdl_ovaddr_step_reg;
	xdl_ovscr_h_next <= xdl_ovscr_h_reg;
	xdl_ovscr_v_next <= xdl_ovscr_v_reg;
	xdl_chbase_next <= xdl_chbase_reg;
	xdl_mapaddr_next <= xdl_mapaddr_reg;
	xdl_mapaddr_step_next <= xdl_mapaddr_step_reg;
	xdl_mapscr_h_next <= xdl_mapscr_h_reg;
	xdl_mapscr_v_next <= xdl_mapscr_v_reg;
	xdl_map_wd_next <= xdl_map_wd_reg;
	xdl_map_ht_next <= xdl_map_ht_reg;
	xdl_ov_size_next <= xdl_ov_size_reg;
	xdl_ov_pal_next <= xdl_ov_pal_reg;
	xdl_pf_pal_next <= xdl_pf_pal_reg;
	xdl_gp_next <= xdl_gp_reg;

	xdl_map_vcount_next <= xdl_map_vcount_reg;
	xdl_map_read_next <= xdl_map_read_reg;
	xdl_map_active_next <= xdl_map_active_reg;
	xdl_map_fetch_next <= xdl_map_fetch_reg;
	xdl_map_fetch_init_next <= xdl_map_fetch_init_reg;
	xdl_map_read_count_next <= xdl_map_read_count_reg;
	xdl_map_buffer_data_in_next <= xdl_map_buffer_data_in_reg;
	xdl_vdelay_next <= xdl_vdelay_reg;

	xdl_ov_active_next <= xdl_ov_active_reg;
	xdl_ov_vcount_next <= xdl_ov_vcount_reg;
	xdl_ov_fetch_next <= xdl_ov_fetch_reg;
	xdl_ov_fetch_init_next <= xdl_ov_fetch_init_reg;
	xdl_ov_text_next <= xdl_ov_text_reg;
	xdl_ov_hi_next <= xdl_ov_hi_reg;
	xdl_ov_lo_next <= xdl_ov_lo_reg;

	xdl_pixels_next <= xdl_pixels_reg;
	xdl_ptrans_next <= xdl_ptrans_reg;

	xdl_pixel_buffer_windex_next <= xdl_pixel_buffer_windex_reg;
	xdl_char_code_next <= xdl_char_code_reg;
	xdl_char_attr_next <= xdl_char_attr_reg;
	xdl_vcount_next <= xdl_vcount_reg;
	
	if blitter_pending_reg = '1' then
		blitter_vram_data_in_next <= vram_data_in;
		blitter_pending_next <= '0';
	end if;

	blitter_notify := false; -- Becomes true when there is a free slot for the blitter on this cycle
	xdl_or_blitter_notify := false;

	case dma_state_reg(3 downto 0) is
	when "0000" =>
		dma_state_next <= "0001";
		if xdl_ov_tlive_reg = '1' then
			vram_op_next <= "01";
			vram_addr_next <= std_logic_vector(xdl_ov_fetch_reg);
			xdl_ov_fetch_next <= xdl_ov_fetch_reg + 1;
		else
			xdl_or_blitter_notify := true;
		end if;
	when "0001" =>
		if (xdl_ov_tlive_reg = '1') then
			if xdl_ov_text_reg = '1' then
				xdl_char_code_next <= vram_data_in;
			else
				-- pixels 0,1
				xdl_ptrans_next(xdl_pixel_buffer_windex_reg) <= '0';
				xdl_ptrans_next(xdl_pixel_buffer_windex_reg+1) <= '0';
				if xdl_ov_hi_reg = '1' then
					xdl_pixels_next(xdl_pixel_buffer_windex_reg) <= "0000" & vram_data_in(7 downto 4);
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+1) <= "0000" & vram_data_in(3 downto 0);
					if vram_data_in(7 downto 4) = x"0" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg) <= not(no_trans_reg);
					end if;
					if vram_data_in(3 downto 0) = x"0" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+1) <= not(no_trans_reg);
					end if;
				else
					xdl_pixels_next(xdl_pixel_buffer_windex_reg) <= vram_data_in;
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+1) <= vram_data_in;
					if vram_data_in = x"00" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg) <= not(no_trans_reg);
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+1) <= not(no_trans_reg);
					end if;
				end if;
			end if;
		end if;
		if (memac_request_next = "01") then
			vram_op_next <= "01";
			if memac_check_next(0) = '1' then
				vram_addr_next <= mems_reg(6 downto 0) & memac_address(11 downto 0);
				case memc_reg(1 downto 0) is
				when "00" =>
					null;
				when "01" =>
					vram_addr_next(12) <= std_logic_vector(unsigned(memac_address(15 downto 12)) - unsigned(memc_reg(7 downto 4)))(0);
				when "10" =>
					vram_addr_next(13 downto 12) <= std_logic_vector(unsigned(memac_address(15 downto 12)) - unsigned(memc_reg(7 downto 4)))(1 downto 0);
				when "11" =>
					vram_addr_next(14 downto 12) <= std_logic_vector(unsigned(memac_address(15 downto 12)) - unsigned(memc_reg(7 downto 4)))(2 downto 0);
				end case;
			else -- memac_check_b = '1'
				vram_addr_next <= memb_reg(4 downto 0) & memac_address(13 downto 0);
			end if;
			dma_state_next(3) <= '1';
		else 
			dma_state_next(3) <= '0';
			xdl_or_blitter_notify := true;
		end if;
		dma_state_next(2 downto 0) <= "010";
	when "0010" | "1010" =>
		if dma_state_reg(3) = '1' then
			memac_data_next <= vram_data_in;
			memac_request_complete_next <= '1';
		end if;
		dma_state_next <= "0011";
		if (xdl_ov_tlive_reg = '1') and (xdl_ov_lo_reg = '0') then
			vram_op_next <= "01";
			vram_addr_next <= std_logic_vector(xdl_ov_fetch_reg);
			xdl_ov_fetch_next <= xdl_ov_fetch_reg + 1;
		else
			xdl_or_blitter_notify := true;
		end if;
	when "0011" =>
		if (xdl_ov_tlive_reg = '1') then
			if xdl_ov_text_reg = '1' then
				xdl_char_attr_next <= vram_data_in;
			else
				-- pixels 2,3
				xdl_ptrans_next(xdl_pixel_buffer_windex_reg+2) <= '0';
				xdl_ptrans_next(xdl_pixel_buffer_windex_reg+3) <= '0';
				if xdl_ov_hi_reg = '1' then
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+2) <= "0000" & vram_data_in(7 downto 4);
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+3) <= "0000" & vram_data_in(3 downto 0);
					if vram_data_in(7 downto 4) = x"0" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+2) <= not(no_trans_reg);
					end if;
					if vram_data_in(3 downto 0) = x"0" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+3) <= not(no_trans_reg);
					end if;
				elsif xdl_ov_lo_reg = '1' then
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+2) <= xdl_pixels_reg(xdl_pixel_buffer_windex_reg);
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+3) <= xdl_pixels_reg(xdl_pixel_buffer_windex_reg+1);
					xdl_ptrans_next(xdl_pixel_buffer_windex_reg+2) <= xdl_ptrans_reg(xdl_pixel_buffer_windex_reg);
					xdl_ptrans_next(xdl_pixel_buffer_windex_reg+3) <= xdl_ptrans_reg(xdl_pixel_buffer_windex_reg+1);
				else
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+2) <= vram_data_in;
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+3) <= vram_data_in;
					if vram_data_in = x"00" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+2) <= not(no_trans_reg);
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+3) <= not(no_trans_reg);
					end if;
				end if;
			end if;
		end if;
		if (memac_request_next = "11") then
			vram_op_next <= "11";
			vram_data_next <= memac_data_in;
			if memac_check_next(0) = '1' then
				vram_addr_next <= mems_reg(6 downto 0) & memac_address(11 downto 0);
				case memc_reg(1 downto 0) is
				when "00" =>
					null;
				when "01" =>
					vram_addr_next(12) <= std_logic_vector(unsigned(memac_address(15 downto 12)) - unsigned(memc_reg(7 downto 4)))(0);
				when "10" =>
					vram_addr_next(13 downto 12) <= std_logic_vector(unsigned(memac_address(15 downto 12)) - unsigned(memc_reg(7 downto 4)))(1 downto 0);
				when "11" =>
					vram_addr_next(14 downto 12) <= std_logic_vector(unsigned(memac_address(15 downto 12)) - unsigned(memc_reg(7 downto 4)))(2 downto 0);
				end case;
			else -- memac_check_b = '1'
				vram_addr_next <= memb_reg(4 downto 0) & memac_address(13 downto 0);
			end if;
			dma_state_next(3) <= '1';
		else 
			dma_state_next(3) <= '0';
			xdl_or_blitter_notify := true;
		end if;
		dma_state_next(2 downto 0) <= "100";
	when "0100" | "1100"=>
		if dma_state_reg(3) = '1' then
			memac_request_complete_next <= '1';
		end if;
		dma_state_next <= "0101";
		if (xdl_ov_tlive_reg = '1') then
			if xdl_ov_text_reg = '1' then
				vram_op_next <= "01";
				vram_addr_next(18 downto 11) <= xdl_chbase_reg;
				vram_addr_next(10 downto 3) <= xdl_char_code_reg;
				vram_addr_next(2 downto 0) <= std_logic_vector(xdl_ov_vcount_reg);
			else
				vram_op_next <= "01";
				vram_addr_next <= std_logic_vector(xdl_ov_fetch_reg);
				xdl_ov_fetch_next <= xdl_ov_fetch_reg + 1;
			end if;
		else
			xdl_or_blitter_notify := true;
		end if;
	when "0101" =>
		if (xdl_ov_tlive_reg = '1') then
			if (xdl_ov_text_reg = '1') then
				for pi in 0 to 7 loop
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+pi)(7) <= not(vram_data_in(7-pi));
					if (xdl_char_attr_reg(7) = '0') and (vram_data_in(7-pi) = '0') then
						xdl_pixels_next(xdl_pixel_buffer_windex_reg+pi)(6 downto 0) <= (others => '0');
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+pi) <= not(no_trans_reg);
					else
						xdl_pixels_next(xdl_pixel_buffer_windex_reg+pi)(6 downto 0) <= xdl_char_attr_reg(6 downto 0);
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+pi) <= '0';
					end if;
				end loop;
				if xdl_pixel_buffer_windex_reg = 8 then
					xdl_pixel_buffer_windex_next <= 0;
				else
					xdl_pixel_buffer_windex_next <= 8;
				end if;
			else
				-- pixels 4,5
				xdl_ptrans_next(xdl_pixel_buffer_windex_reg+4) <= '0';
				xdl_ptrans_next(xdl_pixel_buffer_windex_reg+5) <= '0';
				if xdl_ov_hi_reg = '1' then
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+4) <= "0000" & vram_data_in(7 downto 4);
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+5) <= "0000" & vram_data_in(3 downto 0);
					if vram_data_in(7 downto 4) = x"0" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+4) <= not(no_trans_reg);
					end if;
					if vram_data_in(3 downto 0) = x"0" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+5) <= not(no_trans_reg);
					end if;
				else
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+4) <= vram_data_in;
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+5) <= vram_data_in;
					if vram_data_in = x"00" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+4) <= not(no_trans_reg);
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+5) <= not(no_trans_reg);
					end if;
				end if;
			end if;
		end if;
		xdl_or_blitter_notify := true;
		dma_state_next <= "0110";
	when "0110" =>
		if (xdl_ov_tlive_reg = '1') and (xdl_ov_text_reg = '0') and (xdl_ov_lo_reg = '0') then
			vram_op_next <= "01";
			vram_addr_next <= std_logic_vector(xdl_ov_fetch_reg);
			xdl_ov_fetch_next <= xdl_ov_fetch_reg + 1;
		else
			xdl_or_blitter_notify := true;
		end if;
		dma_state_next <= "0111";
	when "0111" =>
		if xdl_ov_tlive_reg = '1' then
			if xdl_ov_text_reg = '0' then
				-- pixels 6,7
				xdl_ptrans_next(xdl_pixel_buffer_windex_reg+6) <= '0';
				xdl_ptrans_next(xdl_pixel_buffer_windex_reg+7) <= '0';
				if xdl_ov_hi_reg = '1' then
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+6) <= "0000" & vram_data_in(7 downto 4);
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+7) <= "0000" & vram_data_in(3 downto 0);
					if vram_data_in(7 downto 4) = x"0" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+6) <= not(no_trans_reg);
					end if;
					if vram_data_in(3 downto 0) = x"0" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+7) <= not(no_trans_reg);
					end if;
				elsif xdl_ov_lo_reg = '1' then
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+6) <= xdl_pixels_reg(xdl_pixel_buffer_windex_reg+4);
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+7) <= xdl_pixels_reg(xdl_pixel_buffer_windex_reg+5);
					xdl_ptrans_next(xdl_pixel_buffer_windex_reg+6) <= xdl_ptrans_reg(xdl_pixel_buffer_windex_reg+4);
					xdl_ptrans_next(xdl_pixel_buffer_windex_reg+7) <= xdl_ptrans_reg(xdl_pixel_buffer_windex_reg+5);
				else
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+6) <= vram_data_in;
					xdl_pixels_next(xdl_pixel_buffer_windex_reg+7) <= vram_data_in;
					if vram_data_in = x"00" then
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+6) <= not(no_trans_reg);
						xdl_ptrans_next(xdl_pixel_buffer_windex_reg+7) <= not(no_trans_reg);
					end if;
				end if;
				if xdl_pixel_buffer_windex_reg = 8 then
					xdl_pixel_buffer_windex_next <= 0;
				else
					xdl_pixel_buffer_windex_next <= 8;
				end if;
			end if;
		end if;
		xdl_or_blitter_notify := true;
		dma_state_next <= "1111";
	when others =>
		vram_op_next <= "00";
	end case;

	if (vsync = '1') then
		if pal = '1' then
			xdl_vdelay_next <= 42;
		elsif ntsc_fix = '1' then
			xdl_vdelay_next <= 12;
		else
			-- Account for the PAL/NTSC bug in the original implementation
			-- This is purposely 1 scanline too low
			xdl_vdelay_next <= 13;
		end if;
		xdl_active_next <= xdl_enabled_reg;
		xdl_read_state_next <= 0;
	end if;

	if (xdl_field_end2 = '1') and (xdl_active_reg = '1') then
		if xdl_vdelay_reg = 0 then
			if xdl_map_active_reg = '1' then
				if xdl_map_vcount_reg = xdl_map_ht_reg then
					xdl_map_vcount_next <= "00000";
					xdl_map_read_next <= '1';
					xdl_map_read_count_next <= (others => '0');
					xdl_map_fetch_next <= xdl_map_fetch_init_reg;
					xdl_map_fetch_init_next <= xdl_map_fetch_init_reg + xdl_mapaddr_step_reg;
				else
					xdl_map_vcount_next <= xdl_map_vcount_reg + 1;
				end if;
			end if;
			if xdl_ov_active_reg = '1' then
				xdl_pixel_buffer_windex_next <= 0;
				if xdl_ov_vcount_reg = "111" then
					if xdl_ov_text_reg = '1' then
						xdl_ov_vcount_next <= "000";
					end if;
					xdl_ov_fetch_next <= xdl_ovaddr_reg + xdl_ovaddr_step_reg;
					xdl_ov_fetch_init_next <= xdl_ovaddr_reg + xdl_ovaddr_step_reg;
					xdl_ovaddr_next <= xdl_ovaddr_reg + xdl_ovaddr_step_reg;
				else
					xdl_ov_fetch_next <= xdl_ov_fetch_init_reg;
					xdl_ov_vcount_next <= xdl_ov_vcount_reg + 1;
				end if;
			end if;
			if xdl_rptl_reg = x"00" then
				if xdl_cmd_reg(15) = '0' then
					xdl_read_state_next <= 1;
				else
					xdl_active_next <= '0'; -- XDL vanishes for the rest of the screen
					xdl_map_active_next <= '0';
					xdl_ov_active_next <= '0';
				end if;
			else
				xdl_rptl_next <= xdl_rptl_reg - 1;
				xdl_read_state_next <= 23; -- say we already read the XDL
			end if;
			if xdl_vcount_reg = 239 then
				xdl_active_next <= '0'; -- XDL vanishes for the rest of the screen
				xdl_map_active_next <= '0';
				xdl_ov_active_next <= '0';
			else
				xdl_vcount_next <= xdl_vcount_reg + 1;
			end if;
		else
			if xdl_vdelay_reg = 1 then
				xdl_active_next <= xdl_enabled_reg;
				xdl_rptl_next <= x"00";
				xdl_fetch_next <= xdl_addr_reg;
				xdl_ovscr_h_next <= "000";
				xdl_ovscr_v_next <= "000";
				xdl_mapscr_h_next <= "00000";
				xdl_mapscr_v_next <= "00000";
				xdl_map_wd_next <= "00111";
				xdl_map_ht_next <= "00111";
				xdl_ov_size_next <= "01";
				xdl_ov_pal_next <= "01";
				xdl_pf_pal_next <= "00";
				xdl_gp_next <= (others => '1');
				xdl_cmd_next <= (others => '0');
				xdl_map_active_next <= '0';
				xdl_ov_active_next <= '0';
				xdl_vcount_next <= 0;
				xdl_read_state_next <= 1;
			end if;
			xdl_vdelay_next <= xdl_vdelay_reg - 1;
		end if;
	end if;

	xdl_map_buffer_wren <= '0';
	if xdl_pending_reg = '1' then
		xdl_pending_next <= '0';
		case xdl_read_state_reg is
			when 2 => xdl_cmd_next(7 downto 0) <= vram_data_in;
			when 3 => xdl_cmd_next(15 downto 8) <= vram_data_in;
			when 4 => xdl_rptl_next <= unsigned(vram_data_in);
			when 5 => xdl_ovaddr_next(7 downto 0) <= unsigned(vram_data_in);
			when 6 => xdl_ovaddr_next(15 downto 8) <= unsigned(vram_data_in);
			when 7 => xdl_ovaddr_next(18 downto 16) <= unsigned(vram_data_in(2 downto 0));
			when 8 => xdl_ovaddr_step_next(7 downto 0) <= unsigned(vram_data_in);
			when 9 => xdl_ovaddr_step_next(11 downto 8) <= unsigned(vram_data_in(3 downto 0));
			when 10 => xdl_ovscr_h_next <= unsigned(vram_data_in(2 downto 0));
			when 11 => xdl_ovscr_v_next <= unsigned(vram_data_in(2 downto 0));
			when 12 => xdl_chbase_next <= vram_data_in;
			when 13 => xdl_mapaddr_next(7 downto 0) <= unsigned(vram_data_in);
			when 14 => xdl_mapaddr_next(15 downto 8) <= unsigned(vram_data_in);
			when 15 => xdl_mapaddr_next(18 downto 16) <= unsigned(vram_data_in(2 downto 0));
			when 16 => xdl_mapaddr_step_next(7 downto 0) <= unsigned(vram_data_in);
			when 17 => xdl_mapaddr_step_next(11 downto 8) <= unsigned(vram_data_in(3 downto 0));
			when 18 => xdl_mapscr_h_next <= unsigned(vram_data_in(4 downto 0));
			when 19 => xdl_mapscr_v_next <= unsigned(vram_data_in(4 downto 0));
			when 20 => xdl_map_wd_next <= unsigned(vram_data_in(4 downto 0)); -- TODO ? What to do if the value is below 7 (=not allowed)?
			when 21 => xdl_map_ht_next <= unsigned(vram_data_in(4 downto 0));
			when 22 =>
				xdl_ov_size_next <= vram_data_in(1 downto 0);
				xdl_ov_pal_next <= vram_data_in(5 downto 4);
				xdl_pf_pal_next <= vram_data_in(7 downto 6);
			when 23 =>
				xdl_gp_next <= vram_data_in;
			when 24 =>
				xdl_map_buffer_data_in_next <= vram_data_in;
				xdl_map_buffer_wren <= '1';
			when others =>
		end case;
	end if;

	if xdl_read_state_reg = 22 then
		if (xdl_cmd_reg(3) = '1') or (xdl_cmd_reg(9) = '1') then
			xdl_map_fetch_next <= xdl_mapaddr_reg;
			xdl_map_fetch_init_next <= xdl_mapaddr_reg + xdl_mapaddr_step_reg;
			xdl_map_read_next <= '1';
			xdl_map_read_count_next <= (others => '0');
			xdl_map_active_next <= '1';
			xdl_map_vcount_next <= xdl_mapscr_v_reg;
		end if;
		if xdl_cmd_reg(4) = '1' then
			xdl_map_read_next <= '0';
			xdl_map_active_next <= '0';
		end if;
		if xdl_cmd_reg(6) = '1' then
			xdl_ov_fetch_next <= xdl_ovaddr_reg;
			xdl_ov_fetch_init_next <= xdl_ovaddr_reg;
		end if;
		if (xdl_cmd_reg(0) xor xdl_cmd_reg(1)) = '1' then
			xdl_ov_hi_next <= xdl_cmd_reg(12);
			xdl_ov_lo_next <= xdl_cmd_reg(13);
			xdl_ov_active_next <= '1';
			xdl_ov_text_next <= xdl_cmd_reg(0);
			if xdl_cmd_reg(0) = '1' then
				xdl_ov_vcount_next <= xdl_ovscr_v_reg;
			else
				xdl_ov_vcount_next <= "111";
			end if;
		end if;
		-- TODO Docs say forbidden for lowres & highres at the same time, but what does it mean? Altirra disables the mode altogether
		if (xdl_cmd_reg(2) = '1') or ((xdl_cmd_reg(0) and xdl_cmd_reg(1)) = '1') or ((xdl_cmd_reg(12) and xdl_cmd_reg(13)) = '1') then
			xdl_ov_active_next <= '0';
		end if;
	end if;

	xdl_read_required := false;
	if xdl_or_blitter_notify then
		if xdl_read_state_reg > 0 and xdl_read_state_reg < 24 then
			xdl_read_state_next <= xdl_read_state_reg + 1;
		end if;
		case xdl_read_state_reg is
			when 1 | 2 => xdl_read_required := true;
			when 3 => if xdl_cmd_reg(5) = '1' then xdl_read_required := true; end if;
			when 4 | 5 | 6 | 7 | 8 => if xdl_cmd_reg(6) = '1' then xdl_read_required := true; end if;
			when 9 | 10 => if xdl_cmd_reg(7) = '1' then xdl_read_required := true; end if;
			when 11 => if xdl_cmd_reg(8) = '1' then xdl_read_required := true; end if;
			when 12 | 13 | 14 | 15 | 16 => if xdl_cmd_reg(9) = '1' then xdl_read_required := true; end if;
			when 17 | 18 | 19 | 20 => if xdl_cmd_reg(10) = '1' then xdl_read_required := true; end if;
			when 21 | 22 => if xdl_cmd_reg(11) = '1' then xdl_read_required := true; end if;
			when 23 =>
				if xdl_map_read_reg = '0' then
					xdl_read_state_next <= 0;
				else
					xdl_read_required := true;
				end if;
			when 24 =>
				if xdl_map_read_count_reg = x"AB" then -- 171 = 43*4 - 1
					xdl_map_read_next <= '0';
					xdl_read_state_next <= 0;
				else
					xdl_read_required := true;
					xdl_map_read_count_next <= xdl_map_read_count_reg + 1;
				end if;
			when others =>
		end case;
		if xdl_read_required then
			if xdl_read_state_reg < 23 then
				vram_addr_next <= xdl_fetch_reg;
				xdl_fetch_next <= std_logic_vector(unsigned(xdl_fetch_reg) + 1);
			else
				vram_addr_next <= std_logic_vector(xdl_map_fetch_reg);
				xdl_map_fetch_next <= xdl_map_fetch_reg + 1;
			end if;
			vram_op_next <= "01";
			xdl_pending_next <= '1';
		else
			blitter_notify := true;
		end if;
	end if;

	if blitter_notify and (or_reduce(blitter_status) = '1') then
		blitter_enable <= '1';
		vram_addr_next <= blitter_vram_address;
		vram_op_next <= blitter_vram_wren & '1';
		vram_data_next <= blitter_vram_data;
		-- If we are reading, we need to capture the data for the blitter
		-- on the next cycle
		blitter_pending_next <= not(blitter_vram_wren);
	end if;
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