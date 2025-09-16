library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

entity VBXE_blitter is
port (
	clk : in std_logic;
	reset_n : in std_logic;
	soft_reset : in std_logic;
	blitter_enable : in std_logic;
	blitter_start_request : in std_logic;
	blitter_stop_request : in std_logic;
	blitter_address : in std_logic_vector(18 downto 0);
	blitter_vram_data_in : in std_logic_vector(7 downto 0);
	blitter_vram_wren : out std_logic;
	blitter_vram_data : out std_logic_vector(7 downto 0);
	blitter_vram_address : out std_logic_vector(18 downto 0);
	blitter_status : out std_logic_vector(1 downto 0);
	blitter_collision : out std_logic_vector(7 downto 0);
	blitter_irq : out std_logic;
	blitter_irqc : in std_logic
);
end VBXE_blitter;

architecture vhdl of VBXE_blitter is

signal blitter_src_address_next : std_logic_vector(18 downto 0);
signal blitter_src_address_reg : std_logic_vector(18 downto 0);

signal blitter_src_step_y_reg : unsigned(18 downto 0);
signal blitter_src_step_y_next : unsigned(18 downto 0);

signal blitter_src_step_x_reg : unsigned(18 downto 0);
signal blitter_src_step_x_next : unsigned(18 downto 0);

signal blitter_dest_address_next : std_logic_vector(18 downto 0);
signal blitter_dest_address_reg : std_logic_vector(18 downto 0);

signal blitter_dest_step_y_reg : unsigned(18 downto 0);
signal blitter_dest_step_y_next : unsigned(18 downto 0);

signal blitter_dest_step_x_reg : unsigned(18 downto 0);
signal blitter_dest_step_x_next : unsigned(18 downto 0);

signal blitter_width_reg : std_logic_vector(8 downto 0);
signal blitter_width_next : std_logic_vector(8 downto 0);

signal blitter_height_reg : std_logic_vector(7 downto 0);
signal blitter_height_next : std_logic_vector(7 downto 0);

signal blitter_and_mask_reg : std_logic_vector(7 downto 0);
signal blitter_and_mask_next : std_logic_vector(7 downto 0);

signal blitter_xor_mask_reg : std_logic_vector(7 downto 0);
signal blitter_xor_mask_next : std_logic_vector(7 downto 0);

signal blitter_collision_mask_reg : std_logic_vector(7 downto 0);
signal blitter_collision_mask_next : std_logic_vector(7 downto 0);

signal blitter_zoom_x_reg : std_logic_vector(2 downto 0);
signal blitter_zoom_x_next : std_logic_vector(2 downto 0);

signal blitter_zoom_y_reg : std_logic_vector(2 downto 0);
signal blitter_zoom_y_next : std_logic_vector(2 downto 0);

signal blitter_pattern_reg : std_logic;
signal blitter_pattern_next : std_logic;

signal blitter_pattern_count_reg : std_logic_vector(5 downto 0);
signal blitter_pattern_count_next : std_logic_vector(5 downto 0);

signal blitter_next_reg : std_logic;
signal blitter_next_next : std_logic;

signal blitter_mode_reg : std_logic_vector(2 downto 0);
signal blitter_mode_next : std_logic_vector(2 downto 0);

signal blitter_load_address_reg : std_logic_vector(18 downto 0);
signal blitter_load_address_next : std_logic_vector(18 downto 0);

signal blitter_state_reg : std_logic_vector(5 downto 0);
signal blitter_state_next : std_logic_vector(5 downto 0);

signal blitter_src_current_next : std_logic_vector(18 downto 0);
signal blitter_src_current_reg : std_logic_vector(18 downto 0);

signal blitter_dest_current_next : std_logic_vector(18 downto 0);
signal blitter_dest_current_reg : std_logic_vector(18 downto 0);

--signal blitter_vram_wren_reg : std_logic;
--signal blitter_vram_wren_next : std_logic;

signal blitter_vram_data_reg : std_logic_vector(7 downto 0);
signal blitter_vram_data_next : std_logic_vector(7 downto 0);

signal blitter_vram_address_reg : std_logic_vector(18 downto 0);
signal blitter_vram_address_next : std_logic_vector(18 downto 0);

signal blitter_collision_reg : std_logic_vector(7 downto 0);
signal blitter_collision_next : std_logic_vector(7 downto 0);

signal blitter_irq_reg : std_logic;
signal blitter_irq_next : std_logic;

signal blitter_x_reg : std_logic_vector(8 downto 0);
signal blitter_x_next : std_logic_vector(8 downto 0);

