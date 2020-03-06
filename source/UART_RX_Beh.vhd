--------------------------------------------------------------------------------------------------------------
---------------------------------- Поведенческая модель приемника UART ---------------------------------------
-- Generics блока задают параметры приемника, такие как скорость в бодах/с, количество бит в передаваемом слове,
-- количество стоп-битов, наличие бита четности. С помощью переменной UART_transaction, осуществляется возможность 
-- приема данных в случае, если число стоп-битов установлено равным нулю и следующая передача, следует сразу же 
-- за предыдущей без задержки. Вход rx - сигнал от UART передатчика. Выходы: data - полученное слово данных,
-- data_valid - строб сигнал для полученных данных, parity_error - флаг ошибки четности (активный уровень '1').
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_RX_Beh is
    Generic( Baud_Rate  : integer;  -- 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
             Byte_Size  : integer;  -- 5, 6, 7, 8, 9
             Stop_Bits  : integer;  -- 0, 1, 2
             Parity_Bit : integer   -- 0 - none, 1 - even, 2 - odd,
    );
    Port ( rx           : in  STD_LOGIC;
           data         : out STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
           data_valid   : out STD_LOGIC;
           parity_error : out STD_LOGIC
    );
end UART_RX_Beh;

architecture Behavioral of UART_RX_Beh is

constant Bit_Period : time := 1000000000/Baud_Rate * 1 ns; -- длительность одного бита

begin

process
    -- переменные для бита четности и данных
    variable data_bits        : STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
    variable parity_bit_value : STD_LOGIC;
    variable data_parity      : STD_LOGIC;
    -- флаг продолжения передачи, на случай, если число стоп-бит установлено равным нулю
    variable UART_transaction : STD_LOGIC := '0';
    
begin 
    data <= (others => '0');
    data_valid <= '0';
    parity_error <= '0';  
    
    -- если число стоп-бит установлено равным нулю и это продолжение передачи и сейчас принять
    -- старт бит, то ждем длительности одного бита, чтобы попасть на середину первого бита данных
    if (UART_transaction = '1') and (rx = '0') then
       wait for Bit_Period;
    
    -- иначе сбрасываем флаг продолжения передачи, ожидаем спада сигнала rx и после его появления ждем
    -- полторы длительности одного бита, чтобы попасть на середину первого бита данных
    else      
       UART_transaction := '0';
       wait until falling_edge(rx);
       wait for 1.5*Bit_Period;
    end if;
    
    UART_transaction := '1';
    
    -- считываем все биты данных кроме последнего 
    for idx in 0 to Byte_Size-2 loop 
        data_bits(idx) := rx;
        wait for Bit_Period;
    end loop;
    
    -- считываем последний бит 
    data_bits(Byte_Size-1) := rx;
    
    if Parity_Bit = 0 then -- если бит четности не используется, выдаем полученные данные на выход,
        data <= data_bits; -- так как бита четности и стоп-бита может и не быть
        data_valid <= '1';
        parity_error <= '0';
    else  -- принимаем бит четности, подсчитываем четность данных и выдаем полученные данные на выход
        wait for Bit_Period;
        parity_bit_value := rx;
        
        data_parity := '0';
        for idx in 0 to Byte_Size-1 loop 
            data_parity := data_parity xor data_bits(idx);
        end loop;
        data_parity := data_parity xor parity_bit_value;
        
        data <= data_bits;
        data_valid <= '1';
        if (data_parity = '1' and Parity_Bit = 1) or   -- even parity
           (data_parity = '0' and Parity_Bit = 2) then -- odd parity
           parity_error <= '1';
        else
           parity_error <= '0';
        end if;
    end if;
    wait for Bit_Period;
    
    -- оставшиеся стоп-биты на алгоритм влияния не оказывают
end process;


end Behavioral;
