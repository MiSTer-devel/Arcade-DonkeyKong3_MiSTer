---------------------------------------------------------------------------------
-- 
-- *** WORK IN PROGRESS VERSION ***
--
-- Arcade: Donkey Kong 3 for MiSTer by gaz68 (https://github.com/gaz68)
-- July 2020 
-- 
-- Original Donkey Kong port to MiSTer by Sorgelig
-- 18 April 2018
-- 
---------------------------------------------------------------------------------
-- 
-- dkong Copyright (c) 2003 - 2004 Katsumi Degawa
-- T80   Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org) All rights reserved
-- T65   Copyright (c) 2002-2015 Daniel Wallner, Mike Johnson, Wolfgang Scherr, Morten Leikvoll
-- NES APU taken from the NES for MiSTer project
--
---------------------------------------------------------------------------------
-- 
-- Keyboard inputs :
--
--   F2          : Start 2 players
--   F1          : Start 1 player
--   SPACE       : Fire
--   UP,DOWN,LEFT,RIGHT arrows : Movements
--
-- MAME/IPAC/JPAC Style Keyboard inputs:
--   5           : Coin 1
--   6           : Coin 2
--   1           : Start 1 Player
--   2           : Start 2 Players
--   R,F,D,G     : Player 2 Movements (Cocktail mode only)
--   A           : Player 2 Fire
--   T           : Test mode (hold down for several seconds).
--
--
-- Joystick support.
--  
---------------------------------------------------------------------------------

                                *** Attention ***

ROM is not included. In order to use this arcade, you need to provide a correct ROM file.

To simplify the process .mra files are provided in the releases folder, that
specifies the required ROMs with checksums. The ROMs .zip filename refers to the
corresponding file of the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for
information on how to setup and use the environment.

Quickreference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/_Arcade/mame/<mame rom>.zip
/_Arcade/hbmame/<hbmame rom>.zip


