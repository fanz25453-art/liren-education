extends RefCounted
# 运行时柜体配色，保留原像素素材和透明边缘；不修改原图。
static var beige_texture: ImageTexture
static func texture() -> Texture2D:
 if beige_texture != null:return beige_texture
 var source:Texture2D=load("res://assets/tilesets/rasak/bedroom.png")
 var image:Image=source.get_image()
 image.convert(Image.FORMAT_RGBA8)
 for region in [Rect2i(528,504,48,104),Rect2i(672,384,24,224)]:
  for y in range(region.position.y,region.end.y):
   for x in range(region.position.x,region.end.x):
    var pixel:Color=image.get_pixel(x,y)
    if pixel.a==0:continue
    var brightness:float=clampf(pixel.r/0.56,0.0,1.3)
    var shade:float=pow(brightness,0.65)
    image.set_pixel(x,y,Color(minf(0.86*shade,1.0),minf(0.80*shade,1.0),minf(0.66*shade,1.0),pixel.a))
 beige_texture=ImageTexture.create_from_image(image)
 return beige_texture
