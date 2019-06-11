------------------------------------------------------------------
--  lcd.vhd -- general LCD testing program
------------------------------------------------------------------
--  Author -- Dan Pederson, 2004
--			  -- Barron Barnett, 2004
--			  -- Jacob Beck, 2006
------------------------------------------------------------------
--  This module is a test module for implementing read/write and
--  initialization routines for an LCD on the Digilab boards
------------------------------------------------------------------
--  Revision History:								    
--  05/27/2004(DanP):  created
--  07/01/2004(BarronB): (optimized) and added writeDone as output
--  08/12/2004(BarronB): fixed timing issue on the D2SB
--  12/07/2006(JacobB): Revised code to be implemented on a Nexys Board
--				Changed "Hello from Digilent" to be on one line"
--				Added a Shift Left command so that the message
--				"Hello from Diligent" is shifted left by 1 repeatedly
--				Changed the delay of character writes
------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity lcd is
    Port ( LCD_DB: out std_logic_vector(7 downto 0);		--DB( 7 through 0)
           RS:out std_logic;  				--WE
           RW:out std_logic;				--ADR(0)
	   CLK:in std_logic;				--GCLK2
	   --ADR1:out std_logic;				--ADR(1)
	   --ADR2:out std_logic;				--ADR(2)
	   --CS:out std_logic;				--CSC
	   OE:out std_logic;				--OE
	   rst:in std_logic;		--BTN
	   --rdone: out std_logic);			--WriteDone output to work with DI05 test
		leds : out std_logic_vector (7 downto 0);
		ps2d, ps2c: in std_logic
		);
end lcd;

architecture Behavioral of lcd is
			    
------------------------------------------------------------------
--  Component Declarations
COMPONENT kb_code port (
				clk, reset: in  std_logic; --clk da fpga
				ps2d, ps2c: in  std_logic; 
				rd_key_code: in std_logic; -- libera o buffer
				key_code: out std_logic_vector(7 downto 0);--tecla no buffer
				kb_buf_empty: out std_logic -- tecla foi escrita no buffer
				
				
			);
	END COMPONENT kb_code;
------------------------------------------------------------------

------------------------------------------------------------------
--  Local Type Declarations
-----------------------------------------------------------------
--  Symbolic names for all possible states of the state machines.

	--LCD control state machine
	type mstate is (					  
		stFunctionSet,		 			--Initialization states
		stDisplayCtrlSet,
		stDisplayClear,
		stPowerOn_Delay,  				--Delay states
		stFunctionSet_Delay,
		stDisplayCtrlSet_Delay, 	
		stDisplayClear_Delay,
		stInitDne,					--Display charachters and perform standard operations
		stActWr,
		stCharDelay					--Write delay for operations
		--stWait					--Idle state
	);

	--Write control state machine
	type wstate is (
		stRW,						--set up RS and RW
		stEnable,					--set up E
		stIdle						--Write data on DB(0)-DB(7)
	);
	type jestados is (
		jEspera,
		jAcerto,
		jErro,
		jPerde
	);
	type mleitor is (
		minicial,
		mmeio,
		mfinal
	);

