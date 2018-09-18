-- PLR
--

engine.name = "SoftCut"


local g = grid.connect()
local push = 0

local pattern_time = require 'pattern_time'

local MAX_TRACKS = 6
local MAX_PATTERNS = 8
local MAX_CLIPS = 16
local FADE = 0.01

-- events
local eCUT = 1
local eSTOP = 2
local eSTART = 3
local eLOOP = 4
local eSPEED = 5
local eREV = 6

local quantize = 0

local midi_device = midi.connect()
local midiclocktimer

local gridpage = 0 

local function update_tempo()
  local t = params:get("tempo")
  local d = params:get("quant_div")
  local interval = (60/t) / d
  -- print("q > "..interval)
  quantizer.time = interval
  for i=1,MAX_TRACKS do
    if tracks[i].tempo_map == 1 then
      update_rate(i)
    end
  end
  midiclocktimer.time = 60/24/t
end


function event(e)
  if quantize == 1 then
    event_q(e)
  else
    for i=1,4 do
      patterns[i]:watch(e)
    end
    event_exec(e)
  end
end

local quantize_events = {}

function event_q(e)
  table.insert(quantize_events,e)
end

function event_q_clock()
  if #quantize_events > 0 then
    for k,e in pairs(quantize_events) do
      for i=1,MAX_PATTERNS do
        patterns[i]:watch(e)
      end
      event_exec(e)
    end
    quantize_events = {}
  end
end


function event_exec(e)
  local track = tracks[e.i]
  if e.t==eCUT then
    if track.loop == 1 then
      track.loop = 0
      engine.loop_start(e.i,clips[track.clip].s)
      engine.loop_end(e.i,clips[track.clip].e)
    end
    local cut = (e.pos/16)*clips[track.clip].l + clips[track.clip].s
    engine.pos(e.i,cut)
    engine.reset(e.i)
    if track.play == 0 then
      track.play = 1
      engine.start(e.i)
    end
  elseif e.t==eSTOP then
    track.play = 0
    track.pos_grid = -1
    engine.stop(e.i)
    dirtygrid=true
  elseif e.t==eSTART then
    track.play = 1
    engine.start(e.i)
    dirtygrid=true
  elseif e.t==eLOOP then
    track.loop = 1
    track.loop_start = e.loop_start
    track.loop_end = e.loop_end
    --print("LOOP "..track.loop_start.." "..track.loop_end)
    local clip = clips[track.clip]
    local lstart = clip.s + (track.loop_start-1)/16*clip.l
    local lend = clip.s + (track.loop_end)/16*clip.l
    --print(">>>> "..lstart.." "..lend)
    engine.loop_start(e.i,lstart)
    engine.loop_end(e.i,lend)
    dirtygrid=true
  elseif e.t==eSPEED then
    track.speed = e.speed
    update_rate(e.i)
    dirtygrid=true
  elseif e.t==eREV then
    track.rev = e.rev
    update_rate(e.i)
    dirtygrid=true
  end
end



------ patterns
patterns = {}
for i=1,MAX_PATTERNS do
  patterns[i] = pattern_time.new()
  patterns[i].process = event_exec
end

focus = 1
alt = 0

tracks = {}
for i=1,MAX_TRACKS do
  tracks[i] = {}
  tracks[i].head = (i-1)%4+1
  tracks[i].play = 0
  tracks[i].rec = 0
  tracks[i].rec_level = 1
  tracks[i].pre_level = 0
  tracks[i].loop = 0
  tracks[i].loop_start = 0
  tracks[i].loop_end = 16
  tracks[i].clip = i
  tracks[i].pos = 0
  tracks[i].pos_grid = -1
  tracks[i].speed = 0
  tracks[i].rev = 0
  tracks[i].tempo_map = 0
end


set_clip_length = function(i, len)
  clips[i].l = len
  clips[i].e = clips[i].s + len
  local bpm = 60 / len
  while bpm < 60 do
    bpm = bpm * 2
    -- print("bpm > "..bpm)
  end
  clips[i].bpm = bpm
end

clip_reset = function(i, length)
  set_clip_length(i, length)
  clips[i].name = "-"
end

clips = {}
for i=1,MAX_CLIPS do
  clips[i] = {}
  clips[i].s = 2 + (i-1)*30
  clips[i].name = "-"
  set_clip_length(i,4)
end



calc_quant = function(i)
  local q = (clips[tracks[i].clip].l/16)
  -- print("q > "..q)
  return q
end

