-- Iconos 32x32 de tiza, con textura fija y editables preservados.
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
local function C(h,a) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=a or 255} end
for _,id in ipairs({'domino','clasico','amigos','reto','trofeo'}) do
 local path=dir..'/tiza_'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(32,32,ColorMode.RGB)
  local base=s.layers[1];base.name='Trazo de tiza'
  local grain=s:newLayer();grain.name='Polvo y desgaste'
  local a=Image(32,32,ColorMode.RGB);local b=Image(32,32,ColorMode.RGB)
  local pixels={}
  local function dot(x,y) if x>=1 and x<31 and y>=1 and y<31 then pixels[y*32+x]=true end end
  local function line(x1,y1,x2,y2)
   local n=math.max(math.abs(x2-x1),math.abs(y2-y1))
   for k=0,n do local t=n==0 and 0 or k/n;local x=math.floor(x1+(x2-x1)*t+0.5);local y=math.floor(y1+(y2-y1)*t+0.5);dot(x,y);dot(x+1,y) end
  end
  local function box(x,y,w,h) line(x,y,x+w,y);line(x+w,y,x+w,y+h);line(x+w,y+h,x,y+h);line(x,y+h,x,y) end
  local function pip(x,y) dot(x,y);dot(x+1,y);dot(x,y+1);dot(x+1,y+1) end
  if id=='domino' then
   box(9,3,13,25);line(10,15,21,15)
   pip(12,7);pip(18,10);pip(12,19);pip(18,19);pip(15,23)
   line(25,5,27,4);line(25,10,28,10)
  elseif id=='clasico' then
   box(16,3,12,18);line(17,12,27,12);pip(19,6);pip(24,8);pip(23,16)
   box(3,11,12,18);line(4,20,14,20);pip(6,14);pip(11,16);pip(8,24)
  elseif id=='amigos' then
   for _,x in ipairs({8,23}) do
    box(x-3,4,6,7);line(x-2,4,x+2,4)
    line(x-3,15,x+3,15);line(x-3,15,x-6,22);line(x+3,15,x+5,21)
    line(x-6,22,x-6,28);line(x-6,28,x+5,28);line(x+5,28,x+5,24)
   end
   line(11,19,15,22);line(15,22,19,19);pip(15,21)
  elseif id=='trofeo' then
   line(8,4,24,4);line(8,4,9,13);line(24,4,23,13)
   line(9,13,12,17);line(23,13,20,17);line(12,17,20,17)
   line(8,6,4,6);line(4,6,4,10);line(4,10,9,13)
   line(24,6,28,6);line(28,6,28,10);line(28,10,23,13)
   line(15,17,15,22);line(17,17,17,22)
   box(10,22,12,4);line(8,28,24,28)
   line(14,8,16,7);line(16,7,16,12)
  else
   box(3,7,25,22);line(4,13,27,13);line(9,3,9,9);line(23,3,23,9)
   local points={{16,16},{18,20},{23,20},{19,23},{20,27},{16,25},{12,27},{13,23},{9,20},{14,20},{16,16}}
   for k=1,#points-1 do line(points[k][1],points[k][2],points[k+1][1],points[k+1][2]) end
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
 assert(s.width==32 and s.height==32 and #s.frames==1,'Tiza: un frame 32x32')
 s:saveCopyAs(dir..'/tiza_'..id..'.png');s:close();print('Exportada tiza '..id)
end
