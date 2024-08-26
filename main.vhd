library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main is
    Port ( clk : in  std_logic;
           swt : in  std_logic_vector (7 downto 0);
           led : inout  std_logic_vector (7 downto 0));
end main;

architecture Behavioral of main is
    signal num_a: integer range 0 to 255;
    signal num_b: integer range 0 to 255;
    signal sum: std_logic_vector(8 downto 0);
begin
    
    with swt(7 downto 5) select
	    num_a <= 35 when "111",
                 30 when "110",
                 25 when "101",
                 20 when "100",
                 15 when "011",
                 10 when "010",
                 5 when "001",
                 0 when others;
    
    with swt(2 downto 0) select
	    num_b <= 21 when "111",
                 18 when "110",
                 15 when "101",
                 12 when "100",
                 9 when "011",
                 6 when "010",
                 3 when "001",
                 0 when others;
    
    sum <= std_logic_vector(to_unsigned(num_a + num_b, 9));
    
    led(7 downto 0) <= sum(7 downto 0);		  
    
end Behavioral;
