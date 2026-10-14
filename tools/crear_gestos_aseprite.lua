-- Gestos estáticos: mejora los botones, no modifica las animaciones 3D.
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
local function C(h) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255} end
for _,id in ipairs({'dance','clap','point','wave','stretch','choca','brindis','sit','shove'}) do
 local path=dir..'/'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(16,16,ColorMode.RGB)
  local base=s.layers[1];base.name='Contorno'
  local figure=s:newLayer();figure.name='Pose y colores'
  local a=Image(16,16,ColorMode.RGB);local b=Image(16,16,ColorMode.RGB)
  local pixels={}
  local function dot(x,y,h) if x>=1 and x<=14 and y>=1 and y<=14 then pixels[y*16+x]=h end end
  local function rect(x,y,w,h,col) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(xx,yy,col) end end end
  local function line(x1,y1,x2,y2,col)
   local n=math.max(math.abs(x2-x1),math.abs(y2-y1))
   for k=0,n do local t=n==0 and 0 or k/n;dot(math.floor(x1+(x2-x1)*t+0.5),math.floor(y1+(y2-y1)*t+0.5),col) end
  end
  local skin='f4d19a';local shirt='51b4a0';local pants='d3a044';local light='fff0ce'
  local function head(x,y) rect(x,y,3,3,skin);dot(x,y,light) end
  if id=='clap' or id=='choca' then
   if id=='clap' then
    rect(3,7,3,6,skin);rect(10,7,3,6,skin)
    line(4,6,7,3,skin);line(11,6,8,3,skin);line(5,7,7,5,light);line(10,7,8,5,light)
    rect(3,12,3,2,shirt);rect(10,12,3,2,shirt);dot(7,1,pants);dot(8,1,pants)
   else
    rect(5,3,2,5,skin);rect(9,3,2,5,skin);dot(6,2,light);dot(9,2,light)
    line(5,8,3,13,skin);line(10,8,12,13,skin)
    rect(2,12,3,2,shirt);rect(11,12,3,2,shirt);dot(7,1,pants);dot(8,1,pants)
   end
  elseif id=='brindis' then
   for _,x in ipairs({2,9}) do
    rect(x,5,5,7,'b5d6c8');rect(x+1,7,3,4,'dc9c36');rect(x+1,5,3,1,light)
    line(x+2,12,x+2,13,skin);rect(x+1,13,3,1,shirt)
   end
   dot(7,3,pants);dot(8,2,light);dot(9,3,pants)
  elseif id=='shove' then
   head(2,3);rect(3,6,2,4,shirt);line(4,6,9,6,skin);line(4,8,9,8,skin)
   line(3,10,2,13,pants);line(4,10,6,13,pants)
   head(11,2);line(11,5,10,9,'dc8a55');line(12,5,14,7,skin)
   line(10,9,11,13,pants);line(10,9,8,12,pants)
  elseif id=='sit' then
   head(5,2);rect(5,5,3,4,shirt);line(7,6,10,7,skin)
   rect(6,9,5,2,pants);rect(10,10,2,4,pants)
   rect(3,6,1,8,'eac382');rect(3,11,10,1,'eac382');rect(12,12,1,2,'eac382')
  else
   local hx=id=='point' and 3 or 7;local hy=id=='stretch' and 4 or 2
   head(hx,hy);rect(hx,hy+3,3,5,shirt)
   if id=='dance' then
    line(7,6,4,3,skin);line(9,6,12,8,skin);line(7,10,4,13,pants);line(9,10,12,12,pants);dot(12,13,pants);dot(13,2,pants);dot(14,1,pants)
   elseif id=='point' then
    line(5,6,13,6,skin);line(3,6,2,9,skin);line(3,10,2,13,pants);line(5,10,6,13,pants);dot(13,5,light)
   elseif id=='wave' then
    line(9,6,12,3,skin);rect(12,1,2,3,skin);line(7,6,4,9,skin);line(7,10,6,13,pants);line(9,10,10,13,pants);dot(10,1,pants)
   else
    line(7,7,4,2,skin);line(9,7,12,2,skin);dot(4,1,light);dot(12,1,light);line(7,12,6,14,pants);line(9,12,10,14,pants)
   end
  end
  for key in pairs(pixels) do local x=key%16;local y=math.floor(key/16)
   for dy=-1,1 do for dx=-1,1 do if x+dx>=0 and x+dx<16 and y+dy>=0 and y+dy<16 then a:drawPixel(x+dx,y+dy,C('382316')) end end end
  end
  for key,col in pairs(pixels) do b:drawPixel(key%16,math.floor(key/16),C(col)) end
  s:newCel(base,1,a,Point(0,0));s:newCel(figure,1,b,Point(0,0));s:saveAs(path)
 end
 assert(s.width==16 and s.height==16 and #s.frames==1,'Gesto: un frame 16x16')
 s:saveCopyAs(dir..'/'..id..'.png');s:close();print('Exportado gesto '..id)
end
