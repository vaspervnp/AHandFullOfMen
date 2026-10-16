-- Aseprite pass of the art pipeline.
--
--   aseprite -b --script-param in=<sheet.png> --script-param ase=<out.aseprite>
--            --script-param png=<out.png> --script cpc_palette.lua
--
-- Clamps a sheet to the 16-colour CPC game palette (index 16 = transparent
-- key), marks the document as 2:1 pixel ratio (Mode 0) for correct preview
-- and hand clean-up, saves the editable .aseprite source and exports the
-- PNG that tools/png2cpc.py converts.
-- Keep the colours in sync with tools/cpcpal.py GAME_PENS.

local PAL = {
  {0,0,0}, {255,255,255}, {128,255,255}, {0,128,255},
  {0,0,128}, {128,128,128}, {0,128,0}, {0,128,128},
  {128,0,0}, {255,128,0}, {255,128,128}, {128,128,0},
  {255,0,0}, {255,255,0}, {0,0,255}, {255,255,128},
}
local KEY = 16

local p = app.params
local spr = app.open(p["in"])
if not spr then error("cannot open " .. tostring(p["in"])) end

-- every transparent pixel -> opaque magenta key, so the indexed conversion
-- maps it by colour to KEY (it would otherwise land on index 0 = black)
if spr.colorMode == ColorMode.RGB then
  for _, cel in ipairs(spr.cels) do
    local img = cel.image
    for it in img:pixels() do
      local c = it()
      if app.pixelColor.rgbaA(c) < 128 or
         (app.pixelColor.rgbaR(c) == 255 and app.pixelColor.rgbaG(c) == 0 and
          app.pixelColor.rgbaB(c) == 255) then
        it(app.pixelColor.rgba(255, 0, 255, 255))
      end
    end
  end
end

local pal = Palette(17)
for i, c in ipairs(PAL) do pal:setColor(i - 1, Color{r=c[1], g=c[2], b=c[3], a=255}) end
pal:setColor(KEY, Color{r=255, g=0, b=255, a=255})
spr:setPalette(pal)
app.command.ChangePixelFormat{ format="indexed", dithering="none" }
spr.transparentColor = KEY
spr.pixelRatio = Size(2, 1)

spr:saveAs(p["ase"])
spr:saveCopyAs(p["png"])
print("cpc_palette: " .. p["in"] .. " -> " .. p["ase"] .. " (" .. spr.width .. "x" .. spr.height .. ")")
