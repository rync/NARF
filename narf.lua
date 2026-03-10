-- NARF: Quad Sequential 
--       Voltage Source
-- 
--      4 Channels of 
--    99-Step Stochastic 
--     MIDI Sequencing
-- 
-- K1 (Hold) + E1: 
--      Select Track (A, B, C, D)
-- E1: Select Step
-- E2: Select Paramater
-- E3: Adjust Parameter
--
-- Parameter details:
--
-- DURATION: E2 toggles between 
--     Numerator/Denominator. 
--     E3 adjusts.
--
-- CC1/CC2: Assignable MIDI CC.
--     Select CC address and 
--     value separately.
--
-- K1 + K3: GLOBAL START / STOP
--
-- K3 (Hold):  
--     SAVE to selected SLOT.
--     Slots are handled 
--     externally in PARAMS.

local tab = require 'tabutil'
local mu = require 'musicutil'

-- 1. DATA STRUCTURES
local tracks = {}
local selected_track = 1
local track_names = {"A", "B", "C", "D"}

local edit_focus = 1
local param_focus = 1
local dur_sub_focus = 1 
local shift = false
local show_splash = true
local flash_level = 0 

local param_names = {"PITCH", "VELOCITY", "DURATION", "CC1 VALUE", "CC2 VALUE", "MODULATION", "ARTICULATION", "GLIDE", "LOOP TO", "REPEATS", "PROBABILITY"}
local m = midi.connect()

-- 2. INITIALIZATION
function init()
  params:set("clock_tempo", 108)

  for i = 1, 4 do
    tracks[i] = {
      active_step = 1,
      is_running = false,
      is_playing_note = false, -- Add this line
      steps = {},
      midi_ch = i, transpose = 0, p_start = 1, p_end = 8,
      cc1_n = 0, cc2_n = 0
    }
    init_steps(i)
  end

  clock.run(function() clock.sleep(2.5); show_splash = false; redraw() end)

  clock.run(function()
    while true do
      if flash_level > 0 then flash_level = flash_level - 1; redraw() end
      clock.sleep(1/15)
    end
  end)

  params:add_separator("narf_config", "NARF CONFIG")
  params:add_number("save_slot", "SAVE/LOAD SLOT", 1, 10, 1)
  params:set_action("save_slot", function(v) load_sequence(v) end)

  params:add_option("send_clock", "SEND MIDI CLOCK", {"OFF", "ON"}, 2)
  params:add_option("rec_mode", "MIDI RECORD MODE", {"OFF", "ON"}, 1)
  params:add_option("midi_remote", "REMOTE MAPPING", {"OFF", "16n", "nKONTROL2"}, 2)

  for i = 1, 4 do
    params:add_group("TRACK " .. track_names[i], 6)
    params:add_number("midi_ch_"..i, "MIDI CHANNEL", 1, 16, i)
    params:add_number("trans_"..i, "TRANSPOSE", -24, 24, 0)
    params:add_number("start_"..i, "PATTERN START", 1, 99, 1)
    params:add_number("end_"..i, "PATTERN END", 1, 99, 24)
    params:add_number("cc1_n_"..i, "CC1 DESTINATION", 0, 127, 0)
    params:add_number("cc2_n_"..i, "CC2 DESTINATION", 0, 127, 0)
    params:set_action("midi_ch_"..i, function(v) tracks[i].midi_ch = v end)
    params:set_action("trans_"..i, function(v) tracks[i].transpose = v end)
    params:set_action("start_"..i, function(v) tracks[i].p_start = v end)
    params:set_action("end_"..i, function(v) tracks[i].p_end = v end)
    params:set_action("cc1_n_"..i, function(v) tracks[i].cc1_n = v end)
    params:set_action("cc2_n_"..i, function(v) tracks[i].cc2_n = v end)
  end

  params:add_number("global_trans", "GLOBAL TRANSPOSE", -24, 24, 0)

  params:add_trigger("clear_track", "CLEAR SELECTED TRACK")
  params:set_action("clear_track", function()
    init_steps(selected_track)
    print("Cleared Track " .. track_names[selected_track])
    redraw()
  end)

  params:add_separator("quantize_config", "QUANTIZATION")
  params:add_option("quantize", "QUANTIZE", {"OFF", "ON"}, 1)
  params:add_option("root_note", "ROOT NOTE", mu.NOTE_NAMES, 1)
  local scale_names = {}
  for i=1, #mu.SCALES do table.insert(scale_names, mu.SCALES[i].name) end
  params:add_option("scale", "SCALE", scale_names, 1)

  m.event = function(data)
    local msg = midi.to_msg(data)
    local remote = params:get("midi_remote")
    if msg.type == "note_on" and params:get("rec_mode") == 2 then record_midi_step(msg.note, msg.vel)
    elseif msg.type == "cc" and remote > 1 then handle_remote_cc(msg.cc, msg.val, remote) end
  end

  load_sequence(params:get("save_slot"))
  redraw()