signal blitter_y_reg : std_logic_vector(7 downto 0);
signal blitter_y_next : std_logic_vector(7 downto 0);

signal blitter_rep_x_reg : std_logic_vector(2 downto 0);
signal blitter_rep_x_next : std_logic_vector(2 downto 0);

signal blitter_rep_y_reg : std_logic_vector(2 downto 0);
signal blitter_rep_y_next : std_logic_vector(2 downto 0);

signal blitter_pattern_current_reg : std_logic_vector(5 downto 0);
signal blitter_pattern_current_next : std_logic_vector(5 downto 0);

begin

-- outputs

blitter_vram_address <= blitter_vram_address_next;
blitter_vram_data <= blitter_vram_data_next;
--blitter_vram_wren <= blitter_vram_wren_next;
blitter_status <= (not(blitter_state_reg(5)) and or_reduce(blitter_state_reg(4 downto 0))) & blitter_state_reg(5);
blitter_collision <= blitter_collision_reg; -- TODO or _next?
blitter_irq <= blitter_irq_reg;

process(clk, reset_n)
begin
	if (reset_n = '0') then
		blitter_src_address_reg <= (others => '0');
		blitter_src_step_y_reg <= (others => '0');
		blitter_src_step_x_reg <= (others => '0');
		blitter_dest_address_reg <= (others => '0');
		blitter_dest_step_y_reg <= (others => '0');
		blitter_dest_step_x_reg <= (others => '0');
		blitter_width_reg <= (others => '0');
		blitter_height_reg <= (others => '0');
		blitter_and_mask_reg <= (others => '0');
		blitter_xor_mask_reg <= (others => '0');
		blitter_collision_mask_reg <= (others => '0');
		blitter_zoom_x_reg <= (others => '0');
		blitter_zoom_y_reg <= (others => '0');
		blitter_pattern_reg <= '0';
		blitter_pattern_count_reg <= (others => '0');
		blitter_next_reg <= '0';
		blitter_mode_reg <= (others => '0');

		blitter_load_address_reg <= (others => '0');
		blitter_state_reg <= (others => '0');

		blitter_src_current_reg <= (others => 'U');
		blitter_dest_current_reg <= (others => 'U');

		--blitter_vram_wren_reg <= '0';
		blitter_vram_data_reg <= (others => '0');
		blitter_vram_address_reg <= (others => '0');
		blitter_collision_reg  <= (others => 'U');
		blitter_irq_reg <= '0';
		blitter_x_reg <= (others => '0');
		blitter_y_reg <= (others => '0');
		blitter_rep_x_reg <= (others => '0');
		blitter_rep_y_reg <= (others => '0');
		blitter_pattern_current_reg <= (others => '0');
	elsif rising_edge(clk) then
		blitter_src_address_reg <= blitter_src_address_next;
		blitter_src_step_y_reg <= blitter_src_step_y_next;
		blitter_src_step_x_reg <= blitter_src_step_x_next;
		blitter_dest_address_reg <= blitter_dest_address_next;
		blitter_dest_step_y_reg <= blitter_dest_step_y_next;
		blitter_dest_step_x_reg <= blitter_dest_step_x_next;
		blitter_width_reg <= blitter_width_next;
		blitter_height_reg <= blitter_height_next;
		blitter_and_mask_reg <= blitter_and_mask_next;
		blitter_xor_mask_reg <= blitter_xor_mask_next;
		blitter_collision_mask_reg <= blitter_collision_mask_next;
		blitter_zoom_x_reg <= blitter_zoom_x_next;
		blitter_zoom_y_reg <= blitter_zoom_y_next;
		blitter_pattern_reg <= blitter_pattern_next;
		blitter_pattern_count_reg <= blitter_pattern_count_next;
		blitter_next_reg <= blitter_next_next;
		blitter_mode_reg <= blitter_mode_next;

		blitter_load_address_reg <= blitter_load_address_next;
		blitter_state_reg <= blitter_state_next;

		blitter_src_current_reg <= blitter_src_current_next;
		blitter_dest_current_reg <= blitter_dest_current_next;

		--blitter_vram_wren_reg <= blitter_vram_wren_next;
		blitter_vram_data_reg <= blitter_vram_data_next;
		blitter_vram_address_reg <= blitter_vram_address_next;
		blitter_collision_reg  <= blitter_collision_next;
		blitter_irq_reg <= blitter_irq_next;
		blitter_x_reg <= blitter_x_next;
		blitter_y_reg <= blitter_y_next;
		blitter_rep_x_reg <= blitter_rep_x_next;
		blitter_rep_y_reg <= blitter_rep_y_next;
		blitter_pattern_current_reg <= blitter_pattern_current_next;
	end if;
