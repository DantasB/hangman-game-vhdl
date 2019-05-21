----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    16:28:18 05/21/2019 
-- Design Name: 
-- Module Name:    Leitor_Tecla - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity Leitor_Tecla is
	port (
			clk, reset: in  std_logic; --clk da fpga
			ps2d, ps2c: in  std_logic; 
			rd_key_code: in std_logic; -- libera o buffer
			key_code: out std_logic_vector(7 downto 0);--tecla no buffer
			kb_buf_empty: out std_logic; -- tecla foi escrita no buffer
			leds : out std_logic_vector (7 downto 0)
		);
end Leitor_Tecla;

architecture Behavioral of Leitor_Tecla is

	COMPONENT kb_code port (
				clk, reset: in  std_logic; --clk da fpga
				ps2d, ps2c: in  std_logic; 
				rd_key_code: in std_logic; -- libera o buffer
				key_code: out std_logic_vector(7 downto 0);--tecla no buffer
				kb_buf_empty: out std_logic -- tecla foi escrita no buffer
			);
	END COMPONENT kb_code;
	
	type estados is (
	eInicial,
	eMeio,
	eFinal
	);
	
	signal eAtual : estados := eInicial;
	signal eProximo : estados;
	
	signal clkReduzido : std_logic := '0';
	
begin
	
	process(clk)
		variable contagem : UNSIGNED (5 downto 0) := "000000";
		BEGIN
			if (clk = '1' and clk'event) then
				if (contagem >= 9) then
					contagem := 0;
					clkReduzido<= not clkReduzido;
				else
					contagem := contagem + 1;
				end if;
			end if;
	end process;
	
	process(clkReduzido)
	begin
		if (clkReduzido = '1' and clkReduzido'event) then
		end if;
	end process;
	
end Behavioral;

