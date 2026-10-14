-- Familia de controles: conserva editables existentes al reexportar.
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz';app.fs.makeAllDirectories(dir)
local function C(h) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255} end
for _,id in ipairs({'pause','gear','play_pause','previous','next'}) do
 local path=dir..'/'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(16,16,ColorMode.RGB)
  local base=s.layers[1];base.name='Contorno y sombra'
  local face=s:newLayer();face.name='Oro y reflejos'
  local a=Image(16,16,ColorMode.RGB);local b=Image(16,16,ColorMode.RGB)
  local function r(img,x,y,w,h,hex) for yy=y,y+h-1 do for xx=x,x+w-1 do img:drawPixel(xx,yy,C(hex)) end end end
  local function bar(x,y,w,h)
   r(a,x-1,y-1,w+2,h+2,'382316');r(b,x,y,w,h,'e5aa35');r(b,x,y,w,1,'fff0b3');r(b,x,y,1,h-1,'ffcf58')
  end
  if id=='pause' then bar(4,3,3,10);bar(10,3,3,10)
  elseif id=='gear' then
   for y=1,14 do for x=1,14 do
    local dx=x-7.5;local dy=y-7.5;local d=dx*dx+dy*dy
    local tooth=(x>=6 and x<=9) or (y>=6 and y<=9) or (math.abs(dx)>3 and math.abs(dy)>3 and math.abs(dx)<6 and math.abs(dy)<6)
    if d<40 or (tooth and d<56) then a:drawPixel(x,y,C('382316')) end
    if d<28 or (tooth and d<40) then b:drawPixel(x,y,C(y<8 and 'ffcf58' or 'c68a29')) end
    if d<8 then b:drawPixel(x,y,C('382316')) end
   end end
   r(b,6,2,4,1,'fff0b3');r(b,2,6,1,3,'fff0b3')
  elseif id=='play_pause' then
   for x=2,7 do local h=math.floor((7-x)/2);r(a,x-1,7-h-1,3,2*h+3,'382316');r(b,x,7-h,1,2*h+1,'ffcf58') end
   bar(10,4,1,8);bar(13,4,1,8)
  else
   local left=id=='previous'
   bar(left and 2 or 13,3,1,10)
   for k=0,6 do local x=left and (5+k) or (10-k);local h=math.floor(k/2)
    r(a,x-1,7-h-1,3,2*h+3,'382316');r(b,x,7-h,1,2*h+1,'ffcf58')
   end
  end
  s:newCel(base,1,a,Point(0,0));s:newCel(face,1,b,Point(0,0));s:saveAs(path)
 end
 assert(s.width==16 and s.height==16 and #s.frames==1,'Control: un frame 16x16')
 s:saveCopyAs(dir..'/'..id..'.png');s:close();print('Exportado control '..id)
end