calc_quant_off = function(i, q)
  local off = q
  local track = tracks[i]
  local clip = clips[track.clip]
  while off < clip.s do
    off = off + q
  end
  off = off - clip.s
  -- print("off > "..off)
  return off
end

set_clip = function(i, x)
  local track = tracks[i]
  local clip = clips[track.clip]
  track.play = 0
  engine.stop(i)
  track.clip = x
  engine.loop_start(i,clip.s)
  engine.loop_end(i,clip.e)
  local q = calc_quant(i)
  local off = calc_quant_off(i, q)
  engine.quant(i,q)
  engine.quant_offset(i,off)
  track.loop = 0
end

set_rec = function(n)
  local track = tracks[n]
  if track.rec == 1 then
    engine.pre(n,track.pre_level)
    engine.rec(n,track.rec_level)
  else
    engine.pre(n,1)
    engine.rec(n,0)
  end
end

held = {}
heldmax = {}
done = {}
first = {}
second = {}
for i = 1,8 do
  held[i] = 0
  heldmax[i] = 0
  done[i] = 0
  first[i] = 0
  second[i] = 0
end


UP1 = controlspec.new(0, 1, 'lin', 0, 1, "")
BI1 = controlspec.new(-1, 1, 'lin', 0, 0, "")

-------------------- init
init = function()
  params:add_option("midi_sync",{"off","on"})
  params:add_number("tempo",40,240,92)
  params:set_action("tempo", function() update_tempo() end)
  params:add_number("quant_div",1,32,4)
  params:set_action("quant_div",function() update_tempo() end)
  p = {}
  for i=1,MAX_TRACKS do
    engine.rec_on(i,1) -- always on!!
    engine.pre(i,1)
    engine.pre_lag(i,0.05)
    engine.fade_pre(i,FADE)
    engine.amp(i,1)
    engine.rec(i,0)
    engine.rec_lag(i,0.05)
    engine.fade_rec(i,FADE)

    engine.adc_rec(1,i,0.8)
    engine.adc_rec(2,i,0.8)
    engine.play_dac(i,1,1)
    engine.play_dac(i,2,1)
    local track = tracks[i]
    local clip = clips[track.clip]

    engine.loop_start(i,clip.s)
    engine.loop_end(i,clip.e)
    engine.loop_on(i,1)
    engine.quant(i,calc_quant(i))

    engine.fade_rec(i,0.1)
    engine.fade(i,FADE)
    engine.env_time(i,0.1)

    engine.rate_lag(i,0)

    --engine.reset(i)

    p[i] = poll.set("phase_quant_"..i, function(x) phase(i,x) end)
    p[i]:start()

    params:add_control(i.."vol",UP1)
    params:set_action(i.."vol", function(x) engine.amp(i,x) end)
    --params:add_control(i.."pan",BI1)
    --params:set_action(i.."pan",
      --function(x)
        --engine.play_dac(i,1,math.min(1,1+x))
        --engine.play_dac(i,2,math.min(1,1-x))
      --end)
    params:add_control(i.."rec",UP1)
    params:set_action(i.."rec",
      function(x)
        tracks[i].rec_level = x
        set_rec(i)
      end)
    params:add_control(i.."pre",controlspec.UNIPOLAR)
    params:set_action(i.."pre",
      function(x)
        tracks[i].pre_level = x
        set_rec(i)
      end)
    params:add_control(i.."speed_mod", controlspec.BIPOLAR)
    params:set_action(i.."speed_mod", function() update_rate(i) end)
  end

  quantizer = metro.alloc()
  quantizer.time = 0.125
  quantizer.count = -1
  quantizer.callback = event_q_clock
  quantizer:start()
  --pattern_init()


  midiclocktimer = metro.alloc()
  midiclocktimer.count = -1
  midiclocktimer.callback = function()
    if midi_device and params:get("midi_sync")==2 then midi_device.send({248}) end
  end
  update_tempo()
  midiclocktimer:start()

  gridredrawtimer = metro.alloc(function() gridredraw() end, 0.02, -1)
  gridredrawtimer:start()
  dirtygrid = true

  for i = 0, 10 do 
    if push2.devices[i] ~= nil then 
      push = push2.devices[i].dev
    end
  end

  if push == nil then
   return
  end

  -- setup grid lights
  for i = 1,MAX_PATTERNS do -- device keys
      p2_button_state(push,i+102-1,0)
  end
  for i = 1,MAX_TRACKS +2  do -- track keys
      p2_button_state(push,i+20-1,0)
  end
  p2_button_state(push,116, 127) -- quantize
  p2_button_state(push,118, 127) -- delete
  p2_button_state(push,85,10) -- play
  p2_button_state(push,86, 127) -- rec
  p2_button_state(push,62, 0) -- page-
  p2_button_state(push,63, 127) -- page+

