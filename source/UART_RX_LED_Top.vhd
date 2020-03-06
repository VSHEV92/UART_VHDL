library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_RX_LED_Top is
    Port ( clk   : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           rx    : in  STD_LOGIC;
           data  : out STD_LOGIC_VECTOR (7 downto 0)
    );
end UART_RX_LED_Top;

architecture Behavioral of UART_RX_LED_Top is

component UART_RX is
    Generic( Clk_Freq   : integer;  -- частота тактового сигнала в Гц
             Baud_Rate  : integer;  -- 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
             Byte_Size  : integer;  -- 5, 6, 7, 8, 9
             Stop_Bits  : integer;  -- 0, 1, 2
             Parity_Bit : integer   -- 0 - none, 1 - even, 2 - odd,
    );
    Port ( clk          : in  STD_LOGIC;
           reset        : in  STD_LOGIC;
           rx           : in  STD_LOGIC;
           data         : out STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
           data_valid   : out STD_LOGIC;
           parity_error : out STD_LOGIC
    );
end component;

begin

UART_RX_1: UART_RX
    Generic map( Clk_Freq   => 200000000,
                 Baud_Rate  => 9600,  
                 Byte_Size  => 8,
                 Stop_Bits  => 1,
                 Parity_Bit => 0
    )
    Port map ( clk          => clk,
               reset        => reset,
               rx           => rx, 
               data         => data,
               data_valid   => open,
               parity_error => open
    );


end Behavioral;
