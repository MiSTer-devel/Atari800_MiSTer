--------------------------------------------------------------------------
-- (c) 2025 Wojciech Mostowski, firstname.lastname at gmail.com
--
-- The VBXE blitter.
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

signal blitter_src_address_next : unsigned(18 downto 0);
signal blitter_src_address_reg : unsigned(18 downto 0);

signal blitter_src_step_y_reg : unsigned(18 downto 0);
signal blitter_src_step_y_next : unsigned(18 downto 0);

signal blitter_src_step_x_reg : unsigned(18 downto 0);
signal blitter_src_step_x_next : unsigned(18 downto 0);

signal blitter_dest_address_next : unsigned(18 downto 0);
signal blitter_dest_address_reg : unsigned(18 downto 0);

signal blitter_dest_step_y_reg : unsigned(18 downto 0);
signal blitter_dest_step_y_next : unsigned(18 downto 0);

signal blitter_dest_step_x_reg : unsigned(18 downto 0);
signal blitter_dest_step_x_next : unsigned(18 downto 0);

signal blitter_width_reg : unsigned(8 downto 0);
signal blitter_width_next : unsigned(8 downto 0);

signal blitter_height_reg : unsigned(7 downto 0);
signal blitter_height_next : unsigned(7 downto 0);

signal blitter_and_mask_reg : std_logic_vector(7 downto 0);
signal blitter_and_mask_next : std_logic_vector(7 downto 0);

signal blitter_xor_mask_reg : std_logic_vector(7 downto 0);
signal blitter_xor_mask_next : std_logic_vector(7 downto 0);

signal blitter_collision_mask_reg : std_logic_vector(7 downto 0);
signal blitter_collision_mask_next : std_logic_vector(7 downto 0);

signal blitter_zoom_x_reg : unsigned(2 downto 0);
signal blitter_zoom_x_next : unsigned(2 downto 0);

signal blitter_zoom_y_reg : unsigned(2 downto 0);
signal blitter_zoom_y_next : unsigned(2 downto 0);

signal blitter_pattern_reg : std_logic;
signal blitter_pattern_next : std_logic;

signal blitter_pattern_count_reg : unsigned(5 downto 0);
signal blitter_pattern_count_next : unsigned(5 downto 0);

signal blitter_next_reg : std_logic;
signal blitter_next_next : std_logic;

--signal blitter_mode_reg : std_logic_vector(2 downto 0);
--signal blitter_mode_next : std_logic_vector(2 downto 0);

signal blitter_mode_reg : integer range 0 to 7;
signal blitter_mode_next : integer range 0 to 7;

signal blitter_load_address_reg : std_logic_vector(18 downto 0);
signal blitter_load_address_next : std_logic_vector(18 downto 0);

signal blitter_state_reg : std_logic_vector(5 downto 0);
signal blitter_state_next : std_logic_vector(5 downto 0);

signal blitter_src_current_next : unsigned(18 downto 0);
signal blitter_src_current_reg : unsigned(18 downto 0);

signal blitter_dest_current_next : unsigned(18 downto 0);
signal blitter_dest_current_reg : unsigned(18 downto 0);

signal blitter_vram_wren_reg : std_logic;
signal blitter_vram_wren_next : std_logic;

signal blitter_vram_data_reg : std_logic_vector(7 downto 0);
signal blitter_vram_data_next : std_logic_vector(7 downto 0);

signal blitter_vram_address_reg : std_logic_vector(18 downto 0);
signal blitter_vram_address_next : std_logic_vector(18 downto 0);

signal blitter_collision_reg : std_logic_vector(7 downto 0);
signal blitter_collision_next : std_logic_vector(7 downto 0);

signal blitter_irq_reg : std_logic;
signal blitter_irq_next : std_logic;

signal blitter_x_reg : unsigned(8 downto 0);
signal blitter_x_next : unsigned(8 downto 0);

signal blitter_y_reg : unsigned(7 downto 0);
signal blitter_y_next : unsigned(7 downto 0);

