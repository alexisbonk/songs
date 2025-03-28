local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
local monitor = peripheral.find("monitor")

if not speaker then
    print("No speaker found!")
    return
end

if not monitor then
    print("No monitor found!")
    return
end

monitor.setTextScale(1)
monitor.clear()

local GITHUB_RAW_URL = "https://github.com/alexisbonk/songs/raw/refs/heads/main/"
local SONG_LIST_URL = "https://api.github.com/repos/alexisbonk/songs/contents/"

local songs = {}
local currentIndex = 1
local isPlaying = false
local isPaused = false
local VERSION = 2.0

local function fetch_song_list()
    local response = http.get(SONG_LIST_URL)
    if not response then
        print("Failed to fetch song list!")
        return
    end
    local data = textutils.unserializeJSON(response.readAll())
    response.close()

    for _, file in pairs(data) do
        if file.name:match("%.dfpwm$") then
            table.insert(songs, GITHUB_RAW_URL .. file.name)
        end
    end
end

local function draw_songs()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    for i, song in ipairs(songs) do
        monitor.setCursorPos(2, i + 6)
        if i == currentIndex then
            monitor.setBackgroundColor(colors.white)
            monitor.setTextColor(colors.black)
        else
            monitor.setBackgroundColor(colors.black)
            monitor.setTextColor(colors.white)
        end
        local songName = song:match(".*/(.*)"):gsub("_", " "):gsub(".dfpwm", "")
        monitor.write(songName)
    end
end

local function update_song_display()
    monitor.setCursorPos(2, 2)
    monitor.clearLine()
    if isPlaying then
        local songName = songs[currentIndex]:match(".*/(.*)"):gsub("_", " "):gsub(".dfpwm", "")
        monitor.setTextColor(colors.white)
        monitor.write("Now Playing: " .. songName)
    end
end

local function play_song(index)
    if index < 1 or index > #songs then return end
    currentIndex = index
    isPlaying = true
    isPaused = false
    update_song_display()

    local response = http.get(songs[index], nil, true)
    if not response then return end
    
    local decoder = dfpwm.make_decoder()
    local data = response.readAll()
    response.close()

    local i = 1
    while i <= #data do
        while isPaused do
            os.pullEvent("monitor_touch")
        end
        if not isPlaying then return end
        local buffer = decoder(data:sub(i, i + 16 * 64 - 1))
        if buffer then
            while not speaker.playAudio(buffer) do
                os.pullEvent("speaker_audio_empty")
            end
        end
        i = i + 16 * 64
    end
    isPlaying = false
    update_song_display()
end

local function handle_buttons()
    while true do
        local _, _, x, y = os.pullEvent("monitor_touch")
        if x >= 3 and x <= 9 and y == 14 then  -- Prev
            currentIndex = (currentIndex > 1) and (currentIndex - 1) or #songs
            if isPlaying then play_song(currentIndex) end
        elseif x >= 12 and x <= 18 and y == 14 then  -- Next
            currentIndex = (currentIndex < #songs) and (currentIndex + 1) or 1
            if isPlaying then play_song(currentIndex) end
        elseif x >= 3 and x <= 9 and y == 18 then  -- Pause
            isPaused = true
        elseif x >= 12 and x <= 18 and y == 18 then  -- Play
            isPaused = false
            if not isPlaying then play_song(currentIndex) end
        else
            for i = 1, #songs do
                if y == i + 6 and x >= 2 and x <= 18 then
                    currentIndex = i
                    isPlaying = true
                    play_song(i)
                    return
                end
            end
        end
    end
end

local function draw_version()
    VERSION = VERSION + 0.1
    monitor.setCursorPos(1, 25)
    monitor.clearLine()
    monitor.setTextColor(colors.white)
    monitor.write("Version: " .. string.format("%.1f", VERSION))
end

monitor.clear()
fetch_song_list()
draw_songs()
draw_version()
parallel.waitForAny(handle_buttons)
