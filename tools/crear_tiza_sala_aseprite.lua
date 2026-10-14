-- Iconos de tiza de colores para «Sala con amigos» (32x32): modo con aumentos y
-- clásico, meta, privada/pública, con y sin armas, crear, buscar y entrar; y
-- para «Buscar salas»: todos los modos, actualizar, silla libre, esperando,
-- jugando y sala vacía.
-- Capas «Trazo de tiza», «Tiza de color» y «Polvo y desgaste», como los otros
-- iconos de la pizarra. Conserva los editables que ya existan.
-- Uso: Aseprite -b --script-param root=<proyecto> --script tools/crear_tiza_sala_aseprite.lua
local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/interfaz'
local function C(h,a) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=a or 255} end
local TINTA={b='eaf1df',o='f2c94c',r='f28fa6',t='72d6c9',x='e8695a',m='c99a6b'}
local ids={'aumentos','clasico','meta','privada','publica','armas','sin_armas','crear','buscar','entrar','todos','actualizar','silla','esperando','jugando','vacia'}
for _,id in ipairs(ids) do
 local path=dir..'/tiza_sala_'..id..'.aseprite';local f=io.open(path,'rb');local s
 if f then f:close();s=app.open(path) else
  s=Sprite(32,32,ColorMode.RGB)
  local base=s.layers[1];base.name='Trazo de tiza'
  local tinta=s:newLayer();tinta.name='Tiza de color'
  local grain=s:newLayer();grain.name='Polvo y desgaste'
  local a=Image(32,32,ColorMode.RGB);local c=Image(32,32,ColorMode.RGB);local g=Image(32,32,ColorMode.RGB)
  local px={}   -- clave -> letra de color (b = blanca, en su capa)
  local col='b'
  local function dot(x,y) x=math.floor(x+0.5);y=math.floor(y+0.5);if x>=0 and x<32 and y>=0 and y<32 then px[y*32+x]=col end end
  local function line(x1,y1,x2,y2)
   local n=math.max(math.abs(x2-x1),math.abs(y2-y1))
   for k=0,n do local t=n==0 and 0 or k/n;dot(x1+(x2-x1)*t,y1+(y2-y1)*t) end
  end
  local function box(x,y,w,h) line(x,y,x+w,y);line(x+w,y,x+w,y+h);line(x+w,y+h,x,y+h);line(x,y+h,x,y) end
  local function fill(x,y,w,h,paso) for yy=y,y+h do for xx=x,x+w do if (xx+yy)%(paso or 1)==0 then dot(xx,yy) end end end end
  local function ring(cx,cy,r) for k=0,63 do local t=k/64*math.pi*2;dot(cx+math.cos(t)*r,cy+math.sin(t)*r) end end
  local function disk(cx,cy,r,paso) for yy=-r,r do for xx=-r,r do if xx*xx+yy*yy<=r*r and ((xx+yy)%(paso or 1)==0) then dot(cx+xx,cy+yy) end end end end
  local function pip(x,y) dot(x,y);dot(x+1,y);dot(x,y+1);dot(x+1,y+1) end
  local function poly(p) for k=1,#p-1 do line(p[k][1],p[k][2],p[k+1][1],p[k+1][2]) end end
  local function pistola(dx,dy)
   -- corredera con estrías, cañón, mira, gatillo y cacha de madera
   col='b';box(dx+3,dy+6,20,6);line(dx+23,dy+8,dx+26,dy+8);line(dx+23,dy+10,dx+26,dy+10);line(dx+26,dy+8,dx+26,dy+10)
   line(dx+5,dy+5,dx+6,dy+5);line(dx+21,dy+5,dx+21,dy+5)
   for k=0,3 do line(dx+6+k*2,dy+8,dx+6+k*2,dy+10) end
   line(dx+11,dy+12,dx+11,dy+15);line(dx+11,dy+15,dx+15,dy+15);line(dx+15,dy+15,dx+15,dy+12)
   col='o';dot(dx+13,dy+13)
   col='m';poly({{dx+4,dy+12},{dx+2,dy+21},{dx+7,dy+21},{dx+10,dy+12}});fill(dx+4,dy+14,3,5,2)
  end
  if id=='aumentos' then
   -- carta con estrella dorada (inclinada) y un vaso de colmado con espuma
   col='b';poly({{3,6},{14,3},{18,20},{7,23},{3,6}})
   col='o';poly({{10,7},{11,10},{14,10},{12,12},{13,15},{10,13},{8,15},{8,12},{6,10},{9,10},{10,7}});dot(10,11)
   col='b';box(18,14,9,14);line(19,28,26,28)
   col='o';fill(19,18,7,9,2)
   col='b';for _,p in ipairs({{19,13},{21,12},{23,13},{25,12},{26,13}}) do dot(p[1],p[2]) end;dot(20,11);dot(24,11)
   col='t';dot(21,21);dot(23,24);dot(25,20)
  elseif id=='clasico' then
   -- dos fichas cruzadas con sus puntos
   col='b';box(4,5,10,20);line(5,15,13,15);pip(6,8);pip(10,11);pip(6,18);pip(10,18);pip(8,21)
   box(16,9,12,18);line(17,18,27,18);pip(19,12);pip(24,14);pip(21,21)
   col='o';line(15,4,17,2);line(18,5,21,4)
  elseif id=='meta' then
   -- bandera a cuadros en su mástil, ondeando
   col='m';line(6,3,6,29);line(7,3,7,29);col='b';line(3,29,11,29)
   col='b';poly({{8,4},{14,3},{20,5},{26,4},{26,15},{20,16},{14,14},{8,15},{8,4}})
   for yy=0,2 do for xx=0,2 do if (xx+yy)%2==0 then fill(9+xx*6,5+yy*3,4,2) end end end
   col='o';disk(6,3,1)
  elseif id=='privada' then
   -- candado dorado con arco, ojo de la cerradura y brillo
   col='b';line(10,14,10,8);line(22,14,22,8);poly({{10,8},{12,5},{16,4},{20,5},{22,8}})
   line(12,14,12,9);line(20,14,20,9)
   col='o';box(7,14,18,14);fill(8,15,16,12,3)
   col='b';disk(16,19,2);line(16,21,16,25);line(15,24,17,24)
   dot(9,16);dot(9,17)
  elseif id=='publica' then
   -- mundo con meridianos y paralelos, en tiza turquesa
   col='t';ring(16,16,12);line(4,16,28,16);line(6,10,26,10);line(6,22,26,22)
   for k=0,63 do local t=k/64*math.pi*2;dot(16+math.cos(t)*5,16+math.sin(t)*12) end
   line(16,4,16,28)
   col='b';fill(8,8,4,3,2);fill(18,18,5,3,2);fill(20,8,3,2,2)
  elseif id=='armas' then
   pistola(1,4)
   col='x';dot(28,11);dot(29,10);dot(29,12);dot(30,11)
  elseif id=='sin_armas' then
   pistola(1,4)
   col='r';ring(16,15,13);line(7,6,25,24);line(7,7,24,24)
  elseif id=='crear' then
   -- mesa de dominó vista de lado con fichas encima y un «+» dorado
   col='m';line(2,18,22,18);line(2,19,22,19);line(4,19,4,29);line(20,19,20,29);line(6,29,6,29)
   col='b';box(5,13,5,4);box(11,13,5,4);line(8,13,8,17);line(14,13,14,17);dot(6,15);dot(12,15);dot(15,15)
   col='o';fill(23,5,2,10);fill(19,9,10,2)
   col='b';line(2,30,22,30)
  elseif id=='buscar' then
   -- lupa: aro blanco, cristal turquesa con brillo y mango de madera
   col='b';ring(13,13,9);ring(13,13,8)
   col='t';disk(13,13,6,2)
   col='b';line(9,9,11,7);dot(9,11)
   col='m';line(19,19,28,28);line(20,19,29,28);line(19,20,28,29)
  elseif id=='entrar' then
   -- puerta del colmado entreabierta y flecha dorada entrando
   col='b';box(14,3,14,26);line(14,29,28,29)
   col='m';poly({{14,3},{20,6},{20,26},{14,29}});fill(15,8,4,16,3);dot(18,17)
   col='o';line(2,16,12,16);line(2,17,12,17);line(9,13,12,16);line(9,20,12,17);line(8,12,11,15);line(8,21,11,18)
  elseif id=='todos' then
   -- tres fichas en abanico: blanca, dorada y turquesa
   col='b';box(3,8,8,16);line(4,16,10,16);pip(6,11);pip(6,19)
   col='o';box(12,5,8,16);line(13,13,19,13);pip(15,8);pip(14,16);pip(17,18)
   col='t';box(21,8,8,16);line(22,16,28,16);pip(24,11);pip(23,19);pip(26,21)
   col='b';line(4,27,28,27)
  elseif id=='actualizar' then
   -- dos flechas gruesas en círculo (volver a mirar): turquesa arriba, dorada abajo
   col='t';for k=2,28 do for _,r in ipairs({9,10}) do local t=(k/64+0.5)*math.pi*2;dot(16+math.cos(t)*r,16+math.sin(t)*r) end end
   poly({{24,9},{27,15},{21,14}});line(24,10,24,13);line(23,12,26,14)
   col='o';for k=34,60 do for _,r in ipairs({9,10}) do local t=(k/64+0.5)*math.pi*2;dot(16+math.cos(t)*r,16+math.sin(t)*r) end end
   poly({{8,23},{5,17},{11,18}});line(8,22,8,19);line(9,20,6,18)
  elseif id=='silla' then
   -- silla de madera del colmado, libre
   col='m';line(9,3,9,28);line(10,3,10,28);line(22,16,22,28);line(23,16,23,28)
   line(9,16,24,16);line(9,17,24,17);fill(11,5,9,8,3);line(9,4,21,4);line(21,4,21,14)
   col='b';line(6,29,26,29)
   col='t';dot(26,8);dot(27,7);dot(28,8);dot(27,9)
  elseif id=='esperando' then
   -- reloj de arena con la arena cayendo
   col='m';line(8,3,24,3);line(8,29,24,29);line(8,4,24,4);line(8,28,24,28)
   col='b';poly({{10,5},{22,5},{17,15},{22,27},{10,27},{15,15},{10,5}})
   col='o';fill(12,7,8,2);dot(16,13);dot(16,16);dot(16,19);fill(12,23,8,3)
  elseif id=='jugando' then
   -- fichas jugadas en la mesa con una mano dejándola
   col='b';box(2,18,8,5);line(6,18,6,23);dot(4,20);dot(8,20)
   box(10,18,8,5);line(14,18,14,23);dot(12,20);dot(16,21)
   box(18,12,5,11);line(18,17,23,17);dot(20,14);dot(20,20)
   col='m';line(2,26,29,26)
   col='o';poly({{24,4},{29,8},{27,11},{23,10},{24,4}});dot(26,7)
  elseif id=='vacia' then
   -- mesa del colmado sin nadie: cuatro sillas vacías alrededor
   col='m';box(9,11,13,9);fill(10,12,11,7,4)
   col='b';box(13,3,5,4);box(13,24,5,4);box(2,13,4,5);box(25,13,4,5)
   col='r';dot(15,14);dot(16,15);dot(17,14);dot(15,16);dot(17,16)
  end
  for key,k in pairs(px) do
   local x=key%32;local y=math.floor(key/32)
   local worn=(x*7+y*11)%17==0
   if k=='b' then a:drawPixel(x,y,C(worn and 'aabca8' or TINTA.b,worn and 180 or 245))
   else c:drawPixel(x,y,C(TINTA[k],worn and 170 or 240)) end
   if (x*3+y*5)%7==0 then g:drawPixel(x,y,C('fff9df',200)) end
   if x+1<32 and not px[key+1] and (x+y)%5==0 then g:drawPixel(x+1,y,C('c3d2bb',90)) end
  end
  s:newCel(base,1,a,Point(0,0));s:newCel(tinta,1,c,Point(0,0));s:newCel(grain,1,g,Point(0,0));s:saveAs(path)
 end
 assert(s.width==32 and s.height==32 and #s.frames==1,'Tiza: un frame 32x32')
 s:saveCopyAs(dir..'/tiza_sala_'..id..'.png');s:close();print('Exportada tiza_sala_'..id)
end
