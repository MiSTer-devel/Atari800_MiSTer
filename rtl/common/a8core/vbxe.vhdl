library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity VBXE is
port (
	clk : in std_logic;
	clk_enable : in std_logic;
	enable_179 : in std_logic;
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

signal blit_next : std_logic;
signal blit_started : std_logic;
signal blit_data : std_logic_vector(7 downto 0);
signal blit_data_out : std_logic_vector(7 downto 0);
signal blit_miss : std_logic_vector(7 downto 0);
signal memory_request : std_logic;
signal memory_dir : std_logic;


signal blit_data_reg : std_logic_vector(7 downto 0);
signal blit_data_next : std_logic_vector(7 downto 0);

begin

-- data_out <= data_reg_out;
--memory_fetch <= clk_enable and memory_request;
--memory_fetch <= memory_request;
memory_fetch <= '0';


--process(wr_en, data_in, spi_en_reg, spi_clk_reg, spi_in_reg)
--begin
--	spi_en_next <= spi_en_reg;
--	spi_clk_next <= spi_clk_reg;
--	spi_in_next <= spi_in_reg;
--	if wr_en = '1' then
--		spi_en_next <= data_in(0);
--		spi_clk_next <= data_in(1);
--		spi_in_next <= data_in(2);
--	end if;
--end process;

--process(clk, reset_n, addr, wr_en)

vbxe_vram: entity work.generic_ram_infer
        generic map
        (
                ADDRESS_WIDTH => 18, -- 19,
                SPACE => 262144, -- 524288,
                DATA_WIDTH =>8
        )
        PORT MAP(clock => clk,
                address => my_memory_addr(17 downto 0),
                data => blit_data,
                we => memory_dir,
                q => blit_data_out
        );

process(addr, blit_data_reg, wr_en, data_in)
begin
		blit_data_next <= blit_data_reg;
		if wr_en = '1' then
			case addr is
				--when "00000" => -- core version -> FX
				--	data_out <= X"10";
				--when "00001" => -- minor version
				--	data_out <= X"26";
				--when "00010" => -- 
				-- data_out <= blit_miss;
				when "00011" => -- 
					blit_data_next <= data_in;
				when others =>
					null;			
			end case;
		end if;
end process;


-- Read registers
process(addr, blit_miss, blit_data_out)
begin
		case addr is
		when "00000" => -- core version -> FX
			data_out <= X"10";
		when "00001" => -- minor version
			data_out <= X"26";
		when "00010" => -- 
			data_out <= blit_miss;
		when "00011" => -- 
			data_out <= blit_data_out;
--		when "00100" => -- 
--			data_out <= vram(150);
		when others =>
			data_out <= X"FF";			
		end case;
end process;

process(reset_n,clk,clk_enable,enable_179)
	variable miss_counter : integer range 0 to 255;
	variable memory_counter : integer range 0 to 524287;
begin
	if reset_n = '0' then
		blit_data_reg <= (others => '0');
	elsif rising_edge(clk) then
		blit_data_reg <= blit_data_next;
	end if;
end process;

-- Senseless 1 cell blitter just to see how we keep up with clock cycles
process(reset_n,clk,clk_enable,enable_179)
	variable miss_counter : integer range 0 to 255;
	variable memory_counter : integer range 0 to 524287;
begin
	if reset_n = '0' then
		-- memory_addr <= "1110000000000000000"; -- $70000
		my_memory_addr <= "0000000000000000000";
		memory_wr_en <= '0';
		memory_dir <= '0';
		--blit_started <= '0';
		--blit_next <= '0';
		blit_data <= X"AB";
		memory_request <= '1';
		blit_miss <= (others => '0');
		miss_counter := 0;
		memory_counter := 0;
		-- blit_data_out <= X"FF";
	else
		if rising_edge(clk) then
			--if clk_enable = '1'then
			--if memory_ready = '1' then
				-- blit_data_out <= blit_data;
				-- memory_wr_en <= memory_dir;
				blit_data <= blit_data_reg;
				memory_dir <= not(memory_dir);
				miss_counter := miss_counter + 1;
				--if memory_dir = '1' then
				--	blit_data <= vram(to_integer(unsigned(my_memory_addr)));
				--	blit_data <= memory_data_in;
				--else
				--	memory_data_out <= blit_data;
				--	vram(to_integer(unsigned(my_memory_addr))) <= blit_data;				
				--end if;
				if memory_dir = '0' then
					memory_counter := memory_counter + 1;
					my_memory_addr <= std_logic_vector(to_unsigned(memory_counter,19));
				end if;
				-- memory_addr <= std_logic_vector(to_unsigned(memory_counter,19));
			--end if;
			if enable_179 = '1' then
				blit_miss <= std_logic_vector(to_unsigned(miss_counter,8));
				miss_counter := 0;
			end if;
		end if;
	end if;
end process;

end vhdl;