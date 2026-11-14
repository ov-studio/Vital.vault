----------------------------------------------------------------
--[[ Resource: Dynamic Sky
     Script: configs/clock.lua
     Author: ov-studio
     Developer(s): Аниса
     DOC: 13/11/2026
     Desc: Clock and server sync ]]--
----------------------------------------------------------------


-----------------
--[[ Configs ]]--
-----------------

Config.start_time           = 9.0   -- hour of day at resource start (0-24)
Config.day_length_min       = 24.0  -- real minutes for a full 24h day (0 = frozen)
Config.sync_interval_ms     = 5000  -- server re-sync period
Config.allow_client_control = true  -- clients may use /time /weather /timescale (set false on public servers)
