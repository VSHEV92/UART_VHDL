--------------------------------------------------------------------------------------------------------------
----------------------------------- Синтезируемый блок передатчика UART --------------------------------------
-- Generics блока задают параметры передатчика, такие как частота тактового сигнала clk, задержка выдачи данных 
-- из FIFO в тактах, скорость в бодах/с, количество бит в передаваемом слове, количество стоп-битов, 
-- наличие бита четности. Предполагается, что данные для передачи будут считыватся из FIFO. Вход fifo_empty - флаг
-- от FIFO, указывающий, что оно пустое; data - данные, полученные от FIFO;  reset - сигнал сброса, активный
-- уровень '1'. Выходы: fifo_re - сигнал запроса данных из FIFO; tx - сигнал для UART приемника.
--------------------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_TX is
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
end UART_TX;

architecture Behavioral of UART_TX is

constant Bit_Period : integer := Clk_Freq/Baud_Rate;  -- количество тактов на бит

-- сигналы для конечного автомата управления
type UART_RX_FSM_Type is (IDLE, FIFO_RE_STATE, WAIT_FIFO_DATA, GET_FIFO_DATA,
                          START_BIT, DATA_BITS, PARITY_STATE, STOP_BIT_1, STOP_BIT_2);
signal UART_RX_FSM_State : UART_RX_FSM_Type;
signal Baud_Gen_Reset  : std_logic;
signal Bit_Count_Reset : std_logic;

signal Baud_Generator_Counter : integer;
signal Baud_Generator_Done : std_logic; 

signal Bit_Counter : integer;
signal Bit_Counter_Done : std_logic; 

signal Data_from_FIFO : std_logic_vector(Byte_Size-1 downto 0);
signal Parity_Bit_Value : std_logic;

begin

-- счетчик, отсчитывающий интервал времени, равный длительности UART бита 
Baud_Generator: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' or Baud_Gen_Reset = '1' then
            Baud_Generator_Counter <= 0;
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

