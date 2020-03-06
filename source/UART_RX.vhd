--------------------------------------------------------------------------------------------------------------
------------------------------------- Синтезируемый блок приемника UART --------------------------------------
-- Generics блока задают параметры приемника, такие как частота тактового сигнала clk, скорость в бодах/с,
-- количество бит в передаваемом слове, количество стоп-битов, наличие бита четности. Вход rx - сигнал от
-- UART передатчика; reset - сигнал сброса, активный уровень '1'. Выходы: data - полученное слово данных,
-- data_valid - строб сигнал для полученных данных и флага ошибки четности, parity_error - флаг ошибки 
-- четности (активный уровень '1').
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_RX is
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
end UART_RX;

architecture Behavioral of UART_RX is

constant Bit_Period : integer := Clk_Freq/Baud_Rate;  -- количество тактов на бит
constant Bit_Period_Half : integer := Bit_Period/2;   -- количество тактов на половину бита

-- сигналы для конечного автомата управления
type UART_RX_FSM_Type is (IDLE, FALL_EDGE_DETECTED, START_BIT, DATA_BITS, PARITY_STATE, STOP_BIT_1, STOP_BIT_2);
signal UART_RX_FSM_State : UART_RX_FSM_Type;
signal Baud_Gen_Reset : std_logic;
signal Bit_Count_Reset : std_logic;
signal Data_Bits_Flag : std_logic;
signal Parity_Bit_Flag : std_logic;

signal Baud_Generator_Counter : integer;
signal Baud_Generator_Done : std_logic; 

signal Bit_Counter : integer;
signal Bit_Counter_Done : std_logic; 

signal input_shift_reg : std_logic_vector(2 downto 0);
signal rx_falling_egde : std_logic;

signal output_shift_reg : std_logic_vector(Byte_Size-1 downto 0);
signal output_shift_reg_done : std_logic;
signal delayed_output_shift_reg_done : std_logic;
signal falling_edge_output_shift_reg_done : std_logic;

signal received_parity_bit : std_logic;
signal parity_error_internal : std_logic;

signal delay_line_reg : std_logic_vector(9 downto 0);
signal Delay_Baud_Generator_Counter : std_logic;

begin
-- двойной триггер для защиты от метастабильности и обнаружитель спада
input_triggers: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            input_shift_reg <= (others => '1');
        else
            input_shift_reg(2 downto 1) <= input_shift_reg(1 downto 0);
            input_shift_reg(0) <= rx;
            rx_falling_egde <= not input_shift_reg(1) and input_shift_reg(2);
        end if;           
    end if;
end process;

-- при сбросе счетчик устанавливается в Bit_Period_Half, чтобы при обнаружении начала передачи
-- отсчитать половину периода бита и попасть на середину старт-бита
Baud_Generator: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' or Baud_Gen_Reset = '1' then
            Baud_Generator_Counter <= Bit_Period_Half;
            Baud_Generator_Done <= '0';  
        else
            Baud_Generator_Counter <= Baud_Generator_Counter + 1;
            Baud_Generator_Done <= '0'; 
            if Baud_Generator_Counter = Bit_Period then
                Baud_Generator_Counter <= 0;
                -- сигнал Baud_Generator_Done становится равным '1' каждые Bit_Period тактов
                Baud_Generator_Done <= '1';     
            end if;
        end if;
    end if;
end process; 

-- счетчик числа полученых бит
-- сигнал Bit_Counter_Done становится равным '1', если получено заданное число бит
Received_Bits_Counter: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' or Bit_Count_Reset = '1' then
            Bit_Counter <= 0;
            Bit_Counter_Done <= '0';  
        elsif Baud_Generator_Done = '1' then
            Bit_Counter <= Bit_Counter + 1;
            Bit_Counter_Done <= '0'; 
            if Bit_Counter = Byte_Size-2 then
                Bit_Counter <= 0;
                Bit_Counter_Done <= '1';     
            end if;
        end if;
    end if;
end process; 

