local root=assert(app.params.root,'Falta root')
local dir=root..'/arte/escenario';app.fs.makeAllDirectories(dir)
local path=dir..'/radio.aseprite';local f=io.open(path,'rb');local s
local function C(h) return Color{r=tonumber(h:sub(1,2),16),g=tonumber(h:sub(3,4),16),b=tonumber(h:sub(5,6),16),a=255} end
if f then f:close();s=app.open(path) else
 s=Sprite(64,32,ColorMode.RGB)
 local wood=s.layers[1];wood.name='Madera y marco'
 local face=s:newLayer();face.name='Rejilla y sintonizador'
 local details=s:newLayer();details.name='Escala y tornillos'
 local a=Image(64,32,ColorMode.RGB);local b=Image(64,32,ColorMode.RGB);local c=Image(64,32,ColorMode.RGB)
 local function r(img,x,y,w,h,hex) for yy=y,y+h-1 do for xx=x,x+w-1 do img:drawPixel(xx,yy,C(hex)) end end end
 a:clear(C('754726'));r(a,0,0,64,2,'b87b40');r(a,0,2,2,28,'b87b40');r(a,0,30,64,2,'432c20');r(a,62,2,2,30,'432c20')
 for _,y in ipairs({5,13,24,28}) do r(a,3,y,58,1,'845331') end
 r(b,5,5,29,23,'3e3021');r(b,7,7,25,19,'bca375')
 for _,y in ipairs({9,15,21}) do r(b,8,y,23,2,'6e5739');r(b,8,y+2,23,1,'dfc18b') end
 r(b,38,5,21,10,'382c20');r(b,40,7,17,6,'eac981');r(b,40,7,17,1,'fff0b3')
 r(c,41,11,15,1,'9b6c38')
 for _,x in ipairs({42,46,50,54}) do r(c,x,9,1,3,'8b5a32') end
 r(c,49,8,2,5,'bf5136')
 r(c,39,18,19,2,'c69855');r(c,42,21,13,1,'4d3323')
 for _,p in ipairs({{3,3},{59,3},{3,27},{59,27}}) do r(c,p[1],p[2],2,2,'ddc793');r(c,p[1],p[2]+1,2,1,'65513c') end
 s:newCel(wood,1,a,Point(0,0));s:newCel(face,1,b,Point(0,0));s:newCel(details,1,c,Point(0,0));s:saveAs(path)
end
assert(s.width==64 and s.height==32 and #s.frames==1,'Radio: un frame 64x32')
s:saveCopyAs(dir..'/radio.png');s:close();print('Radio exportada')
