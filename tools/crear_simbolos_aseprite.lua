local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
local function C(h) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255} end
for _,id in ipairs({'chat','pass_hand','stand','add'}) do
 local path=dir..'/'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(16,16,ColorMode.RGB)
  local outline=s.layers[1];outline.name='Contorno'
  local face=s:newLayer();face.name='Simbolo y reflejos'
  local a=Image(16,16,ColorMode.RGB);local b=Image(16,16,ColorMode.RGB);local px={}
  local function dot(x,y,c) if x>=1 and x<=14 and y>=1 and y<=14 then px[y*16+x]=c end end
  local function rect(x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(xx,yy,c) end end end
  if id=='chat' then
   rect(2,3,12,7,'fff0ce');rect(3,10,4,2,'fff0ce');dot(3,12,'fff0ce')
   for _,x in ipairs({4,7,10}) do rect(x,6,2,2,'378d83') end
  elseif id=='pass_hand' then
   rect(5,6,7,6,'f4d19a');rect(5,3,1,4,'f4d19a');rect(7,2,1,5,'fff0ce');rect(9,3,1,4,'f4d19a');rect(11,4,1,3,'f4d19a')
   rect(3,8,2,3,'f4d19a');rect(2,7,1,2,'f4d19a');rect(6,12,5,2,'51b4a0');rect(6,10,1,2,'d19b60')
  elseif id=='stand' then
   rect(3,3,3,3,'f4d19a');rect(3,6,3,4,'51b4a0');rect(3,10,1,4,'d3a044');rect(5,10,1,4,'d3a044')
   rect(2,7,1,3,'f4d19a');rect(6,7,1,3,'f4d19a')
   rect(11,6,2,7,'ffcf58');rect(10,5,4,1,'ffcf58');rect(11,4,2,1,'fff0ce');dot(12,3,'fff0ce')
  else
   rect(6,3,3,10,'ffcf58');rect(3,6,10,3,'ffcf58');rect(6,3,3,1,'fff0ce');rect(3,6,3,1,'fff0ce')
  end
  for key in pairs(px) do local x=key%16;local y=math.floor(key/16)
   for dy=-1,1 do for dx=-1,1 do if x+dx>=0 and x+dx<16 and y+dy>=0 and y+dy<16 then a:drawPixel(x+dx,y+dy,C('382316')) end end end
  end
  for key,c in pairs(px) do b:drawPixel(key%16,math.floor(key/16),C(c)) end
  s:newCel(outline,1,a,Point(0,0));s:newCel(face,1,b,Point(0,0));s:saveAs(path)
 end
 assert(s.width==16 and s.height==16 and #s.frames==1,'Simbolo: un frame 16x16')
 s:saveCopyAs(dir..'/'..id..'.png');s:close();print('Exportado '..id)
end
