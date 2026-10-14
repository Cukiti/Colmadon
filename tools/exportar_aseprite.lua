-- Exporta los archivos EDITADOS en Aseprite sin volver a generar su dibujo.
-- aseprite -b --script-param root=<proyecto> --script tools/exportar_aseprite.lua
local states={'neutral','parpadeo','guino','hablar','hablar_abierto','enfado','susto','risa','rubor','rubor_parpadeo'}
local root=assert(app.params.root,'Falta --script-param root=...')
for _,id in ipairs({'fello','yeya','chichi','nena','tito','rafa','colmadero'}) do
 local dir=root..'/arte/personajes/'..id
 local sprite=app.open(dir..'/caras.aseprite')
 assert(sprite and (sprite.width==16 or sprite.width==64) and sprite.height==sprite.width and #sprite.frames==10,'Se esperan diez caras cuadradas de 16 o 64: '..id)
 for i,name in ipairs(states) do
  local found=false
  for _,tag in ipairs(sprite.tags) do
   if tag.name==name and tag.fromFrame.frameNumber==i and tag.toFrame.frameNumber==i then found=true end
  end
  assert(found,'Etiqueta o posición incorrecta: '..name)
 end
 local size=sprite.width
 local sheet=Image(size*10,size,ColorMode.RGB)
 for i=1,10 do sheet:drawSprite(sprite,i,Point((i-1)*size,0)) end
 sheet:saveAs(dir..'/caras.png')
 local preview=Image(sheet);preview:drawImage(sheet);preview:resize(1280,128)
 preview:saveAs(dir..'/expresiones_preview.png')
 local metadata=assert(io.open(dir..'/caras.json','w'));metadata:write(json.encode({width=size,height=size,frames=states,source='caras.aseprite'}));metadata:close()
 print('Exportado '..id..' desde su Aseprite editable')
 sprite:close()
end