-- процесс управления состояниями конечного автомата
FSM_States_Controller: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            UART_RX_FSM_State <= IDLE;
        else
            case UART_RX_FSM_State is
            
                -- если обнаружен спад сигнала rx, ждем половину длительности бита,
                -- чтобы попасть на середину старт-бита
                when IDLE =>
                    if rx_falling_egde = '1' then  
                        UART_RX_FSM_State <= FALL_EDGE_DETECTED;
                    end if;
                    
                -- поступление сигнала Baud_Generator_Done означает, что достигнута
                -- середина старт-бита    
                when FALL_EDGE_DETECTED =>    
                    if Baud_Generator_Done = '1' then  
                        UART_RX_FSM_State <= START_BIT;
                    end if;
                    
                -- ждем длительность бита и попадаем на биты данных
                when START_BIT =>    
                    if Baud_Generator_Done = '1' then  
                        UART_RX_FSM_State <= DATA_BITS;
                    end if;
                    
                -- поступление сигнала Bit_Counter_Done означает, что получены все биты
                when DATA_BITS =>    
                    if Baud_Generator_Done = '1' and Bit_Counter_Done = '1' then
                        if Parity_Bit /= 0 then -- если присутствует бит четности, считываем его
                            UART_RX_FSM_State <= PARITY_STATE;
                        elsif Stop_Bits /= 0 then -- если присутствуют стоп-биты, получаем их  
                            UART_RX_FSM_State <= STOP_BIT_1;
                        elsif input_shift_reg(2) = '0' then -- если нет бита четности и стоп-битов и input_shift_reg(2) равен '0'
                            UART_RX_FSM_State <= START_BIT; -- значит началась новая передача и это старт-бит                               
                        else
                            UART_RX_FSM_State <= IDLE; -- иначе передача закончилась
                        end if;    
                    end if;            
                
                -- получаем бит четности
                when PARITY_STATE =>    
                    if Baud_Generator_Done = '1' then
                        if Stop_Bits /= 0 then -- если присутствуют стоп-биты, получаем их  
                            UART_RX_FSM_State <= STOP_BIT_1;
                        elsif input_shift_reg(2) = '0' then -- если нет стоп-битов и input_shift_reg(2) равен '0'
                            UART_RX_FSM_State <= START_BIT; -- значит началась новая передача и это старт-бит                               
                        else
                            UART_RX_FSM_State <= IDLE; -- иначе передача закончилась
                        end if;    
                    end if;            
                
                -- получаем первый стоп-бит
                when STOP_BIT_1 =>    
                    if Baud_Generator_Done = '1' then
                        if Stop_Bits = 2 then -- если присутствует второй стоп-бит, получаем его  
                            UART_RX_FSM_State <= STOP_BIT_2;
                        elsif input_shift_reg(2) = '0' then -- если нет второго стоп-бита и input_shift_reg(2) равен '0'
                            UART_RX_FSM_State <= START_BIT; -- значит началась новая передача и это старт-бит                               
                        else
                            UART_RX_FSM_State <= IDLE; -- иначе передача закончилась
                        end if;    
                    end if;
                
                -- получаем второй стоп-бит
                when STOP_BIT_2 =>    
                    if Baud_Generator_Done = '1' then
                        if input_shift_reg(2) = '0' then    -- если input_shift_reg(2) равен '0'
                            UART_RX_FSM_State <= START_BIT; -- значит началась новая передача и это старт-бит                               
                        else
                            UART_RX_FSM_State <= IDLE; -- иначе передача закончилась
                        end if;    
                    end if;      
                    
                when others =>
                    UART_RX_FSM_State <= IDLE;
            end case;
        end if;
    end if;
end process;

