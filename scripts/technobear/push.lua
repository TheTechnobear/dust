-- push 2 native test
-- press device to switch between modes
-- shows graphcis, animation, control

engine.name = 'TestSine'

local metro = require 'metro'

local i = 0
local ctl = nil
local dev = nil
local mididev = nil
local mode = 0
local imidi = false

function init()
  engine.amp(0)

  params:add_number("tempo",20,240,48)
  params:add_number("pw",0,1,1)
  params:add_number("cutoff",1,20000,500)
  params:add_number("res",0,100,48)
  params:add_number("attack",0,100,0)
  params:add_number("decay",0,100,25)
  params:add_number("sustain",0,100,100)
  params:add_number("release",0,100,25)
    -- dev = push2.devices[2].dev
  for i = 0, 10 do 
    if push2.devices[i] ~= nil then 
      dev = push2.devices[i].dev
    end
  end

  if dev == nil then
   return
  end

  p2_clear(dev)
  p2_update(dev)

  clk = metro.alloc()
  clk.time = 1/15
  clk.callback = function(stage)
    redraw()
  end
  clk:start()

end

function cleanup()
  metro.free(cld.id)
  for i=0,7 do
  local data = {0xB0,i+102,0}
    midi.send(mididev,data)
  end
  midi.send(mididev, {0xB0,110,0})
end


local function initmidi()
  for i=0,7 do
    midi.send(mididev,{0xB0,i+102,i+2})
  end
  midi.send(mididev, {0xB0,110,127})
end


p2_text_right = function(dev,str)
  local x, y = p2_extents(dev,str)
  p2_move_rel(dev,-x, 0)
  p2_text(dev,str)
end

p2_text_center = function(dev,str)
  local x, y = p2_extents(dev,str)
  p2_move_rel(dev,-x/2, 0)
  p2_text(dev,str)
end

p2_circle = function(dev,x, y, r)
  p2_arc(dev,x, y, r, 0, math.pi*2)
end

 

-- screen redraw function
function redraw()
  if dev == nil then
   return
  end

  i = i + 1
  if mode == 0 then 
    drawall(dev)
  elseif mode == 1 then
    anim(dev)
  else
    pdraw(dev)
  end
  p2_update(dev);
  
  --something calls screen_update after init and midi.add!
  if not imidi and mididev then
    imidi = true
    initmidi()
  end
    
end

function pdraw(dev) 
  p2_clear(dev)
  p2_font_size(dev,20)
  p2_font_face(dev,9)
  for param_index = 1,params.count do
    p2_colour(dev, 0.5,0.5, 1)
    p2_move(dev,5 + (param_index-1) * 125 ,30)
    p2_text(dev,params:get_name(param_index))
    p2_colour(dev, 1, 1, 1)
    p2_move(dev,5 +(param_index-1) * 125,50)
    p2_text(dev,params:string(param_index))
  end
end


function anim(dev)
  local r = math.random(16)
  local g = math.random(16)
  local b = math.random(16)
  p2_colour(dev, 1/r, 1/g,1/b)
  p2_move(dev, math.random(960), math.random(120))
  p2_line_width(dev,1)
  p2_line(dev, math.random(200) ,math.random(200) )
  p2_stroke(dev)
end


function drawall(dev) 
  p2_clear(dev)
  p2_colour(dev, 1,0,0)
  p2_aa(dev,1)

  p2_line_width(dev,2.0)
  p2_move(dev,0,0)
  p2_line(dev,100,200)
  p2_stroke(dev)

  p2_arc(dev,0,100,100,0,math.pi*0.8)
  p2_stroke(dev)

  p2_rect(dev,230,100,150,200)
  p2_colour(dev, 0,1,0)
  p2_stroke(dev)

  p2_move(dev,550,0)
  p2_curve(dev,150,120,600,0,700,10)
  p2_colour(dev, 0,0,1)
  p2_stroke(dev)
  
  p2_move(dev,700,0)
  p2_line(dev,800,50)
  p2_line(dev,750,100)
  p2_close(dev)
  p2_colour(dev, 1,1,1)
  p2_fill(dev)

  p2_circle(dev,400,120,100)
  p2_stroke(dev)

  p2_move(dev,300,100)
  p2_font_face(dev,4)
  p2_font_size(dev,40)

  local r = i % 16;
  local g = (i / 16 ) %16;
  local b = (i / (16*16)) % 16;
  p2_colour(dev, 1/r, 1/g,1/b)
  p2_text(dev,"new!")

  p2_colour(dev, 1,0,0)


  p2_move(dev,763,50)
  p2_font_face(dev,4)
  p2_font_size(dev,20)
  p2_text_center(dev,"center")
  
  -- draw right aligned text
  p2_move(dev,227,63)
  p2_text_right(dev,"1992")

end



local function note_on(note, vel)
  local data = {0x90,note,vel}
  midi.send(mididev,data)
end

local function note_off(note, vel)
  local data = {0x80,note,vel}
  midi.send(mididev,data)
end

local function cc(ccnum, val)
  print("cc"..ccnum..":"..val)
  if ccnum == 110 and val> 0 then
    mode = (mode + 1) % 3
    p2_clear(dev)
    p2_update(dev)
    print(params.count)
  end 
  if (ccnum >=71 and ccnum <=78) then
    local param = ccnum - 70
    local delta = val
    local name = params:get_name(param)
    if(val > 64 ) then delta = (128-val) * -1 end
    params:delta(name,delta)
    
  end

end


local function midi_event(data)
  if not data[1] then return end

  local status  = data[1] 
  -- local status  = (data[1] & 0x0F)
  if status == 0x90 then
    note_on(data[2], data[3])
  elseif status == 0x80 then
    note_off(data[2],data[3])
  elseif status == 0xB0 then
    cc(data[2], data[3])
  end
end



midi.add = function(dev)
  dev.event = midi_event
  mididev = dev;
  initmidi()
end
