local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
local function C(h) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255} end
for _,id in ipairs({'arrow_left','arrow_right','arrow_up','arrow_down','home','music'}) do
 local path=dir..'/'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(16,16,ColorMode.RGB)
  local base=s.layers[1];base.name='Contorno'
  local detail=s:newLayer();detail.name='Oro y reflejos'
  local a=Image(16,16,ColorMode.RGB);local b=Image(16,16,ColorMode.RGB)
  local mask={}
  local function mark(x,y) if x>=1 and x<=14 and y>=1 and y<=14 then mask[y*16+x]=true end end
  local function rect(x,y,w,h) for yy=y,y+h-1 do for xx=x,x+w-1 do mark(xx,yy) end end end
  if id:sub(1,5)=='arrow' then
   for k=0,6 do for v=-math.floor(k/2),math.floor(k/2) do
    if id=='arrow_left' then mark(4+k,7+v)
    elseif id=='arrow_right' then mark(11-k,7+v)
    elseif id=='arrow_up' then mark(7+v,4+k)
    else mark(7+v,11-k) end
   end end
  elseif id=='home' then
   for k=0,5 do rect(7-k,2+k,2*k+2,1) end
   rect(4,8,8,6)
   for y=10,13 do mask[y*16+7]=nil;mask[y*16+8]=nil end
  else
   rect(5,4,2,8);rect(12,2,2,8);rect(6,2,7,2)
   rect(2,11,4,3);rect(9,9,4,3)
  end
  for key in pairs(mask) do local x=key%16;local y=math.floor(key/16)
   for dy=-1,1 do for dx=-1,1 do if x+dx>=0 and x+dx<16 and y+dy>=0 and y+dy<16 then a:drawPixel(x+dx,y+dy,C('382316')) end end end
  end
  for key in pairs(mask) do local x=key%16;local y=math.floor(key/16)
   b:drawPixel(x,y,C(not mask[key-16] and 'fff0b3' or (y<9 and 'ffcf58' or 'd49a2d')))
  end
  s:newCel(base,1,a,Point(0,0));s:newCel(detail,1,b,Point(0,0));s:saveAs(path)
 end
 assert(s.width==16 and s.height==16 and #s.frames==1,'Navegacion: un frame 16x16')
 s:saveCopyAs(dir..'/'..id..'.png');s:close();print('Exportado '..id)
end
