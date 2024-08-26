library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity main is
    Port ( rst : in  STD_LOGIC;
           clk : in  STD_LOGIC;
           swt : in  STD_LOGIC_VECTOR (2 downto 0);
           led : inout  STD_LOGIC_VECTOR (7 downto 0));
end main;

architecture Behavioral of main is

begin
    
    -- Display an alternating test pattern on the board LEDs
    led <= "10101010";				  
	
end Behavioral;
