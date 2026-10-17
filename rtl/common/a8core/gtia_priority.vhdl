---------------------------------------------------------------------------
-- (c) 2013 mark watson
-- I am happy for anyone to use this for non-commercial use.
-- If my vhdl files are used commercially or otherwise sold,
-- please contact me for explicit permission at scrameta (gmail).
-- This applies for source and binary form and derived works.
---------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

ENTITY gtia_priority IS
PORT 
( 
	PRIOR : in std_logic_vector(4 downto 0);
	P0 : in std_logic;
	P1 : in std_logic;
	P2	: in std_logic;
	P3 : in std_logic;
	PF0 : in std_logic;
	PF1 : in std_logic;
	PF2 : in std_logic;
	PF3 : in std_logic;
	BK : in std_logic;
	
	P0_OUT : out std_logic;
	P1_OUT : out std_logic;
	P2_OUT : out std_logic;
	P3_OUT : out std_logic;
	PF0_OUT : out std_logic;
	PF1_OUT : out std_logic;
	PF2_OUT : out std_logic;
	PF3_OUT : out std_logic;
	BK_OUT : out std_logic
);
END gtia_priority;

ARCHITECTURE vhdl OF gtia_priority IS
	signal P01 : std_logic;
	signal P23 : std_logic;
	
	signal PF01 : std_logic;
	signal PF23 : std_logic;
	
	signal PRI01 : std_logic;
	signal PRI12 : std_logic;
	signal PRI23 : std_logic;
	signal PRI03 : std_logic;
	
	signal PRI0 : std_logic;
	signal PRI1 : std_logic;
	signal PRI2 : std_logic;
	signal PRI3 : std_logic;
	signal MULTI : std_logic;

	signal SF3 : std_logic;
	
begin
	-- Use actual GTIA logic...
	P01 <= P0 or P1;
	P23 <= P2 or P3;

	PF01 <= PF0 or PF1;
	PF23 <= PF2 or PF3;
	
	PRI0 <= prior(0);
	PRI1 <= prior(1);
	PRI2 <= prior(2);
	PRI3 <= prior(3);
	MULTI <= prior(4);
	
	PRI01 <= PRI0  or  PRI1;
	PRI12 <= PRI1  or  PRI2;
	PRI23 <= PRI2  or  PRI3;
	PRI03 <= PRI0  or  PRI3;
	
	P0_OUT <= P0  and   not (PF01 and PRI23)  and   not (PRI2 and PF23);
	P1_OUT <= P1  and   not (PF01 and PRI23)  and   not (PRI2 and PF23)  and  ( not P0  or  MULTI);
	P2_OUT <= P2  and   not P01  and   not (PF23 and PRI12)  and   not (PF01 and  not PRI0);
	P3_OUT <= P3  and   not P01  and   not (PF23 and PRI12)  and   not (PF01 and  not PRI0)  and  ( not P2  or  MULTI);
	PF0_OUT <= PF0  and   not (P23 and PRI0)  and   not (P01 and PRI01)  and   not SF3;
	PF1_OUT <= PF1  and   not (P23 and PRI0)  and   not (P01 and PRI01)  and   not SF3;
	PF2_OUT <= PF2  and   not (P23 and PRI03)  and   not (P01 and  not PRI2)  and   not SF3;
	SF3 <= PF3  and   not (P23 and PRI03)  and   not (P01 and  not PRI2);
	PF3_OUT <= SF3;
	BK_OUT <=  not P01  and   not P23  and   not PF01  and   not PF23;
	
end vhdl;