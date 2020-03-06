--------------------------------------------------------------------------------------------------------------
-------------------------------- Поведенческая модель передатчика UART ---------------------------------------
-- Входные данные для передачи считываются из файла, путь к которому указывается в generic Input_Data_File.
-- Остальные generics задают параметры передатчика, такие как скорость в бодах/с, количество бит в передаваемом слове,
-- количество стоп-битов, наличие бита четности. С помощью переменной random_delay, создается случайная задержка
-- по времени между UART передачами (от 10 до 30 длительностей бита). Выход tx - сигнал от UART передатчика,
-- выходы data (передаваемое слово) и data_valid (строб сигнал для data) служат для проверки корректности 
-- работы блока при тестировании. Выход done - флаг, указывающий, что переданы все данные из файла.
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use STD.TEXTIO.ALL;

use ieee.math_real.uniform;
use ieee.math_real.floor;

use IEEE.NUMERIC_STD.ALL;
 
entity UART_TX_Beh is
    Generic( Input_Data_File : string;     -- путь к файлу с передаваемыми данными
             Baud_Rate       : integer;    -- 9600, 19200, 38400, 57600, 115200, 230400, 460800, 921600
             Byte_Size       : integer;    -- 5, 6, 7, 8, 9
             Stop_Bits       : integer;    -- 0, 1, 2
             Parity_Bit      : integer     -- 0 - none, 1 - even, 2 - odd,
    );
    Port ( tx         : out STD_LOGIC;                                -- UART TX
           data       : out STD_LOGIC_VECTOR (Byte_Size-1 downto 0);  -- передаваемый вектор (для проверки)
           data_valid : out STD_LOGIC;                                -- строб для передаваемого вектор
           done       : out STD_LOGIC                                 -- флаг, указывающий, что переданы все данные из файла
    );
end UART_TX_Beh;

architecture Behavioral of UART_TX_Beh is

constant Bit_Period : time := 1000000000/Baud_Rate * 1 ns; -- длительность одного бита
file file_HANDLER : text;

begin

process
    -- переменные для считывания из файла
    variable file_LINE : line;
    variable file_DATA : integer;
    -- переменные для генерирования случайной задержки от 10 до 30 Bit_Period
    variable seed1 : positive;
    variable seed2 : positive;
    variable random_value : real;
    variable random_delay : integer;
    -- переменная для выдачи signal
    variable data_bits : std_logic_vector(Byte_Size-1 downto 0);
    -- переменные для вычисления бита четности
    variable parity_bit_value : std_logic;
    
begin 
    -- считывание данных из файла
    file_open(file_HANDLER, Input_Data_File,  read_mode);
    while not endfile(file_HANDLER) loop
        readline(file_HANDLER, file_LINE);
        read(file_LINE, file_DATA);
        data_bits := std_logic_vector(to_unsigned(file_DATA, Byte_Size));
        
        -- начальная случайная задержка 
        uniform(seed1, seed2, random_value);
        random_delay := integer(floor(random_value*real(Bit_Period/ 1 ns)*20 + real(Bit_Period/ 1 ns)*10));
        tx <= '1';
        data <= (others => '0');
        data_valid <= '0';
        done <= '0';
        wait for random_delay * 1 ns;
    
        -- старт бит
        tx <= '0';
        data <= data_bits;
        data_valid <= '1';
        wait for Bit_Period;
        data_valid <= '0';
        
        -- данные
        for idx in 0 to Byte_Size-1 loop 
            tx <= data_bits(idx);
            wait for Bit_Period;
        end loop;
        
        -- бит четности
        parity_bit_value := '0';
        for idx in 0 to Byte_Size-1 loop 
            parity_bit_value := parity_bit_value xor data_bits(idx);
        end loop;
        if Parity_Bit = 1 then    -- even parity
            tx <= parity_bit_value;
            wait for Bit_Period;
        elsif Parity_Bit = 2 then    -- odd parity
            tx <= not parity_bit_value;
            wait for Bit_Period;
        end if;    
        
        -- стоп бит
        for idx in 0 to Stop_Bits-1 loop 
            tx <= '1';
            wait for Bit_Period;
        end loop;
    end loop;
 
    file_close(file_HANDLER);
    done <= '1';
    wait;
end process;

end Behavioral;