end

function init_steps(t)
  for i = 1, 99 do
    tracks[t].steps[i] = {
      pitch = 60, vel = 100, num = 1, den = 4, cc1_v = 0, cc2_v = 0,
      mod = 0, artic = 0.8, glide = 0, loop_to = 0, repeats = 0, count = 0, prob = 100
    }
  end
end

-- 3. REMOTE MIDI HANDLER
function handle_remote_cc(cc, val, mode)
  if mode == 2 then
    if cc >= 32 and cc <= 35 then tracks[cc-31].steps[edit_focus].pitch = val
    elseif cc >= 36 and cc <= 39 then tracks[cc-35].steps[edit_focus].vel = val
    elseif cc >= 40 and cc <= 43 then tracks[cc-39].steps[edit_focus].num = util.clamp(math.floor(val/4)+1, 1, 32)
    elseif cc >= 44 and cc <= 47 then tracks[cc-43].steps[edit_focus].mod = val end
  end
  redraw()
end

-- 4. SEQUENCER LOOP
function run_track(t_idx)
  local t = tracks[t_idx]
  if params:get("send_clock") == 2 then m:start() end
  while t.is_running do
    local s = t.steps[t.active_step]
    local global_transpose = params:get("global_trans")
    local final_pitch = get_quantized_note(s.pitch + t.transpose + global_transpose)
    if s.glide > 0 then m:cc(65, 127, t.midi_ch); m:cc(5, s.glide, t.midi_ch) end
    if t.cc1_n > 0 then m:cc(t.cc1_n, s.cc1_v, t.midi_ch) end
    if t.cc2_n > 0 then m:cc(t.cc2_n, s.cc2_v, t.midi_ch) end
    m:note_on(final_pitch, s.vel, t.midi_ch)
    m:cc(1, s.mod, t.midi_ch)
    local dur_beats = (s.num / s.den) * 4
    local total_sleep = dur_beats * clock.get_beat_sec()
    if s.artic < 1.0 then
      clock.sleep(total_sleep * s.artic); m:note_off(final_pitch, 0, t.midi_ch); clock.sleep(total_sleep * (1 - s.artic))
    else clock.sleep(total_sleep);
      m:note_off(final_pitch, 0, t.midi_ch)
      t.is_playing_note = false -- Note ended
      redraw()
    end

    local next_step = t.active_step + 1
    if s.loop_to > 0 and s.repeats > 0 and s.loop_to < t.p_end and s.loop_to >= t.p_start then
      if math.random(1, 100) <= s.prob then
        if s.count < s.repeats then s.count = s.count + 1; next_step = s.loop_to else s.count = 0 end
      else s.count = 0 end
    end
    if next_step > t.p_end or next_step < t.p_start then
      next_step = t.p_start
      flash_level = 4
    end
    t.active_step = next_step; redraw()
  end
end

