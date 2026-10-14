-- Corrección por capa: conserva el dibujo anterior y restaura la boca oculta.
local root=assert(app.params.root,'Falta root')
for _,id in ipairs({'fello','tito','colmadero'}) do
 local s=app.open(root..'/arte/personajes/'..id..'/caras.aseprite')
 assert(s and s.width==64 and s.height==64,'Se espera cara 64x64')
 local layer
 for _,candidate in ipairs(s.layers) do if candidate.name=='Bigote sigue al labio' then layer=candidate end end
 if not layer then layer=s:newLayer();layer.name='Bigote sigue al labio' end
 -- Leer referencia neutral antes de aplicar correcciones.
 local neutral=Image(64,64,ColorMode.RGB);neutral:drawSprite(s,1)
 local skin=Color(neutral:getPixel(0,0))
 local mouth=Color{r=math.floor(skin.red*.5),g=math.floor(skin.green*.5),b=math.floor(skin.blue*.5),a=255}
 local inside=Color{r=64,g=13,b=15,a=255}
 local teeth=Color{r=242,g=242,b=230,a=255}
 for _,frame in ipairs({4,5,8}) do
  local opening=frame==4 and 1 or 2
  local patch=Image(64,64,ColorMode.RGB)
  -- Fila vieja del bigote: devolver labio en entreabierta y dientes en abierta.
  for y=44,47 do for x=16,47 do
   local color=skin
   if x>=24 and x<=39 then
    color=opening==1 and mouth or inside
    if opening==2 and x>=28 and x<=35 then color=teeth end
   end
   patch:drawPixel(x,y,color)
  end end
  local target_y=44-opening*2
  for y=0,3 do for x=0,31 do patch:drawPixel(16+x,target_y+y,neutral:getPixel(16+x,44+y)) end end
  local cel=layer:cel(frame)
  if cel then cel.image=patch;cel.position=Point(0,0) else s:newCel(layer,frame,patch,Point(0,0)) end
 end
 s:saveAs(root..'/arte/personajes/'..id..'/caras.aseprite');s:close()
 print('Bigote animado: '..id)
end