------------------------------------------------------------------
--  Signal Declarations and Constants
------------------------------------------------------------------
	--These constants are used to initialize the LCD pannel.

	--FunctionSet:
		--Bit 0 and 1 are arbitrary
		--Bit 2:  Displays font type(0=5x8, 1=5x11)
		--Bit 3:  Numbers of display lines (0=1, 1=2)
		--Bit 4:  Data length (0=4 bit, 1=8 bit)
		--Bit 5-7 are set
	--DisplayCtrlSet:
		--Bit 0:  Blinking cursor control (0=off, 1=on)
		--Bit 1:  Cursor (0=off, 1=on)
		--Bit 2:  Display (0=off, 1=on)
		--Bit 3-7 are set
	--DisplayClear:
		--Bit 1-7 are set	
	signal clkCount:std_logic_vector(5 downto 0);
	signal activateW:std_logic:= '0';		    			--Activate Write sequence
	signal count:std_logic_vector (16 downto 0):= "00000000000000000";	--15 bit count variable for timing delays
	signal delayOK:std_logic:= '0';						--High when count has reached the right delay time
	signal OneUSClk:std_logic;						--Signal is treated as a 1 MHz clock	
	signal stCur:mstate:= stPowerOn_Delay;	--LCD control state machine
	signal jAtual:jestados:= jEspera;
	signal jNext:jestados;
	signal stNext:mstate;
	signal matual: mleitor:= minicial;
	signal stCurW:wstate:= stIdle; 						--Write control state machine
	signal stNextW:wstate;
	signal writeDone:std_logic:= '0';		--Command set finish
	signal liberaBuf : std_logic := '0';
	signal keyRead : std_logic_vector (7 downto 0):= "00000000";
	signal keybuffer : std_logic_vector (7 downto 0);
	signal bufEmpty : std_logic ;
	signal errocount: UNSIGNED (3 DOWNTO 0):= "0000";
	signal teclou : std_logic := '0';
	signal leu : std_logic := '0';
	
	type SHOW_T is array(integer range 0 to 5) of std_logic_vector(9 downto 0);
	signal show : SHOW_T := (
		0 => "10"&X"2E",
		1 => "10"&X"2E",
		2 => "10"&X"2E",
		3 => "10"&X"2E",
		4 => "10"&X"2E",
		5 => "10"&X"2E"
		);
	
	--signal escritura: std_logic_vector (23 downto 0) := ""
	
	type LCD_CMDS_T is array(integer range 0 to 13) of std_logic_vector(9 downto 0);
	signal LCD_CMDS : LCD_CMDS_T := (
						 0 => "00"&X"3C",			--Function Set
					    1 => "00"&X"0C",			--Display ON, Cursor OFF, Blink OFF
					    2 => "00"&X"01",			--Clear Display
					    3 => "00"&X"02", 			--return home

					    4 => "10"&X"48", 			--H 
					    5 => "10"&X"65",  			--e
					    6 => "10"&X"6C",  			--l
					    7 => "10"&X"6C", 			--l
					    8 => "10"&X"6F", 			--o
					    9 => "10"&X"20",  			--space
					    10 => "10"&X"46", 			--F
					    11 => "10"&X"72", 			--r
						 12 => "10"&X"72", 			--r
						 13 => "10"&X"72");

	signal lcd_cmd_ptr : integer range 0 to LCD_CMDS'HIGH + 1 := 0;
begin
	 leds(0) <= keyRead(0);
	 leds(1) <= keyRead(1);
	 leds(2) <= keyRead(2);
	 leds(3) <= keyRead(3);
	 leds(4) <= keyRead(4);
	 leds(5) <= keyRead(5);
	 leds(6) <= keyRead(6);
	 leds(7) <= keyRead(7);
	 
	 LCD_CMDS(0) <= "00"&X"3C";
	 LCD_CMDS(1) <= "00"&X"0C";
	 LCD_CMDS(2) <= "00"&X"01";
	 LCD_CMDS(3) <= "00"&X"02";	
	 
	 LCD_CMDS(4) <= show(0);
	 LCD_CMDS(5) <= show(1);
	 LCD_CMDS(6) <= show(2);
	 LCD_CMDS(7) <= show(3);
	 LCD_CMDS(8) <= show(4);
	 LCD_CMDS(9) <= show(5);
	 LCD_CMDS(10) <= show(3);

	 
	 LCD_CMDS(11) <= "1000100000";
	 
	 LCD_CMDS(12) <= "10"&"0011"&(std_logic_vector(errocount));
	 LCD_CMDS(13) <= "00"&X"02";
	 
