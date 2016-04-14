--[[
    * ReaScript Name: MIDI Compress selected notes by pitch
    * Lua script for Cockos REAPER
    * Author: Kirill-I
    * Author URI: https://github.com/indiscipline
    * Licence: GPL v2 or later
    * Version: 1.1
]]

--[[
    * Changelog:
    * v1.1 (2016-04-14)
        + Added global compression
        + Added expansion functionality
        * Taking selection into account
    * v1.0 (2016-04-12)
        + initial release
--]]

--- Keep integer in given range.
-- Returns low if input < low and high if input > high.
-- Doesn't change par if it's in range.
-- If either of the caps is nil, doesn't limit at that extreme.
-- Use 0 and 127 for MIDI.
-- @param par Parameter integer
-- @param low Lower cap, bypassed if nil
-- @param high Higher cap, bypassed if nil
-- @return integer
function saturate_par(par, low, high)
    if low ~= nil and par < low then
        return low
    elseif high~= nil and par > high then
        return high
    else
        return par
    end
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
    local pitch_table
    pitch_table = {}
    if notes > 1 then
        for i = 0, notes-1 do
            local pitch, vel, is_sel
            _, is_sel, _, _, _, _, pitch, vel = reaper.MIDI_GetNote(take, i)
            if is_sel then
                if pitch_table[pitch] == nil then
                    pitch_table[pitch] = {}
                    --reaper.ShowConsoleMsg("\nadded new pitch "..pitch)
                else
                    --reaper.ShowConsoleMsg("\npitch present "..pitch)
                end
                --reaper.ShowConsoleMsg("\nadding to table: id="..i.." vel="..vel)
                pitch_table[pitch][i] = vel
            end
        end
    end
    return pitch_table
end

--- Compress/Expand an array of given pitch MIDI notes.
-- Note array contains note ID and velocities
-- function calculates average velocity and adjust each note by given %
-- @param take Current Reaper MIDI take
-- @param notes Array of MIDI notes keyed by Reaper ID
-- @param comp_rate Compression rate in %
function compress_note_array(take, note_arr, comp_rate)
    if note_arr == nil or take == nil then
        return
    end

    local av_vel, len = 0, 0

    for _, vel in pairs(note_arr) do
        av_vel = av_vel + vel
        len = len + 1
    end

    if len == 0 then
        return
    end

    -- When compression rate > %100, velocities cross the average so
    -- dynamics get inversed. If you need this, comment the statement.
    -- For expansion this doesn't matter because notes just get farther
    -- from the average and eventualy will be capped by MIDI limits.
    comp_rate=saturate_par(comp_rate,nil,100)

    av_vel = av_vel / len
    --reaper.ShowConsoleMsg("\n Average velocity: "..av_vel)
    --Actual computation
    for id, vel in pairs(note_arr) do
        local delta = (vel - av_vel) / 100 * comp_rate
        local new_vel = saturate_par(round(vel - delta),0,127)
        --reaper.ShowConsoleMsg("\nid="..id.." vel="..vel.." new_vel="..new_vel.." delta="..delta)
        reaper.MIDI_SetNote(take, id, NULL, NULL, NULL, NULL, NULL, NULL, new_vel)
    end
end

--- Compress/Expand selected MIDI notes, by each pitch then globally.
-- Positive values for compression, negative for expansion.
-- Populates a table which stores all the notes sorted by pitch and
-- processes each array of notes of each pitch,
-- then processes all the notes
-- @param pitch_comp Pitch-compression rate in %, negative for expansion
-- @param glob_comp  Global compression rate in %, negative for expansion
function main(pitch_comp, glob_comp)

    local midieditor = reaper.MIDIEditor_GetActive()
    if midieditor == nil then
        return nil
    end

    local take = reaper.MIDIEditor_GetTake(midieditor)
    if take == nil then
        return nil
    end

    local notes
    _, notes = reaper.MIDI_CountEvts(take)

-- Pitch compression
    if pitch_comp ~= 0 then
        local pitch_table = get_pitch_table(midieditor, take, notes)
        for pitch,note_arr in pairs(pitch_table) do
            --reaper.ShowConsoleMsg("\nCompressing pitch "..pitch)
            compress_note_array(take, note_arr, pitch_comp)
        end
    end

-- Global compression
    if notes > 1 and glob_comp ~= 0 then
        local note_arr = {}
        for i = 0, notes-1 do
            local vel, is_sel
            _, is_sel, _, _, _, _, _, vel = reaper.MIDI_GetNote(take, i)
            if is_sel then
                --reaper.ShowConsoleMsg("\ni="..i.." vel="..vel)
                note_arr[i] = vel
            end
        end
        --reaper.ShowConsoleMsg("\nCompressing all selected notes")
        compress_note_array(take, note_arr, glob_comp)
    end
end

--- Get user input.
-- Returns basic user iput in numerical form
-- Returns false on fail. Add pars to taste.
-- @return ret_val Success boolean
-- @return par1 Pitch compression
-- @return par2 Global compression
function get_user_input()
    local ret_val, par_csv, par1, par2

    ret_val, par_csv = reaper.GetUserInputs("MIDI compression for each pitch", 2, 'Pitch compression %,Global compression %', '75,25')
    par1, par2 = par_csv:match("([^,]+),([^,]+)")

    par1 = tonumber(par1)
    par2 = tonumber(par2)

    return ret_val, par1, par2
end

ret_val, pitch_comp, glob_comp = get_user_input()
if ret_val and pitch_comp ~= nil and glob_comp ~= nil then
    reaper.Undo_BeginBlock()
    main(pitch_comp, glob_comp)
    reaper.Undo_EndBlock("MIDI: Each pitch compressed separately", 0)
end