end -- init()

-- cleanup
function cleanup()
  for i=1,MAX_PATTERNS do
    patterns[i]:stop()
    patterns[i] = nil
  end
end


-- poll callback
phase = function(n, x)
  local track = tracks[n]
  local clip = clips[track.clip]
  --if n == 1 then print(x) end
  local pp = ((x - clip.s) / clip.l)-- * 16 --TODO 16=div
  --x = math.floor(track.pos*16)
  --if n==1 then print("> "..x.." "..pp) end
  x = math.floor(pp * 16)
  if x ~= track.pos_grid then
    track.pos_grid = x
    dirtygrid=true
  end
end



update_rate = function(i)
  local n = math.pow(2,tracks[i].speed + params:get(i.."speed_mod"))
  local track = tracks[i]
  local clip = clips[track.clip]
  if track.rev == 1 then n = -n end
  if track.tempo_map == 1 then
    local bpmmod = params:get("tempo") / clip.bpm
    --print("bpmmod: "..bpmmod)
    n = n * bpmmod
  end
  engine.rate(i,n)
  redraw()
end

local delkeyheld = false
local playkeyheld = false
local reckeyheld = false


function key(n,z)
  if z>0 and n>=102 and n <102+MAX_PATTERNS then -- device keys
    local pattern = patterns[n-102+1];
    if delkeyheld == 1 then
      pattern:rec_stop()
      pattern:stop()
      pattern:clear()
    elseif pattern.rec == 1 then
      pattern:rec_stop()
      pattern:start()
    elseif pattern.count == 0 then
      pattern:rec_start()
    elseif pattern.play == 1 then
      pattern:stop()
    else 
      pattern:start()
    end
  elseif z>0 and n>=20 and n <20+MAX_TRACKS then -- track keys
    local nfocus = (n - 20) + 1
    if nfocus==focus and not reckeyheld and not playkeyheld  then
      -- toggle play/record
      local track = tracks[focus]
      if track.play == 1 then
        -- print("toogle play "..track.play)
        e = {}
        e.t = eSTOP
        e.i = focus
        event(e)
      elseif track.rec == 1 then
        -- print("toogle rec "..track.rec)
        track.rec = 1 - track.rec
        set_rec(focus)
      end
    else
      focus = nfocus
      local track = tracks[focus] 
      if playkeyheld then
        if track.play == 1 then
          e = {}
          e.t = eSTOP
          e.i = focus
          event(e)
        else 
          e = {}
          e.t = eSTART
          e.i = focus
          event(e)
        end
      end
      if reckeyheld then 
        track.rec = 1 - track.rec
        -- print("REC "..track.rec)
        set_rec(focus)
      end
    end
  elseif n==116 then
      quantize = 1 - quantize
      if quantize == 0 then quantizer:stop()
      else quantizer:start()
      end
  elseif n==85 then --play 
      playkeyheld = z>0     
  elseif n==86 then --rec 
      reckeyheld = z>0     
  elseif n==118 then --delete 
      delkeyheld = z>0     
  elseif n==62 then --page-
    if gridpage > 0 then
      gridpage = gridpage - 1
      p2_button_state(push,62,gridpage > 0 and 127 or 0)
      p2_button_state(push,63,gridpage < 1 and 127 or 0)
    end 
  elseif n==63 then --page+ 
    if gridpage < 1 then
      gridpage = gridpage + 1
      p2_button_state(push,62,gridpage > 0 and 127 or 0)
      p2_button_state(push,63,gridpage < 1 and 127 or 0)
    end 
  elseif n==60 then --mute clip 
  elseif n==61 then --solo clip 
  elseif n==29 then --stop clip
  end 
  redraw()
end

function enc(n,d)
  if n==1 then 
      params:delta(focus.."vol",d)
  elseif n==2 then
      params:delta(focus.."speed_mod",d)
  elseif n== 3 then
      params:delta(focus.."rec",d)
  elseif n == 4 then 
      params:delta(focus.."pre",d)
  elseif n == 5 then 
      params:delta("midi_sync",d)
  elseif n == 6 then
      params:delta("tempo",d)
  elseif n == 7 then
      params:delta("quant_div",d)
  elseif n == 8 then
      mix:delta("output",d)
  end 
  redraw()
end