kbc: kb_code port map (CLK, rst, ps2d, ps2c, liberaBuf, keybuffer, bufEmpty);
 	
	--  This process counts to 50, and then resets.  It is used to divide the clock signal time.
	process (CLK, oneUSClk)
    		begin
			if (CLK = '1' and CLK'event) then
				clkCount <= clkCount + 1;
			end if;
		end process;
	--  This makes oneUSClock peak once every 1 microsecond

	oneUSClk <= clkCount(5);
	--  This process incriments the count variable unless delayOK = 1.
	process (oneUSClk, delayOK)
		begin
			if (oneUSClk = '1' and oneUSClk'event) then
				if delayOK = '1' then
					count <= "00000000000000000";
				else
					count <= count + 1;
				end if;
			end if;
		end process;

	--This goes high when all commands have been run
	writeDone <= '1' when (lcd_cmd_ptr = LCD_CMDS'HIGH) 
		else '0';
	--rdone <= '1' when stCur = stWait else '0';
	--Increments the pointer so the statemachine goes through the commands
	process (lcd_cmd_ptr, oneUSClk)
   		begin
			if (oneUSClk = '1' and oneUSClk'event) then
				if ((stNext = stInitDne or stNext = stDisplayCtrlSet or stNext = stDisplayClear) and writeDone = '0') then 
					lcd_cmd_ptr <= lcd_cmd_ptr + 1;
				elsif stCur = stPowerOn_Delay or stNext = stPowerOn_Delay then
					lcd_cmd_ptr <= 0;
				elsif teclou = '1' then
					lcd_cmd_ptr <= 3;
				else
					lcd_cmd_ptr <= lcd_cmd_ptr;
				end if;
			end if;
		end process;
	
	--  Determines when count has gotten to the right number, depending on the state.

	delayOK <= '1' when ((stCur = stPowerOn_Delay and count = "00100111001010010") or 			--20050  
					(stCur = stFunctionSet_Delay and count = "00000000000110010") or	--50
					(stCur = stDisplayCtrlSet_Delay and count = "00000000000110010") or	--50
					(stCur = stDisplayClear_Delay and count = "00000011001000000") or	--1600
					(stCur = stCharDelay and count = "11111111111111111"))			--Max Delay for character writes and shifts
					--(stCur = stCharDelay and count = "00000000000100101"))		--37  This is proper delay between writes to ram.
		else	'0';
  	
	-- This process runs the LCD status state machine
	process (oneUSClk, rst)
		begin
			if oneUSClk = '1' and oneUSClk'Event then
				if rst = '1' then
					stCur <= stPowerOn_Delay;
				else
					stCur <= stNext;
				end if;
			end if;
		end process;

	
	--  This process generates the sequence of outputs needed to initialize and write to the LCD screen
	process (stCur, delayOK, writeDone, lcd_cmd_ptr)
		begin   
		
			case stCur is
			
				--  Delays the state machine for 20ms which is needed for proper startup.
				when stPowerOn_Delay =>
					if delayOK = '1' then
						stNext <= stFunctionSet;
					else
						stNext <= stPowerOn_Delay;
					end if;
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '0';

				-- This issuse the function set to the LCD as follows 
				-- 8 bit data length, 2 lines, font is 5x8.
				when stFunctionSet =>
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '1';	
					stNext <= stFunctionSet_Delay;
				
				--Gives the proper delay of 37us between the function set and
				--the display control set.
				when stFunctionSet_Delay =>
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '0';
					if delayOK = '1' then
						stNext <= stDisplayCtrlSet;
					else
						stNext <= stFunctionSet_Delay;
					end if;
				
				--Issuse the display control set as follows
				--Display ON,  Cursor OFF, Blinking Cursor OFF.
				when stDisplayCtrlSet =>
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '1';
					stNext <= stDisplayCtrlSet_Delay;

				--Gives the proper delay of 37us between the display control set
				--and the Display Clear command. 
				when stDisplayCtrlSet_Delay =>
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '0';
					if delayOK = '1' then
						stNext <= stDisplayClear;
					else
						stNext <= stDisplayCtrlSet_Delay;
					end if;
				
				--Issues the display clear command.
				when stDisplayClear	=>
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '1';
					stNext <= stDisplayClear_Delay;

				--Gives the proper delay of 1.52ms between the clear command
				--and the state where you are clear to do normal operations.
				when stDisplayClear_Delay =>
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '0';
					if delayOK = '1' then
						stNext <= stInitDne;
					else
						stNext <= stDisplayClear_Delay;
					end if;
				
				--State for normal operations for displaying characters, changing the
				--Cursor position etc.
				when stInitDne =>		
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '0';
					stNext <= stActWr;

				when stActWr =>		
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '1';
					stNext <= stCharDelay;
					
				--Provides a max delay between instructions.
				when stCharDelay =>
					RS <= LCD_CMDS(lcd_cmd_ptr)(9);
					RW <= LCD_CMDS(lcd_cmd_ptr)(8);
					LCD_DB <= LCD_CMDS(lcd_cmd_ptr)(7 downto 0);
					activateW <= '0';					
					if delayOK = '1' then
						stNext <= stInitDne;
					else
						stNext <= stCharDelay;
					end if;
			end case;
		
		end process;					
								   
 	--This process runs the write state machine
	process (oneUSClk, rst)
		begin
			if oneUSClk = '1' and oneUSClk'Event then
				if rst = '1' then
					stCurW <= stIdle;
				else
					stCurW <= stNextW;
				end if;
			end if;
		end process;

	--This genearates the sequence of outputs needed to write to the LCD screen
	process (stCurW, activateW)
		begin   
		
			case stCurW is
				--This sends the address across the bus telling the DIO5 that we are
				--writing to the LCD, in this configuration the adr_lcd(2) controls the
				--enable pin on the LCD
				when stRw =>
					OE <= '0';
					--CS <= '0';
					--ADR2 <= '1';
					--ADR1 <= '0';
					stNextW <= stEnable;
				
				--This adds another clock onto the wait to make sure data is stable on 
				--the bus before enable goes low.  The lcd has an active falling edge 
				--and will write on the fall of enable
				when stEnable => 
					OE <= '0';
					--CS <= '0';
					--ADR2 <= '0';
					--ADR1 <= '0';
					stNextW <= stIdle;
				
				--Waiting for the write command from the instuction state machine
				when stIdle =>
					--ADR2 <= '0';
					--ADR1 <= '0';
					--CS <= '1';
					OE <= '1';
					if activateW = '1' then
						stNextW <= stRw;
					else
						stNextW <= stIdle;
					end if;
				end case;
		end process;
		process(rst,oneUSClk,teclou,keyread)
			begin
				if rst = '1' then
					show(0) <= "10"&X"2E";
					show(1) <= "10"&X"2E";
					show(2) <= "10"&X"2E";
					show(3) <= "10"&X"2E";
					show(4) <= "10"&X"2E";
					show(5) <= "10"&X"2E";
					errocount <= "0000";

				elsif oneUSClk = '1' and oneUSClk'Event then
							if errocount >= 7 then
								show(0) <= "10"&X"4B";
								show(1) <= "10"&X"4B";
								show(2) <= "10"&X"4B";
								show(3) <= "10"&X"4B";
								show(4) <= "10"&X"4B";
								show(5) <= "10"&X"4B";
							elsif teclou = '1' then
								case keyread is
									when "00011100" =>
										show(0) <= "10"&X"41";
										show(1 to 5) <= show(1 to 5);
									when "00110010" =>
										show(1) <= "10"&X"42";
										show(0) <= show(0);
										show(2 to 5) <= show(2 to 5);
									when "00100011" =>
										show(2) <= "10"&X"44";
										show(0 to 1) <= show(0 to 1);
										show(3 to 5) <= show(3 to 5);
									when "00111100" =>
										show(3) <= "10"&X"55";
										show(0 to 2) <= show(0 to 2);
										show(4 to 5) <= show(4 to 5);
									when "00011010" =>
										show(4) <= "10"&X"5A";
										show(0 to 3) <= show(0 to 3);
										show(5) <= show(5);
									when "01000011" =>
										show(5) <= "10"&X"49";
										show(0 to 4) <= show(0 to 4);
									when others =>
										errocount <= errocount + 1;
										show(0 to 5)<= show(0 to 5);
								end case;
								leu <= '1';	
							else
								show<=show;
							end if;
				end if;
			end process;
	process(oneUSClk)
	begin
	if oneUSClk = '1' and oneUSClk'Event then
		case matual is
			when minicial=>
				if bufempty = '0' then
					matual <= mmeio;
				end if;
			
			when mmeio =>
				if leu <= '1' then
					matual <= mfinal;
				end if;
				
			when mfinal =>
				matual <= minicial;
		end case;
	end if;
	end process;
	
	process(oneUSClk)
	begin
	if oneUSClk = '1' and oneUSClk'Event then
		case matual is
			when minicial =>
				liberaBuf <= '0';
			when mmeio =>
				teclou <= '1';
				keyRead <= keybuffer;
			when mfinal =>
				teclou <= '0';
				leu<= '0';
				liberaBuf <= '1';
		end case;
	end if;
	end process;
				
				
end Behavioral;