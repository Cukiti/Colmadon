-- Dibuja iconos pequeños en capas; conserva y reexporta editables existentes.
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
app.fs.makeAllDirectories(dir)
local function C(h) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255} end
for _,id in ipairs({'cafe','ron','morir','agua'}) do
 local path=dir..'/'..id..'.aseprite'
 local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(16,16,ColorMode.RGB)
  local container=s.layers[1];container.name='Recipiente'
  local drink=s:newLayer();drink.name='Bebida'
  local details=s:newLayer();details.name='Detalles y reflejos'
  local a=Image(16,16,ColorMode.RGB);local b=Image(16,16,ColorMode.RGB);local c=Image(16,16,ColorMode.RGB)
  local function r(img,x,y,w,h,hex) for yy=y,y+h-1 do for xx=x,x+w-1 do img:drawPixel(xx,yy,C(hex)) end end end
  if id=='cafe' then
   r(a,2,6,10,7,'382316');r(a,3,7,8,5,'fff0ce');r(a,4,12,6,1,'bda67f')
   r(a,12,7,3,4,'382316');r(a,12,8,2,2,'ead8b0');r(a,12,8,1,2,'382316')
   r(b,3,6,8,2,'693822');r(b,4,6,6,1,'a16a39');r(c,3,9,1,2,'ffffff')
   r(c,1,14,13,1,'382316');r(c,2,13,11,1,'ead8b0')
   r(c,5,3,1,2,'e0d9c1');r(c,6,2,1,1,'e0d9c1');r(c,9,2,1,2,'e0d9c1')
  else
   local top=id=='ron' and 6 or 3
   r(a,3,top,10,15-top,'263e43');r(a,4,top+1,8,13-top,'98b8b1')
   r(a,4,14,8,1,'e1e9d1')
   local liquid=id=='ron' and 'c98028' or (id=='morir' and 'f4ad63' or '60bdcd')
   local light=id=='ron' and 'e8ad46' or (id=='morir' and 'ffe0a0' or 'a1e4e3')
   local level=id=='ron' and 9 or 7
   r(b,4,level,8,14-level,liquid);r(b,4,level,8,1,light);r(b,10,level+1,2,13-level,id=='ron' and '9e591f' or (id=='morir' and 'db8846' or '3796ad'))
   r(c,4,top,8,1,'e1e9d1');r(c,5,top+1,1,12-top,'edf8e8')
   if id=='ron' then r(c,7,8,3,2,'fff0c3');r(c,8,10,3,2,'e5c78c') end
   if id=='morir' then
    r(c,10,1,1,7,'b96138');r(c,11,1,2,1,'b96138')
    r(c,1,5,3,3,'b96924');r(c,1,5,2,2,'ffd36e');r(c,2,6,1,1,'fff0bc')
   end
   if id=='agua' then r(c,7,8,3,2,'e1f4e7');r(c,8,10,3,2,'bfe6e0');r(c,7,13,3,1,'c4ede6') end
  end
  s:newCel(container,1,a,Point(0,0));s:newCel(drink,1,b,Point(0,0));s:newCel(details,1,c,Point(0,0))
  s:saveAs(path)
 end
 assert(s.width==16 and s.height==16 and #s.frames==1,'Bebidas: un frame de 16x16')
 s:saveCopyAs(dir..'/'..id..'.png');s:close();print('Exportada bebida: '..id)
end
