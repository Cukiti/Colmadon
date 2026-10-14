-- Iconos de los botones de la pantalla de inicio (O03): jugar, volver a la sala,
-- personaje, armario y salir. 16x16, un frame, capas Contorno y Color, como el
-- engranaje de Ajustes. Conserva los editables que ya existan; solo dibuja los que faltan.
-- Uso: Aseprite -b --script-param root=<proyecto> --script tools/crear_inicio_aseprite.lua
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
local function C(h) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255} end
local TINTA='382316'
local PALETA={w='fff0d8',g='d8c4a0',k='382316',l='b09a80',b='7a4a26',t='1fa39a',y='ffcf58',o='d49a2d',d='2a1a10',s='e0a070',h='3a2416',r='b04040',p='ff6f9a',q='d0507a'}
local DIBUJOS={
 inicio_jugar={
  '................',
  '....wwwwwwwg....',
  '....wkkwwwwg....',
  '....wkkwwwwg....',
  '....wwwwwwwg....',
  '....wwwwkkwg....',
  '....wwwwkkwg....',
  '....llllllll....',
  '....wkkwkkwg....',
  '....wkkwkkwg....',
  '....wwwwwwwg....',
  '....wkkwkkwg....',
  '....wkkwkkwg....',
  '....wwwwwwwg....',
  '................',
  '................'},
 inicio_sala={
  '................',
  '.bbbbbbb........',
  '.btttttb........',
  '.btttttb........',
  '.btttttb........',
  '.btttttb...y....',
  '.btttttb..yy....',
  '.bttttyb.yyyyyy.',
  '.btttttb..oo....',
  '.btttttb...o....',
  '.btttttb........',
  '.btttttb........',
  '.btttttb........',
  '.bbbbbbb........',
  '................',
  '................'},
 inicio_personaje={
  '................',
  '.....hhhhhh.....',
  '....hhhhhhhh....',
  '....hssssssh....',
  '....ssksskss....',
  '....ssssssss....',
  '....sssrrsss....',
  '.....ssssss.....',
  '......ssss......',
  '...oooooooooo...',
  '..ooooowwooooo..',
  '..ooooowwooooo..',
  '..oooooooooooo..',
  '..oooooooooooo..',
  '................',
  '................'},
 inicio_armario={
  '.......yy.......',
  '......y..y......',
  '.........y......',
  '........y.......',
  '.......yy.......',
  '.....yy..yy.....',
  '...yy......yy...',
  '..yyyyyyyyyyyy..',
  '...wwwwwwwwww...',
  '..wwwwwwwwwwww..',
  '..www.wwww.www..',
  '.....wgwwww.....',
  '.....wgwwww.....',
  '.....wgwwww.....',
  '.....wwwwww.....',
  '................'},
 inicio_salir={
  '................',
  '.bbbbbbb........',
  '.bdddddb........',
  '.bdddddb........',
  '.bdddddb........',
  '.bdddddb....y...',
  '.bdddddb....yy..',
  '.bddyyyyyyyyyyy.',
  '.bdddddb....oo..',
  '.bdddddb....o...',
  '.bdddddb........',
  '.bdddddb........',
  '.bdddddb........',
  '.bbbbbbb........',
  '................',
  '................'},
}
for _,id in ipairs({'inicio_jugar','inicio_sala','inicio_personaje','inicio_armario','inicio_salir'}) do
 local path=dir..'/'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(16,16,ColorMode.RGB)
  local base=s.layers[1];base.name='Contorno'
  local color=s:newLayer();color.name='Color'
  local a=Image(16,16,ColorMode.RGB);local b=Image(16,16,ColorMode.RGB)
  local filas=DIBUJOS[id]
  local lleno={}
  for y=0,15 do for x=0,15 do
   local ch=filas[y+1]:sub(x+1,x+1)
   if ch~='.' then lleno[y*16+x]=ch end
  end end
  -- contorno de un píxel alrededor de todo lo dibujado
  for key in pairs(lleno) do local x=key%16;local y=math.floor(key/16)
   for dy=-1,1 do for dx=-1,1 do
    if x+dx>=0 and x+dx<16 and y+dy>=0 and y+dy<16 then a:drawPixel(x+dx,y+dy,C(TINTA)) end
   end end
  end
  for key,ch in pairs(lleno) do b:drawPixel(key%16,math.floor(key/16),C(PALETA[ch])) end
  s:newCel(base,1,a,Point(0,0));s:newCel(color,1,b,Point(0,0));s:saveAs(path)
 end
 assert(s.width==16 and s.height==16 and #s.frames==1,'Inicio: un frame 16x16')
 s:saveCopyAs(dir..'/'..id..'.png');s:close();print('Exportado '..id)
end
