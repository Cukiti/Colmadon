-- Migración a 64x64: conserva la fuente 16x16 y añade dibujo fino por expresión.
local root=assert(app.params.root,'Falta root')
local ids={'fello','yeya','chichi','nena','tito','rafa','colmadero'}
local function rgb(r,g,b) return Color{r=r,g=g,b=b,a=255} end
local function tint(c,k) return rgb(math.min(255,math.floor(c.red*k+.5)),math.min(255,math.floor(c.green*k+.5)),math.min(255,math.floor(c.blue*k+.5))) end
local function px(im,x,y,c) if x>=0 and x<64 and y>=0 and y<64 then im:drawPixel(x,y,c) end end
local function rect(im,x,y,w,h,c) for yy=y,y+h-1 do for xx=x,x+w-1 do px(im,xx,yy,c) end end end
local function migrate(id,kind)
 local dir=root..'/arte/personajes/'..id
 local old=app.open(dir..'/'..kind..'.aseprite')
 if not old then return end
 if old.width==64 then print('Conservado 64x64: '..id..'/'..kind);old:close();return end
 assert(old.width==16 and old.height==16,'Fuente inesperada')
 old:saveCopyAs(dir..'/'..kind..'_16.aseprite')
 if kind=='ropa' then old:saveCopyAs(dir..'/ropa_16.png') end
 local sprite=Sprite(64,64,ColorMode.RGB)
 local layers={sprite.layers[1]}
 layers[1].name=old.layers[1].name
 for i=2,#old.layers do layers[i]=sprite:newLayer();layers[i].name=old.layers[i].name end
 local detailLayer=sprite:newLayer();detailLayer.name='Detalle 64 - pixel art'
 local skin=Color(old.layers[1]:cel(1).image:getPixel(0,0))
 for f=1,#old.frames do
  if f>1 then sprite:newEmptyFrame() end
  sprite.frames[f].duration=old.frames[f].duration
  for i,layer in ipairs(old.layers) do
   local full=Image(64,64,ColorMode.RGB)
   local cel=layer:cel(f)
   if cel then
    local image=Image(cel.image);image:resize(image.width*4,image.height*4)
    full:drawImage(image,Point(cel.position.x*4,cel.position.y*4))
   end
   if i==1 and f==1 then sprite.cels[1].image=full else sprite:newCel(layers[i],f,full) end
  end
  local detail=Image(64,64,ColorMode.RGB)
  if kind=='caras' then
   local dark=rgb(24,16,12)
   local warm=tint(skin,1.12);local shade=tint(skin,.78)
   -- Nasal ridge and stepped edges on the original block nose.
   rect(detail,29,36,1,4,warm);rect(detail,28,40,2,1,shade);rect(detail,34,40,2,1,shade)
   px(detail,28,36,skin);px(detail,35,36,skin);px(detail,28,43,skin);px(detail,35,43,skin)
   -- Small wrinkles under eyes, retaining the original eye positions.
   for _,cx in ipairs({16,44}) do
    rect(detail,cx-4,35,3,1,shade);rect(detail,cx+1,35,3,1,shade)
   end
   local blink=f==2 or f==10
   local wink=f==3
   local laugh=f==8
   if not laugh then
    for _,cx in ipairs({16,44}) do
     if blink or (wink and cx==16) then
      px(detail,cx-4,28,skin);px(detail,cx+7,28,skin)
      rect(detail,cx-3,32,9,1,warm)
     elseif f~=7 then
      -- Iris tone and a one-pixel catchlight instead of a solid black square.
      rect(detail,cx+1,30,2,3,rgb(65,43,29))
      px(detail,cx+1,29,rgb(247,242,219));px(detail,cx,35,dark)
     else
      px(detail,cx+1,29,rgb(247,242,219))
     end
    end
   end
   if f~=6 and f~=7 then
    for _,cx in ipairs({16,44}) do
     local brow=Color(old.layers[2]:cel(1).image:getPixel(4,5))
     -- A finer arch with defined hairs, without changing expression identity.
     px(detail,cx-4,20,skin);px(detail,cx+7,20,skin)
     rect(detail,cx-1,19,5,1,brow)
    end
   end
   if id=='fello' or id=='tito' or id=='colmadero' then
    local hair=rgb(110,81,57)
    if id=='fello' or id=='colmadero' then hair=rgb(231,230,216) end
    for x=18,45,3 do rect(detail,x,44+(x%2),1,2,hair) end
    px(detail,16,44,skin);px(detail,47,44,skin)
   elseif id=='chichi' or id=='rafa' then
    for x=13,51,4 do rect(detail,x,57,1,3,rgb(64,43,30)) end
   end
   if id=='yeya' or id=='nena' then
    if f~=6 and f~=7 then rect(detail,28,49,3,1,rgb(241,111,119)) end
    if not blink and not laugh then rect(detail,10,26,2,1,dark);rect(detail,52,26,2,1,dark) end
   end
   if f==9 or f==10 then
    -- Smaller edge steps for the blush, preserve its red center.
    for _,cx in ipairs({4,48}) do px(detail,cx,36,skin);px(detail,cx+11,36,skin);px(detail,cx,43,skin);px(detail,cx+11,43,skin) end
   end
  else
   if id=='fello' then
    for _,x in ipairs({12,20,40,48}) do for y=13,59,4 do px(detail,x+1,y,rgb(183,174,151)) end end
    for _,y in ipairs({16,28,40,56}) do
     rect(detail,33,y+1,2,2,rgb(242,237,220));px(detail,33,y+1,rgb(116,105,85));px(detail,34,y+2,rgb(116,105,85))
    end
    for _,x in ipairs({8,40}) do for xx=x+1,x+14,3 do px(detail,xx,37,rgb(239,234,216));px(detail,xx,53,rgb(163,154,133)) end end
   elseif id=='yeya' then
    for _,p in ipairs({{3,4},{11,5},{6,10},{12,13}}) do
     local x,y=p[1]*4,p[2]*4
     rect(detail,x+1,y+1,2,2,rgb(217,143,42));px(detail,x,y,rgb(255,226,127))
     px(detail,x-4,y,rgb(217,189,151));px(detail,x+7,y+3,rgb(217,189,151))
     rect(detail,x+6,y+9,1,2,rgb(35,106,67))
    end
    for x=10,53,4 do px(detail,x,60,rgb(239,101,119)) end
   else
    for y=10,57,5 do px(detail,5,y,rgb(83,166,98));px(detail,58,y,rgb(34,105,53)) end
    rect(detail,21,21,21,1,rgb(255,252,231))
    for x=10,53,4 do px(detail,x,60,rgb(240,240,215)) end
    rect(detail,2,3,60,1,rgb(252,249,228))
   end
  end
  sprite:newCel(detailLayer,f,detail)
 end
 for _,tag in ipairs(old.tags) do local t=sprite:newTag(tag.fromFrame.frameNumber,tag.toFrame.frameNumber);t.name=tag.name end
 sprite:saveAs(dir..'/'..kind..'.aseprite')
 if kind=='caras' then
  local original=Image(160,16,ColorMode.RGB)
  for f=1,10 do original:drawSprite(old,f,Point((f-1)*16,0)) end
  original:saveAs(dir..'/caras_16.png')
 else sprite:saveCopyAs(dir..'/ropa.png') end
 sprite:close();old:close()
 print('Redibujado con detalle 64x64: '..id..'/'..kind)
end
for _,id in ipairs(ids) do migrate(id,'caras') end
for _,id in ipairs({'fello','yeya','chichi'}) do migrate(id,'ropa') end
