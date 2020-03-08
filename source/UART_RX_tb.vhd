-----------------------------------------------------------------------------------------------
--------------------------- Тест синтезируемого блока UART приемника --------------------------
-----------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_RX_tb is
end UART_RX_tb;

architecture Behavioral of UART_RX_tb is

-- процедура для вывода данных без сообщений от Vivado
procedure echo (arg : in string := "") is
begin
  std.textio.write(std.textio.output, arg);
end procedure echo;

------------------------------------ Параметры теста ------------------------------------
constant Input_Data_File : string  := "/home/vovan/VivadoProjects/UART_VHDL/source/input_data.txt";
constant Clk_Freq        : integer := 200000000;  -- частота тактового сигнала в Гц
constant Baud_Rate       : integer := 9600;       -- 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
constant Byte_Size       : integer := 8;          -- 5, 6, 7, 8, 9
constant Stop_Bits       : integer := 1;          -- 0, 1, 2
constant Parity_Bit      : integer := 1;          -- 0 - none, 1 - even, 2 - odd,
-----------------------------------------------------------------------------------------

-- Поведенческая модель передатчика UART
component UART_TX_Beh is
    Generic( Input_Data_File : string ;
             Baud_Rate       : integer;
             Byte_Size       : integer;
             Stop_Bits       : integer;   
             Parity_Bit      : integer
    );
    Port ( tx         : out STD_LOGIC;                                
           data       : out STD_LOGIC_VECTOR (Byte_Size-1 downto 0);  
           data_valid : out STD_LOGIC;
           done       : out STD_LOGIC                                  
    );
end component;

-- Cинтезируемый блок приемника UART
component UART_RX is
    Generic( Clk_Freq   : integer;  
             Baud_Rate  : integer; 
             Byte_Size  : integer; 
             Stop_Bits  : integer; 
             Parity_Bit : integer   
    );
    Port ( clk          : in  STD_LOGIC;
           reset        : in  STD_LOGIC;
           rx           : in  STD_LOGIC;
           data         : out STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
           data_valid   : out STD_LOGIC;
           parity_error : out STD_LOGIC
    );
end component;

signal UART_data     : STD_LOGIC;                                

signal data_tx       : STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
signal data_tx_valid : STD_LOGIC;
signal done_tx       : STD_LOGIC;

signal data_rx       : STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
signal data_rx_valid : STD_LOGIC;
signal parity_error  : STD_LOGIC; 

signal clk : STD_LOGIC;
signal reset  : STD_LOGIC; 
constant clk_period : time := 1 sec / Clk_Freq;

begin

clk_stim: process
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

reset_stim: process
begin
    reset <= '1';
    wait for 100 ns;
    reset <= '0';
    wait;
end process;

-- Поведенческая модель передатчика UART
UART_TX_uut: UART_TX_Beh
    Generic map( Input_Data_File => Input_Data_File,
                 Baud_Rate       => Baud_Rate,
                 Byte_Size       => Byte_Size,
                 Stop_Bits       => Stop_Bits,
                 Parity_Bit      => Parity_Bit
    )
    Port map ( tx         => UART_data,
               data       => data_tx,
               data_valid => data_tx_valid,
               done       => done_tx
    );

-- Cинтезируемый блок приемника UART
UART_RX_uut: UART_RX
    Generic map( Clk_Freq        => Clk_Freq,
                 Baud_Rate       => Baud_Rate,
                 Byte_Size       => Byte_Size,
                 Stop_Bits       => Stop_Bits,
                 Parity_Bit      => Parity_Bit
    )
    Port map ( clk          => clk,
               reset        => reset,
               rx           => UART_data,
               data         => data_rx,
               data_valid   => data_rx_valid,
               parity_error => parity_error
    );

-----------------------------------------------------------------------------------------
--------------------------- проверка результатов ----------------------------------------
process (data_tx_valid, data_rx_valid, done_tx)
    variable counter_tx : integer := 0;
    variable counter_rx : integer := 0;
    variable data_tx_var : STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
    variable data_rx_var : STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
    variable test_result : string(1 to 4) := "PASS";
begin
    -- записываем передаваемое слово
    if falling_edge(data_tx_valid) then
        data_tx_var := data_tx;
        counter_tx := counter_tx + 1;
    end if;
    
    -- записываем полученное слово
    if rising_edge(data_rx_valid) then
        data_rx_var := data_rx;
        counter_rx := counter_rx + 1;
        
        -- сравниваем значение слов
        if data_rx_var /= data_tx_var then
            echo("TX and RX data doesn't match!" & LF);
            echo("TX word number " & integer'image(counter_tx) & " has value = " & integer'image(TO_INTEGER(UNSIGNED(data_tx_var))) & LF);
            echo("RX word number " & integer'image(counter_rx) & " has value = " & integer'image(TO_INTEGER(UNSIGNED(data_rx_var))) & LF);
            echo("" & LF);
            test_result := "FAIL";
        end if;
        
         -- проверяем бит четности
         if parity_error = '1' then
            echo("Parity Error in RX word number " & integer'image(counter_rx) & LF);
            echo("" & LF);
            test_result := "FAIL";
        end if; 
    end if;
    
    -- вывод результатов теста
    if rising_edge(done_tx) then
        echo("----------------------------------------------------------------------------------------" & LF);
        echo("Number of transmitted words: " & integer'image(counter_tx) & LF);
        echo("Number of received words: " & integer'image(counter_rx) & LF);
        echo("Test result: " & test_result & LF);
        echo("----------------------------------------------------------------------------------------" & LF);
    end if;
    
end process;

end Behavioral;
