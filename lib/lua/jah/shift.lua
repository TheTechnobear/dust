local ControlSpec = require 'controlspec'
-- local Formatters = require 'jah/formatters'
local Shift = {}

-- Autogenerated using Engine_Shift.generateLuaEngineModuleSpecsSection

local specs = {}

specs.pitch_ratio = ControlSpec.new(0, 4, "linear", 0, 1, "")
specs.pitch_dispersion = ControlSpec.new(0, 4, "linear", 0, 0, "")
specs.time_dispersion = ControlSpec.new(0, 1, "linear", 0, 0, "")
specs.freqshift_freq = ControlSpec.new(-2000, 2000, "linear", 0, 0, "")
specs.freqshift_phase = ControlSpec.PHASE

Shift.specs = specs

local function bind(paramname, id, formatter)
  params:add_control(paramname, specs[id], formatter)
  params:set_action(paramname, engine[id])
end

function Shift.add_params()
  bind("pitch_ratio", "pitch_ratio")
  bind("pitch_dispersion", "pitch_dispersion")
  bind("time_dispersion", "time_dispersion")
  bind("freqshift_freq", "freqshift_freq")
  bind("freqshift_phase", "freqshift_phase")
end

return Shift