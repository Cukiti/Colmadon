-- Inicializa un icono editable; las ejecuciones posteriores solo reexportan.
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
app.fs.makeAllDirectories(dir)
local path=dir..'/moneda.aseprite'
local file=io.open(path,'rb')
local s
if file then file:close();s=app.open(path) else
 s=Sprite(16,16,ColorMode.RGB)
 local base=s.layers[1];base.name='Contorno y relieve'
 local img=Image(16,16,ColorMode.RGB)
 local function color(hex) return Color{r=tonumber(hex:sub(1,2),16),g=tonumber(hex:sub(3,4),16),b=tonumber(hex:sub(5,6),16),a=255} end
 local function pixel(x,y,hex) img:drawPixel(x,y,color(hex)) end
 for y=0,15 do for x=0,15 do
  local d=(x-7.5)^2+(y-7.5)^2
  if d<=56 then pixel(x,y,'382316') end
  if d<=43 then pixel(x,y,y<8 and 'ffe5a0' or 'b97823') end
  if d<=31 then pixel(x,y,'935016') end
  if d<=23 then pixel(x,y,y<8 and 'ffd45d' or 'edac32') end
 end end
 for _,p in ipairs({{4,2},{5,2},{3,3},{2,4},{2,5},{11,12},{12,11}}) do pixel(p[1],p[2],'fff4c3') end
 s:newCel(base,1,img,Point(0,0))
 local symbol=s:newLayer();symbol.name='Sello C de Colmadon'
 local seal=Image(16,16,ColorMode.RGB)
 local points={{7,5},{8,5},{9,5},{6,6},{6,7},{6,8},{6,9},{7,10},{8,10},{9,10}}
 for _,p in ipairs(points) do seal:drawPixel(p[1]+1,p[2]+1,color('ffe5a0')) end
 for _,p in ipairs(points) do seal:drawPixel(p[1],p[2],color('8f4a16')) end
 s:newCel(symbol,1,seal,Point(0,0))
 s:saveAs(path)
end
assert(s.width==16 and s.height==16 and #s.frames==1,'Moneda: se espera 16x16 y un frame')
s:saveCopyAs(dir..'/moneda.png')
print('Moneda exportada desde Aseprite')
s:close()
