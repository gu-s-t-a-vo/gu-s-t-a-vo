local CONFIG = {}

CONFIG.LogoMaterial = "materials/gu_panorama/logo.png"
CONFIG.BackgroundMaterial = "materials/gu_panorama/background.png"
CONFIG.DefaultModel = "models/player/kleiner.mdl"
CONFIG.BodygroupIgnore = { -- bodygroup names to ignore when saving
}
CONFIG.SpawnFadeTime = 1.5
CONFIG.DataFolder = "gu_panorama"

function CONFIG:GetDataPath(steamid)
    return string.format("%s/%s.json", self.DataFolder, steamid)
end

_G.GU_PANORAMA_CONFIG = CONFIG
