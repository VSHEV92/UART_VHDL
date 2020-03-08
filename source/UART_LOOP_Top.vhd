library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_LOOP_Top is
    Port ( clk   : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           rx    : in  STD_LOGIC;
           tx    : out  STD_LOGIC;
           led   : out STD_LOGIC_VECTOR (7 downto 0)
    );
end UART_LOOP_Top;

architecture Behavioral of UART_LOOP_Top is

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

COMPONENT Data_Fifo
  PORT (
    clk   : IN  STD_LOGIC;
    srst  : IN  STD_LOGIC;
    din   : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN  STD_LOGIC;
    rd_en : IN  STD_LOGIC;
    dout  : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full  : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END COMPONENT;

component UART_TX is
    Generic( Clk_Freq     : integer;  -- частота тактового сигнала в Гц
             Fifo_Latency : integer;  -- задержка выдачи данных из fifo после fifi_re (1 или 2 такта)
             Baud_Rate    : integer;  -- 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
             Byte_Size    : integer;  -- 5, 6, 7, 8, 9
             Stop_Bits    : integer;  -- 0, 1, 2
             Parity_Bit   : integer   -- 0 - none, 1 - even, 2 - odd,
    );
    Port ( clk          : in  STD_LOGIC;
           reset        : in  STD_LOGIC;
           data         : in  STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
           fifo_empty   : in  STD_LOGIC;
           fifo_re      : out STD_LOGIC;
           tx           : out STD_LOGIC
    );
end component;

signal rx_data : STD_LOGIC_VECTOR (7 downto 0);
signal tx_data : STD_LOGIC_VECTOR (7 downto 0);

signal fifo_we    : STD_LOGIC;
signal fifo_re    : STD_LOGIC;
signal fifo_empty : STD_LOGIC;

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
               data         => rx_data,
               data_valid   => fifo_we,
               parity_error => open
    );

led <= rx_data;

Buffer_FIFO : Data_Fifo
  PORT MAP (
    clk   => clk,
    srst  => reset,
    din   => rx_data,
    wr_en => fifo_we,
    rd_en => fifo_re,
    dout  => tx_data,
    full  => open,
    empty => fifo_empty
  );

UART_TX_1: UART_TX
    Generic map( Clk_Freq     => 200000000,
                 Fifo_Latency => 1,
                 Baud_Rate    => 9600,  
                 Byte_Size    => 8,
                 Stop_Bits    => 1,
                 Parity_Bit   => 0
    )
    Port map ( clk          => clk,
               reset        => reset,
               data         => tx_data,
               fifo_empty   => fifo_empty,
               fifo_re      => fifo_re,
               tx           => tx
    );

end Behavioral;
