-- Dibujos de tiza propios de los folletos de «Dominó con bots» (O05): clásico
-- (fichas jugadas que doblan con un doble en la punta) y con aumentos (cartas en
-- abanico con estrella y un vaso). 32x32, capas Trazo de tiza y Polvo y desgaste,
-- como crear_tiza_aseprite.lua. Conserva los editables que ya existan.
-- Uso: Aseprite -b --script-param root=<proyecto> --script tools/crear_folletos_aseprite.lua
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
local function C(h,a) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=a or 255} end
for _,id in ipairs({'folleto_clasico','folleto_aumentos'}) do
 local path=dir..'/tiza_'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(32,32,ColorMode.RGB)
  local base=s.layers[1];base.name='Trazo de tiza'
  local grain=s:newLayer();grain.name='Polvo y desgaste'
  local a=Image(32,32,ColorMode.RGB);local b=Image(32,32,ColorMode.RGB)
  local pixels={}
  local function dot(x,y) if x>=0 and x<32 and y>=0 and y<32 then pixels[y*32+x]=true end end
  local function line(x1,y1,x2,y2)
   local n=math.max(math.abs(x2-x1),math.abs(y2-y1))
   for k=0,n do local t=n==0 and 0 or k/n;dot(math.floor(x1+(x2-x1)*t+0.5),math.floor(y1+(y2-y1)*t+0.5)) end
  end
  local function box(x,y,w,h) line(x,y,x+w,y);line(x+w,y,x+w,y+h);line(x+w,y+h,x,y+h);line(x,y+h,x,y) end
  local function pip(x,y) dot(x,y);dot(x+1,y);dot(x,y+1);dot(x+1,y+1) end
  if id=='folleto_clasico' then
   -- dos fichas tumbadas y un doble de pie en la punta, como en la mesa
   box(1,16,11,6);line(6,16,6,22);pip(3,18);pip(8,18)
   box(12,16,11,6);line(17,16,17,22);pip(14,18);pip(19,17);pip(20,20)
   box(24,8,6,16);line(24,16,30,16);pip(26,10);pip(26,13);pip(26,18);pip(26,21)
   -- una ficha más subiendo por el lado (la línea dobla en el borde)
   box(24,1,6,6);pip(26,3)
   -- trazos de la mesa
   line(2,27,29,27);line(5,29,26,29)
  else
   -- tres cartas en abanico (solo lo que se ve de las de atrás)
   line(2,8,2,24);line(2,24,13,24);line(13,22,13,24);line(2,8,7,8)
   line(7,5,7,21);line(7,5,12,5);line(7,21,18,21);line(18,19,18,21)
   box(12,2,11,16)
   -- estrella en la carta de delante
   local st={{17,5},{18,8},{21,8},{19,10},{20,13},{17,11},{14,13},{15,10},{13,8},{16,8},{17,5}}
   for k=1,#st-1 do line(st[k][1],st[k][2],st[k+1][1],st[k+1][2]) end
   -- vaso con burbujas
   box(22,20,7,10);line(23,23,28,23);dot(24,26);dot(26,25);dot(25,28);dot(27,27)
   line(21,19,30,19)
  end
  for key in pairs(pixels) do
   local x=key%32;local y=math.floor(key/32)
   local worn=(x*7+y*11)%17==0
   a:drawPixel(x,y,C(worn and 'aabca8' or 'eaf1df',worn and 180 or 245))
   if (x*3+y*5)%7==0 then b:drawPixel(x,y,C('fff9df',245)) end
   if x+1<32 and not pixels[key+1] and (x+y)%5==0 then b:drawPixel(x+1,y,C('c3d2bb',100)) end
  end
  s:newCel(base,1,a,Point(0,0));s:newCel(grain,1,b,Point(0,0));s:saveAs(path)
 end
 assert(s.width==32 and s.height==32 and #s.frames==1,'Folleto: un frame 32x32')
 s:saveCopyAs(dir..'/tiza_'..id..'.png');s:close();print('Exportada tiza '..id)
end
