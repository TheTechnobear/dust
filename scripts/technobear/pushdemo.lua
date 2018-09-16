-- draw demo
--
-- code shows all of the screen
-- drawing functions

engine.name = 'TestSine'

local metro = require 'metro'

local i = 0
local ctl = nil
local dev = nil
local mididev = nil
local mode = 0

function init()
  engine.amp(0)

  params:add_number("tempo",20,240,48)
  params:add_number("pw",0,1,1)
  params:add_number("cutoff",1,20000,500)
  params:add_number("res",0,100,48)
  params:add_number("attack",0,240,48)
  params:add_number("decay",0,240,48)
    -- dev = push2.devices[2].dev
  for i = 0, 10 do 
    if push2.devices[i] ~= nil then 
      dev = push2.devices[i].dev
    end
  end

  if dev == nil then
   return
  end

  clk = metro.alloc()
  clk.time = 1/15
  clk.callback = function(stage)
    redraw()
  end
  clk:start()

end

function cleanup()
  metro.free(cld.id)
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
    anim(dev)
  elseif mode == 1 then
    drawall(dev)
  else
    pdraw(dev)
  end
  p2_update(dev);
end

function pdraw(dev) 
  for param_index = 0,params.count do
    print(params:get_name(param_index))
    p2_move(dev,param_index *100,30)
    p2_text(dev,params:get_name(param_index))
    p2_move(dev,param_index *100,50)
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
  p2_line(dev,10,20)
  p2_stroke(dev)

  p2_arc(dev,20,0,10,0,math.pi*0.8)
  p2_stroke(dev)

  p2_rect(dev,30,10,15,20)
  p2_colour(dev, 0,1,0)
  p2_stroke(dev)

  p2_move(dev,50,0)
  p2_curve(dev,50,20,60,0,70,10)
  p2_colour(dev, 0,0,1)
  p2_stroke(dev)
  p2_move(dev,60,20)

  p2_line(dev,80,10)
  p2_line(dev,70,40)
  p2_close(dev)
  p2_colour(dev, 1,1,1)
  p2_fill(dev)

  p2_circle(dev,100,20,10)
  p2_stroke(dev)

  p2_move(dev,0,100)
  p2_font_face(dev,4)
  p2_font_size(dev,40)

  local r = i % 16;
  local g = (i / 16 ) %16;
  local b = (i / (16*16)) % 16;
  p2_colour(dev, 1/r, 1/g,1/b)
  p2_text(dev,"new!")

  p2_colour(dev, 1,0,0)
  p2_move(dev,63,50)
  p2_font_face(dev,0)
  p2_font_size(dev,8)
  p2_text_center(dev,"center")
  -- draw right aligned text
  p2_move(dev,127,63)
  p2_text_right(dev,"1992")

end

local function note_on(note, vel)
  local data = {0x90,note,vel}
  midi_send(mididev,data)
end

local function note_off(note, vel)
  local data = {0x80,note,vel}
  midi_send(mididev,data)
end

local function cc(ccnum, val)
  print("cc"..ccnum..":"..val)
  if ccnum == 110 and val> 0 then
    mode = (mode + 1) % 3
    p2_clear(dev)
    p2_update(dev)
    print(params.count)
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

local function initmidi(dev)
  for i=9,7 do
  local data = {0xB0,i+102,i}
    midi_send(dev,data)
  end
  midi_send(dev, {0xB0,110,127})
end

midi.add = function(dev)
  dev.event = midi_event
  mididev = dev.dev
  initmidi(dev.dev)
end