-- процесс формирования выходных сигналов конечного автомата (комбинаторный)
FSM_Output_Controller: process(UART_RX_FSM_State)
begin
    case UART_RX_FSM_State is
        -- счетчики в состоянии сброса, флаги наличия данных и бита четности сброшены
        when IDLE =>
            Baud_Gen_Reset <= '1';
            Bit_Count_Reset <= '1';
            Data_Bits_Flag <= '0'; 
            Parity_Bit_Flag <= '0';
                       
        -- счетчик Baud_Generator отсчитывает половину длительности бита
        when FALL_EDGE_DETECTED =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            Data_Bits_Flag <= '0'; 
            Parity_Bit_Flag <= '0';
                       
        -- счетчик Baud_Generator отсчитывает длительность бита
        when START_BIT =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            Data_Bits_Flag <= '0'; 
            Parity_Bit_Flag <= '0';
                           
        -- счетчик Baud_Generator отсчитывает длительность бита
        -- счетчик Received_Bits_Counter отсчитывает число полученных бит
        -- флаг Data_Bits_Flag указывает, что принимаются биты данных
        when DATA_BITS =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '0';
            Data_Bits_Flag <= '1'; 
            Parity_Bit_Flag <= '0';
        
        -- счетчик Baud_Generator отсчитывает длительность бита
        -- флаг Parity_Bit_Flag указывает, что принимается бит четности
        when PARITY_STATE =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            Data_Bits_Flag <= '0'; 
            Parity_Bit_Flag <= '1';   
                    
        -- счетчик Baud_Generator отсчитывает длительность бита
        when STOP_BIT_1 =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            Data_Bits_Flag <= '0'; 
            Parity_Bit_Flag <= '0';
            
         -- счетчик Baud_Generator отсчитывает длительность бита
        when STOP_BIT_2 =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            Data_Bits_Flag <= '0'; 
            Parity_Bit_Flag <= '0';                 
                   
        when others =>
            Baud_Gen_Reset <= '1';
            Bit_Count_Reset <= '1';
            Data_Bits_Flag <= '0'; 
            Parity_Bit_Flag <= '0';
    end case;
end process;

-- линия задержки для сигнала Baud_Generator_Done
delay_line: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then  
            delay_line_reg <= (others => '0');
        else 
            delay_line_reg(9 downto 1) <= delay_line_reg(8 downto 0);
            delay_line_reg(0) <= Baud_Generator_Done;
            Delay_Baud_Generator_Counter <= delay_line_reg(9);
        end if;
    end if;
end process;    

-- регистр сдвига для данных
data_shift_register: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then  
            output_shift_reg <= (others => '0');
            output_shift_reg_done <= '0';
            
        elsif Delay_Baud_Generator_Counter = '1' then -- сдвигаем биты от старших разрядов к младшим,
            if Data_Bits_Flag = '1' then              -- чтобы первый полученный бит оказался в младшем разряде
                output_shift_reg(Byte_Size-1) <= input_shift_reg(2);       
                output_shift_reg(Byte_Size-2 downto 0) <= output_shift_reg(Byte_Size-1 downto 1);
            end if;
            
            output_shift_reg_done <= '0';    -- при поступлении последнего бита устанавливаем   
            if Bit_Counter_Done = '1' then   -- флаг окончания работы
                output_shift_reg_done <= '1';
            end if;
            
        end if;        
    end if;
end process;

-- принимаем бит четности
parity_reg: process(clk)
begin
    if rising_edge(clk) then
        if Delay_Baud_Generator_Counter = '1' and Parity_Bit_Flag = '1' then
            received_parity_bit <= input_shift_reg(2); 
        end if;
    end if;
end process;

-- проверяем четность и, если необходимо выставляем флаг ошибки
parity_control: process(clk)
    variable data_bits_var  : STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
    variable parity_bit_var : STD_LOGIC;
    variable data_parity    : STD_LOGIC;
begin
    if rising_edge(clk) then
        data_bits_var := output_shift_reg;
        parity_bit_var := received_parity_bit;
        data_parity := '0';
        for idx in 0 to Byte_Size-1 loop 
            data_parity := data_parity xor data_bits_var(idx);
        end loop;
        data_parity := data_parity xor parity_bit_var;
        
        if (data_parity = '1' and Parity_Bit = 1) or   -- even parity
           (data_parity = '0' and Parity_Bit = 2) then -- odd parity
           parity_error_internal <= '1';
        else
           parity_error_internal <= '0';
        end if;
    end if;
end process;

-- выходной регистр
output_register: process(clk)
begin
    if rising_edge(clk) then
        -- выдаем данные на выход по спаду сигнала output_shift_reg_done
        delayed_output_shift_reg_done <= output_shift_reg_done;
        falling_edge_output_shift_reg_done <= delayed_output_shift_reg_done and not output_shift_reg_done;
        data_valid <= '0';
        if falling_edge_output_shift_reg_done = '1' then
            data <= output_shift_reg;
            data_valid <= '1';
            parity_error <= parity_error_internal;
        end if;
    end if;
end process;

end Behavioral;
