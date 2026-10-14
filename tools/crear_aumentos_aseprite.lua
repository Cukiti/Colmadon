-- Iconos de categorías de aumentos. Reexporta sin destruir ediciones.
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
local function C(h) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255} end
for _,id in ipairs({'aumento_puntos','aumento_info'}) do
 local path=dir..'/'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(16,16,ColorMode.RGB)
  local base=s.layers[1];base.name='Silueta y volumen'
  local layer=s:newLayer();layer.name='Simbolo y reflejos'
  local a=Image(16,16,ColorMode.RGB);local b=Image(16,16,ColorMode.RGB)
  local function r(img,x,y,w,h,hex) for yy=y,y+h-1 do for xx=x,x+w-1 do img:drawPixel(xx,yy,C(hex)) end end end
  if id=='aumento_puntos' then
   r(a,5,2,8,13,'382316');r(a,3,1,9,13,'382316');r(a,4,2,7,11,'fff0ce')
   r(a,11,3,1,10,'ad926a');r(a,5,14,7,1,'7b5734');r(a,4,2,1,11,'ffffff')
   r(b,5,7,5,1,'ad926a');r(b,5,8,5,1,'e1cb9b')
   for _,p in ipairs({{6,3},{9,3},{6,5},{9,5},{6,10},{9,10},{6,12},{9,12}}) do r(b,p[1],p[2],1,1,'913d2b') end
  else
   local heights={0,1,2,3,3,4,4,4,4,3,3,2,1,0}
   for x=1,14 do
    local h=heights[x]
    r(a,x,8-h,1,h*2+1,'263e43')
    if h>0 then r(a,x,9-h,1,h*2-1,'fff0ce') end
   end
   r(b,6,5,4,7,'237c78');r(b,5,6,6,5,'237c78')
   r(b,6,6,4,5,'53bba6');r(b,7,6,2,5,'263e43');r(b,6,6,2,2,'fff9e2')
   r(b,9,9,1,1,'a2e3c4');r(b,3,3,3,1,'263e43');r(b,6,2,4,1,'263e43')
  end
  s:newCel(base,1,a,Point(0,0));s:newCel(layer,1,b,Point(0,0));s:saveAs(path)
 end
 assert(s.width==16 and s.height==16 and #s.frames==1,'Aumento: un frame 16x16')
 s:saveCopyAs(dir..'/'..id..'.png');s:close();print('Exportado '..id)
end