end process;

---- main process

process(soft_reset,
	blitter_load_address_reg,blitter_state_reg,blitter_src_address_reg,blitter_src_step_y_reg,blitter_src_step_x_reg,
	blitter_dest_address_reg,blitter_dest_step_y_reg,blitter_dest_step_x_reg,blitter_width_reg,blitter_height_reg,
	blitter_and_mask_reg,blitter_xor_mask_reg,blitter_collision_mask_reg,blitter_zoom_x_reg,blitter_zoom_y_reg,
	blitter_pattern_reg,blitter_pattern_count_reg,blitter_next_reg,blitter_mode_reg,
	blitter_vram_data_reg,blitter_vram_address_reg,blitter_vram_data_in,blitter_start_request,blitter_stop_request,
	blitter_address,blitter_src_current_reg,blitter_dest_current_reg,blitter_enable,blitter_collision_reg,blitter_irq_reg,blitter_irqc,
	blitter_x_reg,blitter_y_reg,blitter_rep_x_reg,blitter_rep_y_reg,blitter_pattern_current_reg
)
begin

	blitter_load_address_next <= blitter_load_address_reg;
	blitter_state_next <= blitter_state_reg;

	blitter_src_address_next <= blitter_src_address_reg;
	blitter_src_step_y_next <= blitter_src_step_y_reg;
	blitter_src_step_x_next <= blitter_src_step_x_reg;
	blitter_dest_address_next <= blitter_dest_address_reg;
	blitter_dest_step_y_next <= blitter_dest_step_y_reg;
	blitter_dest_step_x_next <= blitter_dest_step_x_reg;
	blitter_width_next <= blitter_width_reg;
	blitter_height_next <= blitter_height_reg;
	blitter_and_mask_next <= blitter_and_mask_reg;
	blitter_xor_mask_next <= blitter_xor_mask_reg;
	blitter_collision_mask_next <= blitter_collision_mask_reg;
	blitter_zoom_x_next <= blitter_zoom_x_reg;
	blitter_zoom_y_next <= blitter_zoom_y_reg;
	blitter_pattern_next <= blitter_pattern_reg;
	blitter_pattern_count_next <= blitter_pattern_count_reg;
	blitter_next_next <= blitter_next_reg;
	blitter_mode_next <= blitter_mode_reg;

	blitter_vram_wren <= '0';
	--blitter_vram_wren_next <= blitter_vram_wren_reg; -- TODO does not need to be register? Seems so for now...
	blitter_vram_data_next <= blitter_vram_data_reg;
	blitter_vram_address_next <= blitter_vram_address_reg;

	blitter_src_current_next <= blitter_src_current_reg;
	blitter_dest_current_next <= blitter_dest_current_reg;

	blitter_collision_next <= blitter_collision_reg;
	blitter_irq_next <= blitter_irq_reg;
	
	blitter_x_next <= blitter_x_reg;
	blitter_y_next <= blitter_y_reg;
	blitter_rep_x_next <= blitter_rep_x_reg;
	blitter_rep_y_next <= blitter_rep_y_reg;
	blitter_pattern_current_next <= blitter_pattern_current_reg;
	
	if blitter_enable = '1' then
		if (blitter_state_reg /= "000000") then
			if blitter_state_reg(5) = '1' then -- init

				blitter_vram_address_next <= std_logic_vector(unsigned(blitter_vram_address_reg) + 1);

				case blitter_state_reg(4 downto 0) is
				when "00000" =>
					blitter_src_address_next(7 downto 0) <= blitter_vram_data_in;
					blitter_state_next <= "100001";
				when "00001" =>
					blitter_src_address_next(15 downto 8) <= blitter_vram_data_in;
					blitter_state_next <= "100010";
				when "00010" =>
					blitter_src_address_next(18 downto 16) <= blitter_vram_data_in(2 downto 0);
					blitter_state_next <= "100011";
				when "00011" =>
					blitter_src_step_y_next(7 downto 0) <= unsigned(blitter_vram_data_in);
					blitter_state_next <= "100100";
				when "00100" =>
					blitter_src_step_y_next(12 downto 8) <= unsigned(blitter_vram_data_in(4 downto 0));
					blitter_src_step_y_next(18 downto 13) <= (others => blitter_vram_data_in(4));
					blitter_state_next <= "100101";
				when "00101" =>
					blitter_src_step_x_next(7 downto 0) <= unsigned(blitter_vram_data_in);
					blitter_src_step_x_next(18 downto 8) <= (others => blitter_vram_data_in(7));
					blitter_state_next <= "100110";
				when "00110" =>
					blitter_dest_address_next(7 downto 0) <= blitter_vram_data_in;
					blitter_state_next <= "100111";
				when "00111" =>
					blitter_dest_address_next(15 downto 8) <= blitter_vram_data_in;
					blitter_state_next <= "101000";
				when "01000" =>
					blitter_dest_address_next(18 downto 16) <= blitter_vram_data_in(2 downto 0);
					blitter_state_next <= "101001";
				when "01001" =>
					blitter_dest_step_y_next(7 downto 0) <= unsigned(blitter_vram_data_in);
					blitter_state_next <= "101010";
				when "01010" =>
					blitter_dest_step_y_next(12 downto 8) <= unsigned(blitter_vram_data_in(4 downto 0));
					blitter_dest_step_y_next(18 downto 13) <= (others => blitter_vram_data_in(4));
					blitter_state_next <= "101011";
				when "01011" =>
					blitter_dest_step_x_next(7 downto 0) <= unsigned(blitter_vram_data_in);
					blitter_dest_step_x_next(18 downto 8) <= (others => blitter_vram_data_in(7));
					blitter_state_next <= "101100";
				when "01100" =>
					blitter_width_next(7 downto 0) <= blitter_vram_data_in;
					blitter_state_next <= "101101";
				when "01101" =>
					blitter_width_next(8) <= blitter_vram_data_in(0);
					blitter_state_next <= "101110";
				when "01110" =>
					blitter_height_next <= blitter_vram_data_in;
					blitter_state_next <= "101111";
				when "01111" =>
					blitter_and_mask_next <= blitter_vram_data_in;
					blitter_state_next <= "110000";
				when "10000" =>
					blitter_xor_mask_next <= blitter_vram_data_in;
					blitter_state_next <= "110001";
				when "10001" =>
					blitter_collision_mask_next <= blitter_vram_data_in;
					blitter_state_next <= "110010";
				when "10010" =>
					blitter_zoom_x_next <= blitter_vram_data_in(2 downto 0);
					blitter_zoom_y_next <= blitter_vram_data_in(6 downto 4);
					blitter_state_next <= "110011";
				when "10011" =>
					blitter_pattern_next <= blitter_vram_data_in(7);
					blitter_pattern_count_next <= blitter_vram_data_in(5 downto 0);
					blitter_state_next <= "110100";
				when "10100" =>
					blitter_next_next <= blitter_vram_data_in(3);
					blitter_mode_next <= blitter_vram_data_in(2 downto 0);
					blitter_state_next <= "000001";
					blitter_src_current_next <= blitter_src_address_reg;
					blitter_dest_current_next <= blitter_dest_address_reg;
					blitter_x_next <= blitter_width_reg;
					blitter_y_next <= blitter_height_reg;
					blitter_rep_x_next <= blitter_zoom_x_reg;
					blitter_rep_y_next <= blitter_zoom_y_reg;
					blitter_pattern_current_next <= blitter_pattern_count_reg;
					-- blitter_vram_address_next <= ???
				when others =>
				end case;
			else
				-- blitter running
				case blitter_state_reg(4 downto 0) is
				when "00001" =>
					-- When the blitter is done
					if blitter_next_reg = '1' then
						blitter_load_address_next <= std_logic_vector(unsigned(blitter_load_address_reg) + 21);
						blitter_vram_address_next <= blitter_load_address_reg;
						blitter_state_next <= "100000";
						-- blitter_vram_wren_next <= '0';
					else
						blitter_state_next <= "000000";
						blitter_irq_next <= '1';
					end if;
				when others =>
				end case;
			end if;
		end if;
	end if;

	if (blitter_stop_request = '1') or (soft_reset = '1') then
		blitter_state_next <= "000000";
	elsif blitter_start_request = '1' then
		blitter_state_next <= "100000";
		blitter_load_address_next <= std_logic_vector(unsigned(blitter_address) + 21);
		blitter_vram_address_next <= blitter_address;
		blitter_collision_next <= X"00";
		-- blitter_vram_wren_next <= '0';
	end if;
	if (blitter_irqc = '1') or (soft_reset = '1') then
		blitter_irq_next <= '0';
	end if;

end process;

end vhdl;