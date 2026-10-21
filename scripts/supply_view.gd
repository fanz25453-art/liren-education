extends CanvasLayer
signal state_changed
const CATALOG = preload("res://scripts/supply_catalog.gd")
var controller: Node
var overlay: Control
var panel: PanelContainer
var mode: String = ""
var product_grid: GridContainer
var buttons: Array[Button] = []
var selected: int = 0
var note: String = ""
func _ready() -> void:
 layer=55
 controller=get_parent()
 overlay=Control.new()
 add_child(overlay)
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var dim:=ColorRect.new()
 dim.color=Color(0.02,0.035,0.04,0.8)
 overlay.add_child(dim)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 panel=PanelContainer.new()
 overlay.add_child(panel)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("#172d32")
 style.border_color=Color("#a8bba6")
 style.set_border_width_all(2)
 style.set_corner_radius_all(14)
 style.content_margin_left=24
 style.content_margin_right=24
 style.content_margin_top=20
 style.content_margin_bottom=20
 panel.add_theme_stylebox_override("panel",style)
 overlay.hide()
 get_viewport().size_changed.connect(_layout)
func is_open() -> bool:return overlay!=null and overlay.visible
func open(next_mode: String) -> void:
 mode=next_mode
 selected=0
 note=""
 overlay.show()
 refresh()
 state_changed.emit()
func close() -> void:
 overlay.hide()
 state_changed.emit()
func _process(_delta: float) -> void:
 if is_open():_layout()

func _layout() -> void:
 var view: Vector2=get_viewport().get_visible_rect().size
 if is_instance_valid(product_grid):product_grid.columns=1 if view.x<1100 else 2
 panel.size=Vector2(minf(1080,view.x-60),minf(1020,view.y-60))
 panel.position=(view-panel.size)*0.5
func text(parent: Node, value: String, size: int=24) -> void:
 var label:=Label.new()
 label.text=value
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",size)
 parent.add_child(label)
func refresh() -> void:
 for child in panel.get_children():
  panel.remove_child(child)
  child.queue_free()
 buttons.clear()
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",14)
 panel.add_child(column)
 var f=controller.game_menu.features
 text(column,"小卖部" if mode=="shop" else "桌板 · 吃泡面",34)
 text(column,"今日零钱：%d / 30 元 · 每天补到30元，不累计"%f.cash if mode=="shop" else "选择一份泡面 · 体力 +15",23)
 if not note.is_empty():text(column,note,23)
 var scroll:=ScrollContainer.new()
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 column.add_child(scroll)
 var grid:=GridContainer.new()
 product_grid=grid
 grid.columns=2
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 grid.add_theme_constant_override("h_separation",16)
 grid.add_theme_constant_override("v_separation",14)
 scroll.add_child(grid)
 var ids: Array=CATALOG.SHOP_IDS.duplicate() if mode=="shop" else []
 if mode!="shop":
  for id in CATALOG.ITEMS:
   if CATALOG.ITEMS[id].get("kind","")=="noodles" and int(f.inventory.get(id,0))>0:ids.append(id)
 for id in ids:
  var spec: Dictionary=CATALOG.ITEMS[id]
  var card:=PanelContainer.new()
  card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  card.custom_minimum_size=Vector2(450,180)
  grid.add_child(card)
  var row:=HBoxContainer.new()
  row.add_theme_constant_override("separation",16)
  card.add_child(row)
  var picture:=TextureRect.new()
  picture.custom_minimum_size=Vector2(135,150)
  picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  picture.texture=CATALOG.texture(id)
  row.add_child(picture)
  if picture.texture==null:
   var tag:=Label.new()
   tag.text=spec.name
   tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
   tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
   tag.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
   picture.add_child(tag)
  var details:=VBoxContainer.new()
  details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  row.add_child(details)
  text(details,str(spec.name),27)
  text(details,CATALOG.description(spec),19)
  text(details,"背包 × %d"%int(f.inventory.get(id,0)),20)
  var button:=Button.new()
  button.text="购买一份 · %d 元"%spec.price if mode=="shop" else "吃这一份"
  button.custom_minimum_size.y=46
  button.add_theme_font_size_override("font_size",22)
  button.focus_mode=Control.FOCUS_NONE
  button.disabled=mode=="shop" and f.cash<int(spec.price)
  button.pressed.connect(_choose.bind(id))
  details.add_child(button)
  if not button.disabled:buttons.append(button)
 if ids.is_empty():text(column,"背包里没有泡面，可以去小卖部购买。",24)
 if mode!="shop":
  var store:=Button.new()
  store.text="收起桌板，斜靠回柜子旁"
  store.custom_minimum_size.y=52
  store.pressed.connect(_store)
  column.add_child(store)
 var close_button:=Button.new()
 close_button.text="关闭 · Esc"
 close_button.custom_minimum_size.y=50
 close_button.pressed.connect(close)
 column.add_child(close_button)
 text(column,"鼠标选择 · 方向键选择 · Enter确认"+(" · E吃选中的泡面" if mode!="shop" else ""),19)
 selected=clampi(selected,0,maxi(0,buttons.size()-1))
 _highlight()
 _layout()
func _choose(id: String) -> void:
 var f=controller.game_menu.features
 if mode=="shop":f.buy_item(id)
 else:f.use_item(id)
 note=f.feedback
 refresh()
func _store() -> void:
 controller.dorm_table_deployed=false
 controller.map.dorm_table_has_bowl=false
 controller._sync_dorm_table()
 close()
func _highlight() -> void:
 for i in range(buttons.size()):buttons[i].modulate=Color("#ffe49c") if i==selected else Color.WHITE
func _input(event: InputEvent) -> void:
 if not is_open() or not event is InputEventKey:return
 if event.pressed and not event.echo:
  var key: int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
  if key==KEY_ESCAPE:close()
  elif key in [KEY_UP,KEY_LEFT,KEY_DOWN,KEY_RIGHT] and not buttons.is_empty():
   selected=posmod(selected+(-1 if key in [KEY_UP,KEY_LEFT] else 1),buttons.size())
   _highlight()
  elif (key in [KEY_ENTER,KEY_KP_ENTER] or (key==KEY_E and mode!="shop")) and not buttons.is_empty():buttons[selected].pressed.emit()
 get_viewport().set_input_as_handled()
