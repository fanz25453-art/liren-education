extends RefCounted
const SHOP_IDS = ["fenmian", "shrimp", "banmian", "iced_tea", "xiaoheizi", "wanglaoji", "snacks"]
const ITEMS = {
 "fenmian":{"name":"粉面菜蛋","kind":"noodles","price":7,"stamina":15,"energy":0,"image":"fenmian"},
 "shrimp":{"name":"鲜虾鱼板面","kind":"noodles","price":7,"stamina":15,"energy":0,"image":"shrimp"},
 "banmian":{"name":"安徽板面","kind":"noodles","price":7,"stamina":15,"energy":0,"image":"banmian"},
 "iced_tea":{"name":"冰红茶","kind":"drink","price":3,"stamina":0,"energy":5,"image":"iced_tea"},
 "xiaoheizi":{"name":"小黑子","kind":"drink","price":3,"stamina":0,"energy":5},
 "wanglaoji":{"name":"王老吉","kind":"drink","price":3,"stamina":0,"energy":5,"image":"wanglaoji"},
 "snacks":{"name":"零食","kind":"snack","price":4,"stamina":6,"energy":3},
 "cup":{"name":"水杯","usable":false},
 "instant_noodles":{"name":"方便面（原有）","kind":"noodles","stamina":15,"energy":0},
 "energy_drink":{"name":"能量饮料","kind":"drink","stamina":0,"energy":5},
 "sports_drink":{"name":"运动饮料","kind":"drink","stamina":0,"energy":5},
 "mint":{"name":"薄荷糖","kind":"snack","stamina":6,"energy":3},
 "water":{"name":"饮用水","kind":"drink","stamina":0,"energy":5},
 "bread":{"name":"面包","kind":"snack","stamina":6,"energy":3},
 "milk":{"name":"牛奶","kind":"drink","stamina":0,"energy":5}
}
static func description(spec: Dictionary) -> String:
 if not spec.get("usable",true): return "随身用品"
 var result: String = ""
 if int(spec.get("stamina",0))>0: result="体力 +%d"%spec.stamina
 if int(spec.get("energy",0))>0: result+=(" · " if not result.is_empty() else "")+"精力 +%d"%spec.energy
 if spec.get("kind","")=="noodles": result+=" · 仅限展开的桌板"
 return result
static func texture(id: String) -> Texture2D:
 var name: String=str(ITEMS.get(id,{}).get("image",""))
 var path: String="res://assets/products/"+name+".jpg"
 return load(path) if not name.is_empty() and ResourceLoader.exists(path) else null
