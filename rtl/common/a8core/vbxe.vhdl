library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

entity VBXE is
port (
	clk : in std_logic;
	clk_enable : in std_logic; -- VBXE speed -> 8x CPU
	enable_179 : in std_logic; -- CPU speed
	reset_n : in std_logic;
	addr : in std_logic_vector(4 downto 0); -- 32 registers based at $D640/$D740
	data_in: in std_logic_vector(7 downto 0); -- for register write
	wr_en : in std_logic;
	data_out: out std_logic_vector(7 downto 0); -- for register read

	memory_data_in : in std_logic_vector(7 downto 0); -- read from 512K VRAM
	memory_data_out : out std_logic_vector(7 downto 0); -- write to 512K VRAM
	memory_wr_en : out std_logic;
	memory_fetch : out std_logic;
	memory_ready : in std_logic;
	memory_addr : out std_logic_vector(18 downto 0) -- 512K VRAM address
);
end VBXE;

architecture vhdl of VBXE is

--signal data_reg_out: std_logic_vector(7 downto 0);
--type memory_type is array(0 to 524287) of std_logic_vector(7 downto 0);
--type memory_type is array(0 to 16383) of std_logic_vector(7 downto 0);
--signal vram: memory_type;

signal my_memory_addr : std_logic_vector(18 downto 0);
signal memory_request : std_logic;
signal memory_dir : std_logic; -- 1 write, 0 read

signal blit_data_reg : std_logic_vector(7 downto 0);
signal blit_data_next : std_logic_vector(7 downto 0);

signal blit_counter_reg : std_logic_vector(7 downto 0);
signal blit_counter_next : std_logic_vector(7 downto 0);

signal blit_data_read_reg : std_logic_vector(7 downto 0);
signal blit_data_read_next : std_logic_vector(7 downto 0);

signal blit_data_dir_reg : std_logic_vector(7 downto 0);
signal blit_data_dir_next : std_logic_vector(7 downto 0);

begin

--memory_fetch <= clk_enable and memory_request;

memory_fetch <= memory_request;
memory_wr_en <= memory_dir;
memory_addr <= my_memory_addr;
memory_data_out <= blit_data_reg;

--vbxe_vram: entity work.generic_ram_infer
--        generic map
--        (
--                ADDRESS_WIDTH => 18, -- 19,
--                SPACE => 262144, -- 524288,
--                DATA_WIDTH =>8
--        )
--        PORT MAP(clock => clk,
--                address => my_memory_addr(17 downto 0),
--                data => blit_data,
--                we => memory_dir,
--                q => blit_data_out
--        );

-- write registers
process(addr, blit_data_reg, blit_data_dir_reg, wr_en, data_in)
begin
		blit_data_next <= blit_data_reg;
		blit_data_dir_next <= blit_data_dir_reg;
		if wr_en = '1' then
			case addr is
				when "00010" =>
					blit_data_dir_next <= data_in;
				when "00011" =>
					blit_data_next <= data_in;
				when others =>
					null;
			end case;
		end if;
end process;

-- Read registers
process(addr, blit_counter_reg, blit_data_read_reg)
begin
		case addr is
		when "00000" => -- core version -> FX
			data_out <= X"10";
		when "00001" => -- minor version
			data_out <= X"26";
		when "00010" => -- 
			data_out <= blit_counter_reg;
		when "00011" => -- 
			data_out <= blit_data_read_reg;
--		when "00100" => -- 
--			data_out <= vram(150);
		when others =>
			data_out <= X"FF";
		end case;
end process;

process(clk,reset_n,blit_data_next,blit_data_read_next,blit_counter_next,blit_data_dir_next)
begin
	if reset_n = '0' then
		blit_data_reg <= (others => '0');
		blit_data_read_reg <= (others => '1');
		blit_counter_reg <= (others => '0');
		blit_data_dir_reg <= (others => '0');
	elsif rising_edge(clk) then
		blit_data_reg <= blit_data_next;
		blit_data_read_reg <= blit_data_read_next;
		blit_counter_reg <= blit_counter_next;
		blit_data_dir_reg <= blit_data_dir_next;
	end if;
end process;

process(reset_n,clk,clk_enable,enable_179,blit_counter_reg,blit_data_read_reg,blit_data_reg,blit_data_dir_reg,memory_data_in)
	variable hit_counter : integer range 0 to 255;
	variable memory_counter : integer range 0 to 524287;
begin
	if reset_n = '0' then
		memory_dir <= '0';
		memory_request <= '0';
		hit_counter := 0;
		memory_counter := 0;
		my_memory_addr <= std_logic_vector(to_unsigned(memory_counter,19));
	else
		if rising_edge(clk) then
			blit_counter_next <= blit_counter_reg;
			blit_data_read_next <= blit_data_read_reg;
			if blit_data_dir_reg(1) = '1' then
				memory_request <= '1';
			end if;
			--if clk_enable = '1'then
			if memory_ready = '1' then
				hit_counter := hit_counter + 1;
				if memory_dir = '0' then
					blit_data_read_next <= memory_data_in;
				--else
				--	memory_data_out <= blit_data_reg;
				end if;
				memory_dir <= or_reduce(blit_data_dir_reg);
				memory_request <= '1';
				memory_counter := memory_counter + 1;
				my_memory_addr <= std_logic_vector(to_unsigned(memory_counter,19));
			end if;
			if enable_179 = '1' then
				blit_counter_next <= std_logic_vector(to_unsigned(hit_counter,8));
				hit_counter := 0;
			end if;
		end if;
	end if;
end process;

end vhdl;