extends Node
## 每天每个时段只抽取一次；手动点歌优先，直到歌曲结束或时段变化。
signal changed
const TRACKS = ["res://assets/music/last_page.mp3", "res://assets/music/love_wrong.mp3", "res://assets/music/no_hesitation.mp3", "res://assets/music/missed_lover.mp3", "res://assets/music/a_little.mp3"]
const TRACK_NAMES = ["江语晨 · 最后一页", "王力宏 · 爱错", "BEYOND · 不再犹豫", "告五人 · 爱人错过", "Muyoi、Pezzi · 一点"]
const PERIOD_TRACKS = {0:[2,3], 1:[4], 3:[0,1]}
var controller: Node
var audio: AudioStreamPlayer
var rng:=RandomNumberGenerator.new()
var slots: Dictionary = {}
var active_slot: String = ""
var manual: Dictionary = {}
var streams: Dictionary = {}
func _ready() -> void:
 controller=get_parent()
 rng.randomize()
 audio=AudioStreamPlayer.new()
 audio.name="CampusMusicPlayer"
 audio.volume_db=-12.0
 add_child(audio)
 audio.finished.connect(_on_finished)
 controller.day_cycle.changed.connect(sync_time)
static func track_for_roll(roll: int, period: int=3) -> int:
 var choices: Array=PERIOD_TRACKS.get(period,[])
 var bucket: int=clampi(roll,0,99)/10
 return int(choices[bucket]) if bucket<choices.size() else -1
func _current_state() -> Dictionary:
 return manual if manual.get("slot","")==active_slot else slots.get(active_slot,{})
func _remember_position() -> void:
 if audio.playing:
  var state: Dictionary=_current_state()
  if not state.is_empty():state.position=audio.get_playback_position()
func sync_time() -> void:
 var key: String="%d:%d"%[controller.day_cycle.day,controller.day_cycle.period]
 if key==active_slot:return
 _remember_position()
 audio.stop()
 active_slot=key
 if manual.get("slot","")!=key:manual.clear()
 if not slots.has(key):slots[key]={"track":track_for_roll(rng.randi_range(0,99),controller.day_cycle.period),"finished":false,"position":0.0}
 _play_state()
 changed.emit()
func _play_state() -> void:
 var state: Dictionary=_current_state()
 var track: int=int(state.get("track",-1))
 if track<0 or bool(state.get("finished",false)):return
 if not streams.has(track):
  var stream: AudioStreamMP3=load(TRACKS[track]) as AudioStreamMP3
  if stream==null:return
  stream.loop=false
  streams[track]=stream
 audio.stream=streams[track]
 audio.play(clampf(float(state.position),0.0,maxf(0.0,audio.stream.get_length()-0.1)))
func play_song(track: int) -> bool:
 if track<0 or track>=TRACKS.size():return false
 sync_time()
 _remember_position()
 audio.stop()
 manual={"slot":active_slot,"track":track,"finished":false,"position":0.0}
 _play_state()
 changed.emit()
 return audio.playing
func stop_song() -> void:
 _remember_position()
 audio.stop()
 manual={"slot":active_slot,"track":-1,"finished":true,"position":0.0}
 changed.emit()
func status_text() -> String:
 var state: Dictionary=_current_state()
 var track: int=int(state.get("track",-1))
 return "正在播放："+str(TRACK_NAMES[track]) if audio.playing and track>=0 else "当前未播放歌曲"
func _on_finished() -> void:
 var state: Dictionary=_current_state()
 if not state.is_empty():
  state.finished=true
  state.position=0.0
 changed.emit()
func snapshot() -> Dictionary:
 _remember_position()
 return {"slots":slots.duplicate(true),"manual":manual.duplicate(true)}
func restore(data: Dictionary) -> void:
 audio.stop()
 active_slot=""
 slots=data.get("slots",{}).duplicate(true)
 manual=data.get("manual",{}).duplicate(true)
 # 兼容只有夜间随机歌曲的旧存档。
 for day in data.get("nights",{}):slots[str(day)+":3"]=data.nights[day].duplicate(true)
static func _valid_state(state: Variant) -> bool:
 if not state is Dictionary:return false
 var track: Variant=state.get("track")
 var position: Variant=state.get("position")
 if not (track is int or track is float) or not is_finite(float(track)) or float(track)!=int(track) or int(track)<-1 or int(track)>=TRACKS.size():return false
 if not state.get("finished") is bool:return false
 if not (position is int or position is float) or not is_finite(float(position)) or float(position)<0:return false
 return true
static func _valid_slot(key: String) -> bool:
 var parts: PackedStringArray=key.split(":")
 return parts.size()==2 and parts[0].is_valid_int() and int(parts[0])>=1 and int(parts[0])<=99999 and parts[1] in ["0","1","2","3"]
static func valid(data: Variant) -> bool:
 if not data is Dictionary:return false
 for section in ["nights","slots","manual"]:
  if not data.get(section,{}) is Dictionary:return false
 for key in data.get("nights",{}):
  if not str(key).is_valid_int() or int(key)<1 or int(key)>99999 or not _valid_state(data.nights[key]):return false
 for key in data.get("slots",{}):
  if not _valid_slot(str(key)) or not _valid_state(data.slots[key]):return false
 var override: Dictionary=data.get("manual",{})
 if not override.is_empty() and (not _valid_slot(str(override.get("slot",""))) or not _valid_state(override)):return false
 return true
