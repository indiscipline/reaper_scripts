--[[
    * ReaScript Name: MIDI Compress selected notes by pitch
    * Lua script for Cockos REAPER
    * Author: Kirill-I
    * Author URI: https://github.com/indiscipline
    * Licence: GPL v2 or later
    * Version: 1.0
]]

--[[
    * Changelog:
    * v1.0 (2016-04-12)
        + initial release
--]]

--- Keep integer in possible MIDI range.
-- Returns 0 if input is negative,
-- and 127 if input is > 127
-- @param par MIDI parameter integer
-- @return integer
function midi_saturate_par(par)
    if par < 0 then
        par = 0
    elseif par > 127 then
        par = 127
    elseif par == nil then
        par = 0
    end
    return par
end

--- Rounding function.
-- Correctly works with negative and 0.5
-- @param num Number to be rounded
-- @return integer
function round(num)
    if num >= 0 then return math.floor(num+.5)
    else return math.ceil(num-.5) end
end

--- Construct a table of MIDI notes.
-- Table contains arrays of notes sorted by pitch
-- Pitch arrays store Reaper note ID and velocity
-- @param midieditor Reaper MIDI editor
-- @param take Current Reaper MIDI take
-- @return pitch_table
function get_pitch_table(midieditor, take, notes)
    local pitch_table, pitch, vel
    pitch_table = {}
    if notes > 1 then
        for i = 0, notes-1 do
            _, _, _, _, _, _, pitch, vel = reaper.MIDI_GetNote(take, i)
            if pitch_table[pitch] == nil then
                pitch_table[pitch] = {}
                --reaper.ShowConsoleMsg("\nadded new pitch "..pitch)
            else
                --reaper.ShowConsoleMsg("\npitch present "..pitch)
            end
            pitch_table[pitch][i] = vel
        end
    end
    return pitch_table
end

--- Compress an array of given pitch MIDI notes.
-- Note array contains note ID and velocities
-- function calculates average velocity and adjust each note by given %
-- @param take Current Reaper MIDI take
-- @param notes Array of MIDI notes keyed by Reaper ID
-- @param comp_rate Compression rate in %
function compress_note_array(take, notes, comp_rate)
    if notes == nil then
        return
    end

    local av_vel, len
    av_vel = 0
    len = 0
    for _, vel in pairs(notes) do
        av_vel = av_vel + vel
        len = len + 1
    end

    if len == 0 then
      return
    end

    av_vel = av_vel / len
    --reaper.ShowConsoleMsg("\n Average velocity: "..av_vel)
    -- Actual computation
    for id, vel in pairs(notes) do
        local delta, new_vel
        delta = (vel - av_vel) / 100 * comp_rate
        new_vel = round(vel - delta)
        --reaper.ShowConsoleMsg("\nid="..id.." vel="..vel.." new_vel="..new_vel.." delta="..delta)
        reaper.MIDI_SetNote(take, id, NULL, NULL, NULL, NULL, NULL, NULL, new_vel)
    end
end

--- Compress selected MIDI notes, be each pitch.
-- General function of the script. Compresses each pitch separately.
-- Populates a table which stores all the notes sorted by pitch and
-- compresses each array of notes of each pitch.
-- @param comp_rate Compression rate in %
function main(comp_rate)
    if comp_rate == nil then
        return
    end

    local midieditor, take, notes, pitch_table

    midieditor = reaper.MIDIEditor_GetActive()
    if midieditor == nil then
        return nil
    end

    take = reaper.MIDIEditor_GetTake(midieditor)
    if take == nil then
        return nil
    end

    _, notes = reaper.MIDI_CountEvts(take)

    pitch_table = get_pitch_table(midieditor, take, notes)

    for pitch,arr in pairs(pitch_table) do
        --reaper.ShowConsoleMsg("\nCompressing pitch "..pitch)
        compress_note_array(take, arr, comp_rate)
    end
end

ret_val, comp_ret = reaper.GetUserInputs("MIDI compression for each pitch", 1, 'Compression %', '75')
comp_rate = tonumber(comp_ret)

if (comp_rate ~= nil) and (ret_val ~= false) then
    reaper.Undo_BeginBlock()
    main(comp_rate)
    reaper.Undo_EndBlock("MIDI: compressed each pitch by %"..comp_rate, 0)
end