function dispPattern(pi, title)
    p2_colour(push, 0.5,1.0, 0.5)
    p2_move(push,5 + (pi-1) * 125 ,20)
    p2_text(push,title)
end

function dispTrack(pi, title)
    if pi==focus then 
      p2_colour(push, 1.0,1.0, 1.0)
    else 
      p2_colour(push, 0.5,1.0, 0.7)
    end
    p2_move(push,5 + (pi-1) * 125 ,150)
    p2_text(push,title)
end

function dispParam(pi,title, param) 
    p2_colour(push, 0.5,0.5, 1)
    p2_move(push,5 + (pi-1) * 125 ,45)
    p2_text(push,title)
    -- value 
    p2_colour(push, 1, 1, 1)
    p2_move(push,5 +(pi-1) * 125,65)
    p2_text(push,param)
end



function redraw()
  local pname = {"vol", "speed_mod", "rec", "pre"}
  p2_clear(push)
  p2_font_face(push,5)
  p2_font_size(push,12)
  for i = 1, MAX_PATTERNS do
    dispPattern(i,"Pattern "..i)
  end

  p2_font_size(push,20)
  for i,v in ipairs(pname) do
    dispParam(i, v, params:string(focus..v))
  end
  dispParam(5,"midi_sync", params:string("midi_sync"))
  dispParam(6,"tempo", params:string("tempo"))
  dispParam(7,"quant_div", params:string("quant_div"))
  dispParam(8,"output", mix:string("output"))

  p2_font_size(push,12)
  for i = 1, MAX_TRACKS do
    dispTrack(i,"Track "..i)
  end



  p2_update(push);

  --buttons states
  for i = 1, MAX_PATTERNS do -- device
    local pattern = patterns[i]
    local clr = pattern.rec==1 and 64 or (pattern.count == 0 and 10 or (pattern.play == 1 and 127 or 1 ));
    -- print("p = "..i.." , "..clr.." rec "..pattern.rec)
    p2_button_state(push, i+102-1, clr)
  end
  for i = 1, MAX_TRACKS do -- track
    local track = tracks[i]
    local clrstate = {0, 32, 80,1,33, 127}
    local clridx = (track.play==1 and 2 or (track.rec== 1 and 3 or 1)) + (focus == i and 1 or 0) * 3 ;
    p2_button_state(push, i+20-1, clrstate[clridx])
  end
end


g.event = function(x, y, z)
  local i = math.floor((y-1) / 2) + (gridpage * 4)  + 1

  if i>MAX_TRACKS then return end

  local pos = ((x-1) % 8) + (((y-1) % 2) * 8) + 1;
  if z==1 and held[i] then heldmax[i] = 0 end
  held[i] = held[i] + (z*2-1)
  if held[i] > heldmax[i] then heldmax[i] = held[i] end
  --print(held[i])

  if z == 1 then
    if focus ~= i then
      focus = i
      redraw()
    end
    if alt == 1 and i<=MAX_TRACKS then
      if tracks[i].play == 1 then
        e = {} e.t = eSTOP e.i = i
      else
        e = {} e.t = eSTART e.i = i
      end
      event(e)
    elseif i<=MAX_TRACKS and held[i]==1 then
      first[i] = pos
      local cut = pos-1
      --print("pos > "..cut)
      e = {} e.t = eCUT e.i = i e.pos = cut
      event(e)
    elseif i<=MAX_TRACKS and held[i]==2 then
      second[i] = pos
    end
  elseif z==0 then
    if y<=MAX_TRACKS+2 and held[i] == 1 and heldmax[i]==2 then
      e = {}
      e.t = eLOOP
      e.i = i
      e.loop = 1
      e.loop_start = math.min(first[i],second[i])
      e.loop_end = math.max(first[i],second[i])
      event(e)
    end
  end
end



function gridredraw()
  g.all(0)
  local s = gridpage * 4 + 1 
  local e = s + 3
  if e > MAX_TRACKS then e = MAX_TRACKS end

  -- print( "track "..s.." "..e)
  for i = s  , e do
    local track = tracks[i]
    if track.loop == 1 then
      for x=track.loop_start,track.loop_end do
      local pos = x -1
      g.led( (pos%8) + 1 ,(((i-1) % 4) * 2) + math.floor(pos/8) + 1, i)
      end
    end
    if track.play == 1 then
      local pos = track.pos_grid;
      g.led( (pos%8) + 1 ,(((i-1) % 4) * 2) + math.floor(pos/8) + 1, 15)
    end
  end
  g:refresh();
end