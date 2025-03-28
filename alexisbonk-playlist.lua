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
local audioBuffer = nil

local VERSION = "v1.5"

local function fetch_song_list()
    local response = http.get(SONG_LIST_URL)
    if not response then return end
    local data = textutils.unserializeJSON(response.readAll())
    response.close()

    for _, file in pairs(data) do
        if file.name:match("%.dfpwm$") then
            table.insert(songs, GITHUB_RAW_URL .. file.name)
        end
    end
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

local function draw_buttons()
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.setCursorPos(3, 4)
    monitor.write("Prev")
    monitor.setBackgroundColor(colors.green)
    monitor.setTextColor(colors.white)
    monitor.setCursorPos(12, 4)
    monitor.write("Next")
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.setCursorPos(3, 8)
    monitor.write("Pause")
    monitor.setBackgroundColor(colors.red)
    monitor.setTextColor(colors.white)
    monitor.setCursorPos(12, 8)
    monitor.write("Play")

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

local function draw_songs()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    for i, song in ipairs(songs) do
        monitor.setCursorPos(2, i + 12)
        if i == currentIndex then
            monitor.setBackgroundColor(colors.white)
            monitor.setTextColor(colors.black)
        else
            monitor.setBackgroundColor(colors.black)
            monitor.setTextColor(colors.white)
        end
        local songName = song:match(".*/(.*)")
        monitor.write(songName)
    end
end

local function update_song_display()
    monitor.setCursorPos(2, 2)
    monitor.clearLine()
    if isPlaying then
        local songName = songs[currentIndex]:match(".*/(.*)")
        monitor.write("Now Playing: " .. songName)
    end
end

local function play_song(index)
    if index < 1 or index > #songs then return end
    currentIndex = index
    isPlaying = true
    update_song_display()

    local url = songs[index]
    local response = http.get(url, nil, true)
    if not response then return end

    local decoder = dfpwm.make_decoder()
    local data = response.readAll()
    response.close()

    for i = 1, #data, 16 * 64 do
        if isPaused then
            repeat os.pullEvent("monitor_touch") until not isPaused
        end
        if not isPlaying then return end
        local buffer = decoder(data:sub(i, i + 16 * 64 - 1))
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
    isPlaying = false
    update_song_display()
end

local function handle_buttons()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if x >= 3 and x <= 9 and y == 4 then
            isPlaying = false
            play_song(math.max(1, currentIndex - 1))
            draw_songs()
        elseif x >= 12 and x <= 18 and y == 4 then
            isPlaying = false
            play_song(math.min(#songs, currentIndex + 1))
            draw_songs()
        elseif x >= 3 and x <= 9 and y == 8 then
            isPaused = not isPaused
        elseif x >= 12 and x <= 18 and y == 8 then
            isPaused = false
            isPlaying = true
            play_song(currentIndex)
        else
            for i = 1, #songs do
                if y == i + 12 and x >= 2 and x <= 18 then
                    isPlaying = true
                    play_song(i)
                    return
                end
            end
        end
    end
end

local function draw_version()
    monitor.setCursorPos(1, 20)
    monitor.clearLine()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.write("Version: " .. VERSION)
end

monitor.clear()
fetch_song_list()
draw_buttons()
draw_songs()
draw_version()
parallel.waitForAny(handle_buttons)