signal blitter_rep_x_reg : unsigned(2 downto 0);
signal blitter_rep_x_next : unsigned(2 downto 0);

signal blitter_rep_y_reg : unsigned(2 downto 0);
signal blitter_rep_y_next : unsigned(2 downto 0);

signal blitter_pattern_current_reg : unsigned(5 downto 0);
signal blitter_pattern_current_next : unsigned(5 downto 0);

signal blitter_data_last_reg : std_logic_vector(7 downto 0);
signal blitter_data_last_next : std_logic_vector(7 downto 0);

begin

-- outputs

blitter_vram_address <= blitter_vram_address_next;
blitter_vram_data <= blitter_vram_data_next;
blitter_vram_wren <= blitter_vram_wren_next;
blitter_status <= (not(blitter_state_reg(5)) and or_reduce(blitter_state_reg(4 downto 0))) & blitter_state_reg(5);
blitter_collision <= blitter_collision_reg;
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
		blitter_mode_reg <= 0;

		blitter_load_address_reg <= (others => '0');
		blitter_state_reg <= (others => '0');

		blitter_src_current_reg <= (others => '0');
		blitter_dest_current_reg <= (others => '0');

		blitter_vram_wren_reg <= '0';
		blitter_vram_data_reg <= (others => '0');
		blitter_vram_address_reg <= (others => '0');
		blitter_collision_reg  <= (others => 'U');
		blitter_irq_reg <= '0';
		blitter_x_reg <= (others => '0');
		blitter_y_reg <= (others => '0');
		blitter_rep_x_reg <= (others => '0');
		blitter_rep_y_reg <= (others => '0');
		blitter_pattern_current_reg <= (others => '0');
		blitter_data_last_reg <= (others => '0');
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

		blitter_vram_wren_reg <= blitter_vram_wren_next;
		blitter_vram_data_reg <= blitter_vram_data_next;
		blitter_vram_address_reg <= blitter_vram_address_next;
		blitter_collision_reg  <= blitter_collision_next;
		blitter_irq_reg <= blitter_irq_next;
		blitter_x_reg <= blitter_x_next;
		blitter_y_reg <= blitter_y_next;
		blitter_rep_x_reg <= blitter_rep_x_next;
		blitter_rep_y_reg <= blitter_rep_y_next;
		blitter_pattern_current_reg <= blitter_pattern_current_next;
		blitter_data_last_reg <= blitter_data_last_next;
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
	blitter_x_reg,blitter_y_reg,blitter_rep_x_reg,blitter_rep_y_reg,blitter_pattern_current_reg,
	blitter_vram_wren_reg,blitter_data_last_reg
)
	variable source_data : std_logic_vector(7 downto 0);
	variable blitter_write_destination : boolean;
	variable blitter_update_state : boolean;
	variable blitter_src_current_tmp : unsigned(18 downto 0);
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

	blitter_vram_wren_next <= blitter_vram_wren_reg;
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
	blitter_data_last_next <= blitter_data_last_reg;
	
	if blitter_enable = '1' then
		if (blitter_state_reg /= "000000") then
			if blitter_state_reg(5) = '1' then -- init

				blitter_vram_wren_next <= '0';
				blitter_vram_address_next <= std_logic_vector(unsigned(blitter_vram_address_reg) + 1);

				case blitter_state_reg(4 downto 0) is
				when "11111" =>
					if (blitter_next_reg = '1') then
						blitter_load_address_next <= std_logic_vector(unsigned(blitter_load_address_reg) + 21);
						blitter_vram_address_next <= blitter_load_address_reg;
					else
						blitter_load_address_next <= std_logic_vector(unsigned(blitter_address) + 21);
						blitter_vram_address_next <= blitter_address;
						blitter_collision_next <= X"00"; -- TODO also when chained???
					end if;
					blitter_state_next <= "100000";
				when "00000" =>
					blitter_src_address_next(7 downto 0) <= unsigned(blitter_vram_data_in);
					blitter_state_next <= "100001";
				when "00001" =>
					blitter_src_address_next(15 downto 8) <= unsigned(blitter_vram_data_in);
					blitter_state_next <= "100010";
				when "00010" =>
					blitter_src_address_next(18 downto 16) <= unsigned(blitter_vram_data_in(2 downto 0));
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
					blitter_dest_address_next(7 downto 0) <= unsigned(blitter_vram_data_in);
					blitter_state_next <= "100111";
				when "00111" =>
					blitter_dest_address_next(15 downto 8) <= unsigned(blitter_vram_data_in);
					blitter_state_next <= "101000";
				when "01000" =>
					blitter_dest_address_next(18 downto 16) <= unsigned(blitter_vram_data_in(2 downto 0));
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
					blitter_width_next(7 downto 0) <= unsigned(blitter_vram_data_in);
					blitter_state_next <= "101101";
				when "01101" =>
					blitter_width_next(8) <= blitter_vram_data_in(0);
					blitter_state_next <= "101110";
				when "01110" =>
					blitter_height_next <= unsigned(blitter_vram_data_in);
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
					blitter_zoom_x_next <= unsigned(blitter_vram_data_in(2 downto 0));
					blitter_zoom_y_next <= unsigned(blitter_vram_data_in(6 downto 4));
					blitter_state_next <= "110011";
				when "10011" =>
					blitter_pattern_next <= blitter_vram_data_in(7);
					blitter_pattern_count_next <= unsigned(blitter_vram_data_in(5 downto 0));
					blitter_state_next <= "110100";
				when "10100" =>
					blitter_next_next <= blitter_vram_data_in(3);
					-- TODO what about mode 7???
					blitter_mode_next <= to_integer(unsigned(blitter_vram_data_in(2 downto 0)));
					
					-- Prepare or the state variables to run the blitter
					blitter_src_current_next <= blitter_src_address_reg;
					blitter_dest_current_next <= blitter_dest_address_reg;
					blitter_x_next <= blitter_width_reg;
					blitter_y_next <= blitter_height_reg;
					blitter_rep_x_next <= blitter_zoom_x_reg;
					blitter_rep_y_next <= blitter_zoom_y_reg;
					blitter_pattern_current_next <= blitter_pattern_count_reg;
					-- TODO Or waste a cycle and go to "000001" ???
					-- How does it compare with the original timing in VBXE, can this be tested / measured?
					-- (with a long chain of blitter blocks?)
					-- check for the AND mask here does not make too much sense, 
					-- we go to a state where the data is already in anyhow, it would make sense if we 
					-- decided to go to state "000001" first
					blitter_vram_address_next <= std_logic_vector(blitter_src_address_reg);
					blitter_state_next <= "000010";
				when others =>
				end case;
			else
				-- blitter running
				blitter_write_destination := false;
				blitter_update_state := false;
				case blitter_state_reg(4 downto 0) is
				when "00001" => -- request read source
					blitter_vram_wren_next <= '0';
					blitter_vram_address_next <= std_logic_vector(blitter_src_current_reg);
					blitter_state_next <= "000010";
				when "00010" -- just actually read the source byte
					| "01010" -- have to restore a previously read byte (x-zoom in progress)
					| "10010" -- just read the destination byte for modes and configurations that need it
					=>
					if blitter_state_reg(4) = '0' then
						-- source data read
						if blitter_state_reg(3) = '1' then
							-- we are repeating the source data because of the x-zoom
							source_data := (blitter_data_last_reg and blitter_and_mask_reg) xor blitter_xor_mask_reg;
						else
							-- fresh read or irrelevant because AND mask is 0
							blitter_data_last_next <= blitter_vram_data_in;
							source_data := (blitter_vram_data_in and blitter_and_mask_reg) xor blitter_xor_mask_reg;
						end if;
						blitter_vram_data_next <= source_data;
						-- In mode 4 (AND with destination) or in mode 1 with collision mask active, or any other mode
						-- we need to read the destination byte (to do either the collision detection, or to combine into the result (AND), or both)
						if (blitter_mode_reg = 4) or ((source_data /= x"00") and (((blitter_mode_reg = 1) and (blitter_collision_mask_reg /= x"00")) or (blitter_mode_reg > 1))) then
							blitter_vram_wren_next <= '0';
							blitter_vram_address_next <= std_logic_vector(blitter_dest_current_reg);
							-- we need to read the destination byte, so no writing or updating the blitter state yet
							blitter_state_next <= "010010";
						else
							-- no need to read the destination data, now check if the destination has to be changed
							blitter_update_state := true;
							-- In mode 0 or in mode 1 when the source data is not 0 but the collision did not have to be checked
							-- we go directly to writing
							if (blitter_mode_reg = 0) or ((blitter_mode_reg = 1) and (source_data /= x"00")) then
								blitter_write_destination := true;
							end if;
						end if;
					else
						-- destination data read-in, blitter_vram_data_reg has pre-modified source, blitter_vram_data_in has data from the destination
						if ((blitter_mode_reg = 4) and (blitter_vram_data_reg /= x"00")) or ((blitter_mode_reg > 0) and (blitter_mode_reg /= 4) and (blitter_mode_reg /= 6)) then
							-- check for sr collision_code
							if (blitter_collision_reg = x"00") and (blitter_vram_data_in /= x"00") and (blitter_collision_mask_reg(to_integer(unsigned(blitter_vram_data_in(7 downto 5)))) = '1') then
								blitter_collision_next <= blitter_vram_data_in;
							end if;
						end if;
						-- Process the modified source and the destination data according to mode
						case blitter_mode_reg is
							when 2 =>
								blitter_vram_data_next <= std_logic_vector(unsigned(blitter_vram_data_reg) + unsigned(blitter_vram_data_in));
							when 3 =>
								blitter_vram_data_next <= blitter_vram_data_reg or blitter_vram_data_in;
							when 4 =>
								blitter_vram_data_next <= blitter_vram_data_reg and blitter_vram_data_in;
							when 5 =>
								blitter_vram_data_next <= blitter_vram_data_reg xor blitter_vram_data_in;
							when 6 =>
								-- despite the whole source != 0, a single nibble can still be 0
								
								if (blitter_vram_data_reg(3 downto 0) /= x"0") then
									if (blitter_collision_reg(3 downto 0) = x"0") and (blitter_vram_data_in(3 downto 0) /= x"0") and (blitter_collision_mask_reg(to_integer(unsigned(blitter_vram_data_in(3 downto 1)))) = '1') then
										blitter_collision_next(3 downto 0) <= blitter_vram_data_in(3 downto 0);
									end if;
								else
									-- Destination nibble 0, but the write has to happen nevertheless,
									-- so restore this part of the nibble so that the write is a no-op
									blitter_vram_data_next(3 downto 0) <= blitter_vram_data_in(3 downto 0);
								end if;
								-- The other nibble
								if (blitter_vram_data_reg(7 downto 4) /= x"0") then
									if (blitter_collision_reg(7 downto 4) = x"0") and (blitter_vram_data_in(7 downto 4) /= x"0") and (blitter_collision_mask_reg(to_integer(unsigned(blitter_vram_data_in(7 downto 5)))) = '1') then
										blitter_collision_next(7 downto 4) <= blitter_vram_data_in(7 downto 4);
									end if;
								else
									blitter_vram_data_next(7 downto 4) <= blitter_vram_data_in(7 downto 4);
								end if;
								
							when others =>
								-- non existing blitter mode 7 or the two not possible (0) or already taken care of (1)
						end case;
						blitter_update_state := true;
						-- In this branch (we had to read the destination first, we certainly now need to write it)
						blitter_write_destination := true;
					end if;
					
					-- Do we need to write anything?
					if blitter_write_destination then
						blitter_vram_address_next <= std_logic_vector(blitter_dest_current_reg);
						blitter_vram_wren_next <= '1';
					end if;
					
					-- Are we ready to go to the next data by updating all the indices
					if blitter_update_state then
						if (blitter_x_reg = 0) and (blitter_rep_x_reg = 0) then
							if (blitter_y_reg = 0) and (blitter_rep_y_reg = 0) then
								if blitter_next_reg = '1' then
									blitter_state_next <= "111111";
								else
									blitter_state_next <= "000000";
									blitter_irq_next <= '1';
								end if;
							else
								blitter_x_next <= blitter_width_reg;
								blitter_rep_x_next <= blitter_zoom_x_reg;
								if blitter_rep_y_reg = 0 then
									blitter_src_current_tmp := blitter_src_address_reg + blitter_src_step_y_reg;
									blitter_src_address_next <= blitter_src_address_reg + blitter_src_step_y_reg;
									blitter_rep_y_next <= blitter_zoom_y_reg;
									blitter_y_next <= blitter_y_reg - 1;
								else
									blitter_src_current_tmp := blitter_src_address_reg;
									blitter_rep_y_next <= blitter_rep_y_reg - 1;
								end if;
								blitter_src_current_next <= blitter_src_current_tmp;
								blitter_pattern_current_next <= blitter_pattern_count_reg;
								blitter_dest_current_next <= blitter_dest_address_reg + blitter_dest_step_y_reg;
								blitter_dest_address_next <= blitter_dest_address_reg + blitter_dest_step_y_reg;
								if (not(blitter_write_destination) or (blitter_and_mask_reg = x"00")) then
									if blitter_and_mask_reg /= x"00" then
										blitter_vram_wren_next <= '0';
										blitter_vram_address_next <= std_logic_vector(blitter_src_current_tmp);
									end if;
									blitter_state_next <= "000010";
								else
									blitter_state_next <= "000001";
								end if;
							end if;
						else
							blitter_dest_current_next <= blitter_dest_current_reg + blitter_dest_step_x_reg;
							if blitter_rep_x_reg = 0 then
								if (blitter_pattern_reg = '1') and (blitter_pattern_current_reg = 0) then
									blitter_src_current_tmp := blitter_src_address_reg;
									blitter_pattern_current_next <= blitter_pattern_count_reg;
								else
									blitter_src_current_tmp := blitter_src_current_reg + blitter_src_step_x_reg;
									if (blitter_pattern_reg = '1') then
										blitter_pattern_current_next <= blitter_pattern_current_reg - 1;
									end if;
								end if;
								blitter_src_current_next <= blitter_src_current_tmp;
								blitter_rep_x_next <= blitter_zoom_x_reg;
								blitter_x_next <= blitter_x_reg - 1;
								if (not(blitter_write_destination) or (blitter_and_mask_reg = x"00")) then
									if blitter_and_mask_reg /= x"00" then
										blitter_vram_wren_next <= '0';
										blitter_vram_address_next <= std_logic_vector(blitter_src_current_tmp);
									end if;
									blitter_state_next <= "000010";
								else
									blitter_state_next <= "000001";
								end if;
							else
								blitter_rep_x_next <= blitter_rep_x_reg - 1;
								-- The data previously read from the source should be restored
								blitter_state_next <= "001010";
							end if;
						end if;
					end if;
				when others =>
				end case;
			end if;
		end if;
	end if;

	if ((blitter_stop_request or soft_reset) = '1') then
		blitter_state_next <= "000000";
	elsif blitter_start_request = '1' then
		-- TODO Or prep the first step already here and go to state "100000" ???
		-- The condition in state 111111 can be removed (special state for restarting the blitter then?)
		-- Is the sychronization with the request OK for this?
		blitter_state_next <= "111111";
	end if;
	if ((blitter_irqc or soft_reset) = '1') then
		blitter_irq_next <= '0';
	end if;

end process;

end vhdl;