-- счетчик числа переданных бит даннrx_falling_egdeых
-- сигнал Bit_Counter_Done становится равным '1', если передано заданное число бит
Transmitted_Bits_Counter: process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' or Bit_Count_Reset = '1' then
            Bit_Counter <= 0;
            Bit_Counter_Done <= '0';  
        elsif Baud_Generator_Done = '1' then
            Bit_Counter <= Bit_Counter + 1;
            Bit_Counter_Done <= '0'; 
            if Bit_Counter = Byte_Size-2 then
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
            
                -- если FIFO, из которого считываются данные не пустое,   
                -- то запрашиваем данные из FIFO
                when IDLE =>
                    if fifo_empty = '0' then  
                        UART_RX_FSM_State <= FIFO_RE_STATE;
                    end if;
                    
                -- посылаем сигнал запроса данных из FIFO;  в зависимости от Fifo_Latency
                -- данные будут получены на следующем такте или через один такт clk
                when FIFO_RE_STATE =>    
                    if Fifo_Latency = 1 then  
                        UART_RX_FSM_State <= GET_FIFO_DATA;
                    else
                        UART_RX_FSM_State <= WAIT_FIFO_DATA;    
                    end if;
                    
                -- ожидаем данные из FIFO один такт
                when WAIT_FIFO_DATA =>
                    UART_RX_FSM_State <= GET_FIFO_DATA;

               -- записываем данные из FIFO во внутренний регистр
                when GET_FIFO_DATA =>
                    UART_RX_FSM_State <= START_BIT;
                
                -- выставляем старт-бит
                when START_BIT =>
                    if Baud_Generator_Done = '1' then
                        UART_RX_FSM_State <= DATA_BITS;
                    end if;
                    
                -- поступление сигнала Bit_Counter_Done означает, что выданы все биты
                when DATA_BITS =>    
                    if Baud_Generator_Done = '1' and Bit_Counter_Done = '1' then
                        if Parity_Bit /= 0 then -- если присутствует бит четности, выдаем его
                            UART_RX_FSM_State <= PARITY_STATE;
                        elsif Stop_Bits /= 0 then -- если присутствуют стоп-биты, выдаем их  
                            UART_RX_FSM_State <= STOP_BIT_1;
                        elsif fifo_empty = '0' then  -- если входное FIFO все еще не пустое, считываем новое слово данных
                            UART_RX_FSM_State <= FIFO_RE_STATE;
                        else    
                            UART_RX_FSM_State <= IDLE; -- иначе передача закончилась
                        end if;    
                    end if;            
                
                -- выдаем бит четности
                when PARITY_STATE =>    
                    if Baud_Generator_Done = '1' then
                        if Stop_Bits /= 0 then -- если присутствуют стоп-биты, выдаем их  
                            UART_RX_FSM_State <= STOP_BIT_1;
                        elsif fifo_empty = '0' then  -- если входное FIFO все еще не пустое, считываем новое слово данных
                            UART_RX_FSM_State <= FIFO_RE_STATE;                               
                        else
                            UART_RX_FSM_State <= IDLE; -- иначе передача закончилась
                        end if;    
                    end if;            
                
                -- выдаем первый стоп-бит
                when STOP_BIT_1 =>    
                    if Baud_Generator_Done = '1' then
                        if Stop_Bits = 2 then -- если присутствует второй стоп-бит, выдаем его  
                            UART_RX_FSM_State <= STOP_BIT_2;
                       elsif fifo_empty = '0' then  -- если входное FIFO все еще не пустое, считываем новое слово данных
                            UART_RX_FSM_State <= FIFO_RE_STATE;                           
                        else
                            UART_RX_FSM_State <= IDLE; -- иначе передача закончилась
                        end if;    
                    end if;
                
                -- получаем выдаем второй стоп-бит
                when STOP_BIT_2 =>    
                    if Baud_Generator_Done = '1' then
                        if fifo_empty = '0' then  -- если входное FIFO все еще не пустое, считываем новое слово данных
                            UART_RX_FSM_State <= FIFO_RE_STATE;                              
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
        -- запрос на выдачу данных из FIFO не выдается
        when IDLE =>
            Baud_Gen_Reset <= '1';
            Bit_Count_Reset <= '1';
            fifo_re <= '0';
                           
        -- выдается запрос на получение данных из FIFO
        when FIFO_RE_STATE =>    
            Baud_Gen_Reset <= '1';
            Bit_Count_Reset <= '1';
            fifo_re <= '1';
                       
        -- ожидаются данные из FIFO
        when WAIT_FIFO_DATA =>    
            Baud_Gen_Reset <= '1';
            Bit_Count_Reset <= '1';
            fifo_re <= '0';
      
        -- записываем данные из FIFO во внутренный регистр
        when GET_FIFO_DATA =>    
            Baud_Gen_Reset <= '1';
            Bit_Count_Reset <= '1';
            fifo_re <= '0';
            
         -- выдаем старт-бит, Baud_Generator отсчитывает длительность бита
        when START_BIT =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            fifo_re <= '0';
                               
        -- счетчик Baud_Generator отсчитывает длительность бита
        -- счетчик Transmitted_Bits_Counter отсчитывает число полученных бит
        when DATA_BITS =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '0';
            fifo_re <= '0';
            
        -- выдаем бит четности    
        -- счетчик Baud_Generator отсчитывает длительность бита
        when PARITY_STATE =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            fifo_re <= '0';   
        
        -- выдаем первый стоп бит            
        -- счетчик Baud_Generator отсчитывает длительность бита
        when STOP_BIT_1 =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            fifo_re <= '0';   
         
        -- выдаем второй стоп бит
        -- счетчик Baud_Generator отсчитывает длительность бита
        when STOP_BIT_2 =>    
            Baud_Gen_Reset <= '0';
            Bit_Count_Reset <= '1';
            fifo_re <= '0';   
                   
        when others =>
            Baud_Gen_Reset <= '1';
            Bit_Count_Reset <= '1';
            fifo_re <= '0';   
    end case;
end process;

-- внутренний регистр для записи данных от FIFO
input_data_reg: process(clk)
begin
    if rising_edge(clk) then
        if UART_RX_FSM_State = GET_FIFO_DATA then
            Data_from_FIFO <= data;
        end if; 
    end if;
end process;

-- вычисление бита четности
parity_control: process(clk)
    variable data_bits_var  : STD_LOGIC_VECTOR (Byte_Size-1 downto 0);
    variable parity_bit_var : STD_LOGIC;
    variable data_parity    : STD_LOGIC;
begin
    if rising_edge(clk) then
        data_bits_var := Data_from_FIFO;
        data_parity := '0';
        for idx in 0 to Byte_Size-1 loop 
            data_parity := data_parity xor data_bits_var(idx);
        end loop;
        
        if (data_parity = '1' and Parity_Bit = 1) or   -- even parity
           (data_parity = '0' and Parity_Bit = 2) then -- odd parity
           Parity_Bit_Value <= '1';
        else
           Parity_Bit_Value <= '0';
        end if;
    end if;
end process;

-- процесс управления выходом TX
tx_control: process(clk)
begin    
    if rising_edge(clk) then
        if (UART_RX_FSM_State = IDLE) or
           (UART_RX_FSM_State = STOP_BIT_1) or 
           (UART_RX_FSM_State = STOP_BIT_2) then
           tx <= '1';
        elsif (UART_RX_FSM_State = FIFO_RE_STATE) or
              (UART_RX_FSM_State = WAIT_FIFO_DATA) or 
              (UART_RX_FSM_State = GET_FIFO_DATA) or
              (UART_RX_FSM_State = START_BIT) then
            tx <= '0';
        elsif (UART_RX_FSM_State = DATA_BITS) then
            tx <= Data_from_FIFO(Bit_Counter);
        else
            tx <= Parity_Bit_Value;
        end if;           
    end if;
end process;

end Behavioral;
