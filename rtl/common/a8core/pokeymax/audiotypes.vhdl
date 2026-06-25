LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package AudioTypes is

type SIGNED_AUDIO_TYPE is array(NATURAL range<>) of signed(15 downto 0);
type UNSIGNED_AUDIO_TYPE is array(NATURAL range<>) of unsigned(15 downto 0);
type PSG_CHANNEL_TYPE is array(NATURAL range<>) of std_logic_vector(4 downto 0);
type POKEY_AUDIO is array(NATURAL range<>) of std_logic_vector(3 downto 0);

end package AudioTypes;