-- 5. HARDWARE INTERACTION
function enc(n, d)
  if show_splash then show_splash = false; redraw(); return end
  local t = tracks[selected_track]; local s = t.steps[edit_focus]
  if n == 1 then
    if shift then
      -- Change Tempo with Shift + E1
      params:set("clock_tempo", util.clamp(math.floor(clock.get_tempo() + d), 20, 300))
    else
      -- Select Step with just E1
      edit_focus = util.clamp(edit_focus + d, 1, 99)
    end
  elseif n == 2 then
    if shift then
      -- Change Track with Shift + E2
      selected_track = util.clamp(selected_track + d, 1, 4)
    elseif param_focus == 3 then
      -- [Keep your existing duration sub-focus logic here]
      dur_sub_focus = dur_sub_focus + d
      if dur_sub_focus > 2 or dur_sub_focus < 1 then
        param_focus = util.clamp(param_focus + (dur_sub_focus < 1 and -1 or 1), 1, #param_names)
        dur_sub_focus = (dur_sub_focus < 1) and 1 or 2
      end
    else
      param_focus = util.clamp(param_focus + d, 1, #param_names)
      if param_focus == 3 then dur_sub_focus = (d > 0) and 1 or 2 end
    end
  elseif n == 3 then
    if param_focus == 1 then s.pitch = util.clamp(s.pitch + d, 0, 127)
    elseif param_focus == 2 then s.vel = util.clamp(s.vel + d, 0, 127)
    elseif param_focus == 3 then
      if dur_sub_focus == 1 then s.num = util.clamp(s.num + d, 1, 32) else s.den = util.clamp(s.den + d, 1, 32) end
    elseif param_focus == 4 then s.cc1_v = util.clamp(s.cc1_v + d, 0, 127)
    elseif param_focus == 5 then s.cc2_v = util.clamp(s.cc2_v + d, 0, 127)
    elseif param_focus == 6 then s.mod = util.clamp(s.mod + d, 0, 127)
    elseif param_focus == 7 then s.artic = util.clamp(s.artic + (d * 0.05), 0.05, 1)
    elseif param_focus == 8 then s.glide = util.clamp(s.glide + d, 0, 127)
    elseif param_focus == 9 then s.loop_to = util.clamp(s.loop_to + d, 0, 99)
    elseif param_focus == 10 then s.repeats = util.clamp(s.repeats + d, 0, 16)
    -- Add this line for the 11th parameter:
    elseif param_focus == 11 then s.prob = util.clamp(s.prob + d, 0, 100)
    end
  end
  redraw()
end

function key(n, z)
  if show_splash then show_splash = false; redraw(); return end
  if n == 1 then shift = (z == 1) end
  if n == 2 and z == 1 then
    if shift then tracks[selected_track].active_step = edit_focus
    else
      tracks[selected_track].is_running = not tracks[selected_track].is_running
      if tracks[selected_track].is_running then clock.run(function() run_track(selected_track) end) end
    end
  elseif n == 3 then
    if shift then if z == 1 then global_toggle() end
    else
      if z == 1 then hold_start = util.time()
      else if util.time() - hold_start > 1 then save_sequence(params:get("save_slot")) else randomize_step(selected_track, edit_focus) end end
    end
  end
  redraw()
end

-- 6. GLOBAL, SAVE/LOAD, SPLASH
function global_toggle()
  local any_r = false
  for i=1,4 do if tracks[i].is_running then any_r = true end end
  if any_r then for i=1,4 do tracks[i].is_running = false end
  else for i=1,4 do tracks[i].active_step = tracks[i].p_start; tracks[i].is_running = true; clock.run(function() run_track(i) end) end end
  redraw()
end

function save_sequence(slot)
  local d = {}; for i=1,4 do d[i] = tracks[i].steps end
  tab.save(d, norns.state.data .. "narf_slot_"..slot..".data"); print("NARF Saved to Slot "..slot)
end

function load_sequence(slot)
  local p = norns.state.data .. "narf_slot_"..slot..".data"
  if util.file_exists(p) then local sd = tab.load(p); for i=1,4 do tracks[i].steps = sd[i] end print("Slot "..slot.." Loaded") end
  redraw()
end

function record_midi_step(p, v)
  local s = tracks[selected_track].steps[edit_focus]
  s.pitch = p; s.vel = v; edit_focus = util.clamp(edit_focus + 1, 1, 99); redraw()
end

function get_quantized_note(note)
  if params:get("quantize") == 1 then return note end
  local r, si = params:get("root_note"), params:get("scale")
  local sn = mu.generate_scale_of_length(r, mu.SCALES[si].name, 127)
  return mu.snap_to_notes(sn, note)
end

function randomize_step(t, i)
  local r_p = math.random(36, 84); tracks[t].steps[i].pitch = get_quantized_note(r_p)
  tracks[t].steps[i].vel = math.random(60, 115); tracks[t].steps[i].prob = math.random(1, 10) * 10
end

function draw_splash()
  screen.clear()
  screen.level(15)
  screen.move(64, 28)
  screen.text_center("NARF")
  screen.level(4)
  screen.move(64, 42)
  screen.text_center("Sequential Voltage Source")
  screen.update()
end

-- 7. REDRAW
function redraw()
  if show_splash then draw_splash(); return end
  screen.clear()
  if flash_level > 0 then screen.level(flash_level); screen.rect(0,0,128,64); screen.fill() end
  for i=1,4 do
    screen.level(selected_track == i and 15 or 2)
    screen.move((i-1)*12, 7); screen.text(track_names[i])
    if tracks[i].is_running then screen.rect((i-1)*12, 8, 8, 1); screen.fill() end
  end
  screen.font_size(8)
  screen.font_face(0)
  screen.level(3)
  screen.move(127, 7)

  local bpm_val = math.floor(clock.get_tempo())
  screen.text_right("BPM: "..bpm_val.."  Save: "..params:get("save_slot"))
  screen.move(127, 16)
  screen.text_right("Play: "..tracks[selected_track].active_step.."  Edit: "..edit_focus)

  local t = tracks[selected_track]; local center_x, sc = 64, 12
  local is_last_step = (t.active_step == t.p_end); local cur_s = t.steps[t.active_step]
  local cur_w = math.max(2, (cur_s.num/cur_s.den)*4*sc); screen.level(is_last_step and 15 or 12)
  local h_mult = 10
  local bar_h = (cur_s.pitch/127)*h_mult;
  screen.rect(center_x-(cur_w/2), 32-bar_h, cur_w, bar_h);
  screen.fill()
  if is_last_step then
    screen.level(15);
    screen.move(center_x, 12);
    screen.line_rel(-2,-2);
    screen.line_rel(4,0);
    screen.line_rel(-2,2);
    screen.fill()
  end
  local fw_x = center_x + (cur_w/2) + 2

  screen.font_face(0)
  screen.font_size(8)
  for i = 1, 10 do
    local idx = t.active_step + i;
    if idx <= 99 and fw_x < 128 then
      local s = t.steps[idx];
      local w = math.max(1, (s.num/s.den)*2*sc)
      if idx == t.p_end then
        screen.level(10);
        screen.rect(fw_x, 19, 6, 1);
        screen.fill();
        screen.move(fw_x + w, 19);
        screen.line_rel(0, 4);
        screen.stroke()
      end
      screen.level((idx >= t.p_start and idx <= t.p_end) and 2 or 1);
      if idx == edit_focus then
        screen.level(5)
      end
      local h = (s.pitch/127)*h_mult;
      screen.rect(fw_x, 32-h, w, h);
      screen.fill();
      fw_x = fw_x + w + 1
    end
  end
  screen.level(1); screen.move(0, 36); screen.line(127, 36); screen.stroke()
  local s = t.steps[edit_focus]
  local vals = {
    s.pitch .. " (" .. mu.note_num_to_name(s.pitch, true) .. ")", -- 1: Shows "60 (C3)"
    s.vel,             -- 2
    s.num.."/"..s.den, -- 3
    s.cc1_v,           -- 4
    s.cc2_v,           -- 5
    s.mod,             -- 6
    math.floor(s.artic*100).."%", -- 7
    s.glide,           -- 8
    s.loop_to,         -- 9
    s.repeats,         -- 10
    s.prob.."%"        -- 11
  }

  -- Calculate scrolling window
  local start = util.clamp(param_focus - 1, 1, math.max(1, #param_names - 3))

  for i = 0, 3 do
    local idx = start + i
    if idx <= #param_names then
      local y = 44 + (i * 6)
      screen.level(param_focus == idx and 15 or 2)

      -- 1. DRAW LABEL (Left Aligned)
      screen.move(8, y)
      local label = param_names[idx]
      -- Add the "!" indicator if we are editing the last step of a pattern
      if edit_focus == t.p_end and idx <= 2 then label = label .. "!" end
      screen.text(label)

      -- 2. DRAW VALUE (Right Aligned)
      -- We move to 122 to leave a small 6-pixel margin from the edge
      screen.move(122, y)

      if idx == 3 then
        -- Duration is special: we draw parts manually to handle sub-focus colors
        -- Since text_right doesn't support multiple colors easily,
        -- we'll draw it right-to-left manually
        local d_val = s.den
        local n_val = s.num

        screen.level(param_focus == 3 and (dur_sub_focus == 2 and 15 or 4) or 2)
        screen.text_right(d_val)

        -- Get width of denominator to offset the slash and numerator
        local d_width = 10
        screen.move(122 - d_width, y)
        screen.level(param_focus == 3 and 15 or 2)
        screen.text_right("/")

        local s_width = 8
        screen.move(122 - d_width - s_width, y)
        screen.level(param_focus == 3 and (dur_sub_focus == 1 and 15 or 4) or 2)
        screen.text_right(n_val)
      else
        -- Standard values just use text_right
        screen.text_right(vals[idx])
      end

      -- 3. DRAW SELECTION INDICATOR
      if param_focus == idx then
        screen.level(15)
        screen.move(2, y)
        screen.text(">")
      end
    end
  end
  screen.update()
end