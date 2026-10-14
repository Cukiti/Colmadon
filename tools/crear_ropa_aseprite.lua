-- Dibuja ropa pixel art en Aseprite; conserva los editables ya existentes.
local root=assert(app.params.root,'Falta root')
local function C(hex) return Color{r=tonumber(hex:sub(1,2),16),g=tonumber(hex:sub(3,4),16),b=tonumber(hex:sub(5,6),16),a=255} end
local function dot(image,x,y,hex) if x>=0 and x<16 and y>=0 and y<16 then image:drawPixel(x,y,C(hex)) end end
local function rect(image,x,y,w,h,hex) for yy=y,y+h-1 do for xx=x,x+w-1 do dot(image,xx,yy,hex) end end end
for _,id in ipairs({'fello','yeya','chichi'}) do
 local dir=root..'/arte/personajes/'..id
 local existing=io.open(dir..'/ropa.aseprite','rb')
 if existing then existing:close();print('Conservada ropa existente: '..id) else
 local sprite=Sprite(16,16,ColorMode.RGB)
 local base=sprite.layers[1];base.name='Tela'
 local folds=sprite:newLayer();folds.name='Costuras y pliegues'
 local details=sprite:newLayer();details.name='Bordado y detalles'
 local fabric=Image(16,16,ColorMode.RGB)
 local seams=Image(16,16,ColorMode.RGB)
 local design=Image(16,16,ColorMode.RGB)
 if id=='fello' then
  fabric:clear(C('efede0'))
  rect(seams,0,2,1,14,'dedaca');rect(seams,15,2,1,14,'dedaca')
  for _,x in ipairs({3,5,10,12}) do rect(seams,x,3,1,13,'d4cfbd');rect(seams,x+1,3,1,13,'f8f6ec') end
  rect(seams,7,2,1,14,'e0dacc');rect(seams,8,2,1,14,'faf7ec')
  for _,x in ipairs({2,10}) do
   rect(design,x,9,4,1,'bcb4a1');rect(design,x,10,1,3,'ded6c3');rect(design,x+3,10,1,3,'ded6c3');rect(design,x,13,4,1,'c9c1ae')
  end
  for _,y in ipairs({4,7,10,14}) do dot(design,8,y,'a69b87');dot(design,9,y,'fcfaef') end
  rect(design,3,0,3,1,'fbf9ee');rect(design,10,0,3,1,'fbf9ee')
  dot(design,5,1,'d2c9b6');dot(design,6,2,'d2c9b6');dot(design,10,1,'d2c9b6');dot(design,9,2,'d2c9b6')
 elseif id=='yeya' then
  fabric:clear(C('d94059'))
  rect(seams,0,2,1,14,'bc344b');rect(seams,15,2,1,14,'bc344b');rect(seams,1,5,1,11,'ce3851');rect(seams,14,5,1,11,'ce3851')
  rect(seams,3,0,3,1,'f06c79');rect(seams,10,0,3,1,'f06c79');dot(seams,6,1,'f06c79');dot(seams,9,1,'f06c79')
  for i,p in ipairs({{3,4},{11,5},{6,10},{12,13}}) do
   local x,y=p[1],p[2];local petal=i%2==0 and 'ffe8b2' or 'f8f0dc'
   dot(design,x-1,y,petal);dot(design,x+1,y,petal);dot(design,x,y-1,petal);dot(design,x,y+1,petal);dot(design,x,y,'f9bf48')
   dot(design,x+2,y+2,'69b98e');dot(design,x+1,y+2,'3e8c68')
  end
  rect(seams,2,15,12,1,'c73750')
 else
  fabric:clear(C('338c4d'))
  rect(seams,0,2,1,14,'26713c');rect(seams,15,2,1,14,'26713c');rect(seams,1,5,1,10,'2c7d43');rect(seams,14,5,1,10,'2c7d43')
  rect(design,0,0,16,1,'f3efdd');rect(design,0,1,16,1,'d9ddc8');dot(design,6,2,'f3efdd');dot(design,9,2,'f3efdd')
  rect(design,4,4,8,4,'215c34');rect(design,5,5,6,2,'f6f2df')
  for y=7,12 do local x=10-math.floor((y-7)/2);rect(design,x-1,y,4,1,'215c34');rect(design,x,y,2,1,'f6f2df') end
  rect(seams,2,15,12,1,'b5c6a0')
 end
 sprite.cels[1].image=fabric
 sprite:newCel(folds,1,seams);sprite:newCel(details,1,design)
 sprite:saveAs(dir..'/ropa.aseprite')
 sprite:saveCopyAs(dir..'/ropa.png')
 print('Ropa creada en Aseprite: '..id..' (16x16, tres capas)')
 sprite:close()
 end
end
