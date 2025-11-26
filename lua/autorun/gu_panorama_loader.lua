AddCSLuaFile("autorun/sh_gu_panorama_config.lua")
AddCSLuaFile("autorun/client/cl_gu_panorama.lua")

if SERVER then
    include("autorun/sh_gu_panorama_config.lua")
    include("autorun/server/sv_gu_panorama.lua")
else
    include("autorun/sh_gu_panorama_config.lua")
    include("autorun/client/cl_gu_panorama.lua")
end
