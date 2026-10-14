-- Exporta el dibujo de ropa editado en Aseprite sin regenerarlo.
local root=assert(app.params.root,'Falta root')
for _,id in ipairs({'fello','yeya','chichi'}) do
 local dir=root..'/arte/personajes/'..id
 local sprite=app.open(dir..'/ropa.aseprite')
 assert(sprite and (sprite.width==16 or sprite.width==64) and sprite.height==sprite.width and #sprite.frames==1,'Ropa: se espera un frame cuadrado de 16 o 64')
 sprite:saveCopyAs(dir..'/ropa.png')
 print('Ropa exportada: '..id)
 sprite:close()
end

