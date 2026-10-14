local root=app.params.root
local states={'neutral','parpadeo','guino','hablar','hablar_abierto','enfado','susto','risa','rubor','rubor_parpadeo'}
for _,id in ipairs({'fello','yeya','chichi','nena','tito','rafa','colmadero'}) do
 local dir=root..'/arte/personajes/'..id
 local existing=io.open(dir..'/caras.aseprite','rb')
 if existing then existing:close();print('Conservado editable existente: '..id) else
 local f=assert(io.open(dir..'/fuentes/piel.txt','r')); local hex=f:read('*a');f:close()
 local skin=Color{r=tonumber(hex:sub(1,2),16),g=tonumber(hex:sub(3,4),16),b=tonumber(hex:sub(5,6),16),a=255}
 local sprite=Sprite(16,16,ColorMode.RGB)
 local base=sprite.layers[1];base.name='Piel'
 local features=sprite:newLayer();features.name='Rasgos'
 local blush=sprite:newLayer();blush.name='Rubor'
 for i,name in ipairs(states) do
  if i>1 then sprite:newEmptyFrame() end
  sprite.frames[i].duration = name=='parpadeo' and .12 or (name=='guino' and .45 or .1)
  local source=Image{fromFile=dir..'/fuentes/'..name..'.png'}
  local skinImage=Image(16,16,ColorMode.RGB);skinImage:clear(skin)
  local detail=Image(16,16,ColorMode.RGB)
  local blushImage=Image(16,16,ColorMode.RGB)
  local original=nil
  if i>=9 then original=Image{fromFile=dir..'/fuentes/'..states[i-8]..'.png'} end
  for y=0,15 do for x=0,15 do
   local pixel=source:getPixel(x,y)
   local featurePixel=original and original:getPixel(x,y) or pixel
   if featurePixel~=skin.rgbaPixel then detail:drawPixel(x,y,featurePixel) end
   if original and pixel~=featurePixel then blushImage:drawPixel(x,y,pixel) end
  end end
  if i==1 then sprite.cels[1].image=skinImage else sprite:newCel(base,i,skinImage) end
  sprite:newCel(features,i,detail)
  sprite:newCel(blush,i,blushImage)

 end
 for i,name in ipairs(states) do local tag=sprite:newTag(i,i);tag.name=name end
 sprite:saveAs(dir..'/caras.aseprite')
 local sheet=Image(160,16,ColorMode.RGB)
 for i=1,10 do sheet:drawSprite(sprite,i,Point((i-1)*16,0)) end
 sheet:saveAs(dir..'/caras.png')
 local preview=Image(160,16,ColorMode.RGB);preview:drawImage(sheet)
 preview:resize(1280,128)
 preview:saveAs(dir..'/expresiones_preview.png')
 local output=assert(io.open(dir..'/caras.json','w'))
 output:write(json.encode({width=16,height=16,frames=states,layers={'Piel','Rasgos','Rubor'},source='caras.aseprite'}));output:close()
 print(id..': 10 frames, 3 layers, 10 named tags')
 sprite:close()
 end
end


