library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main is
    Port ( clk : in  std_logic;
           swt : in  std_logic_vector (7 downto 0);
           led : inout  std_logic_vector (7 downto 0));
end main;

architecture Behavioral of main is
    signal rst : std_logic;
    signal clkdiv : std_logic_vector (25 downto 0);
    signal dividedClk, clkout : std_logic;
begin
    
    rst <= swt(7);
    
    process (clk, rst) begin
        if rst = '1' then clkdiv <= (others=>'0');
            elsif rising_edge(clk) then
                clkdiv <= std_logic_vector(unsigned(clkdiv) + 1);
                clkout <= dividedClk;
            end if;
    end process;
    
    with swt(2 downto 0) select
    dividedClk <= clkdiv(18) when "111",
                  clkdiv(19) when "110",
                  clkdiv(20) when "101",
                  clkdiv(21) when "100",
                  clkdiv(22) when "011",
                  clkdiv(23) when "010",
                  clkdiv(24) when "001",
                  clkdiv(25) when others;
                      
    process (rst, clkout) begin
        if rst = '1' then
            led <= (others=>'0');
        elsif rising_edge(clkout) then
            led <= led(6 downto 0) & not led(7);
        end if;
    end process;                  
    
end Behavioral;
