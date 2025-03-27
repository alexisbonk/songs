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

local VERSION = "v1.3"

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
    monitor.setCursorPos(3, 6)
    monitor.write("Prev")
    monitor.setBackgroundColor(colors.green)
    monitor.setTextColor(colors.white)
    monitor.setCursorPos(12, 6)
    monitor.write("Next")
    monitor.setBackgroundColor(colors.lightGray)
    monitor.setTextColor(colors.black)
    monitor.setCursorPos(3, 9)
    monitor.write("Pause")
    monitor.setBackgroundColor(colors.red)
    monitor.setTextColor(colors.white)
    monitor.setCursorPos(12, 9)
    monitor.write("Play")

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

local function draw_songs()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    for i, song in ipairs(songs) do
        monitor.setCursorPos(2, i + 2)
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

local function update_song_display(songName)
    monitor.setCursorPos(2, 2)
    monitor.clearLine()
    monitor.write("Now Playing: " .. songName)
end

local function play_song(index)
    if index < 1 or index > #songs then return end
    currentIndex = index
    local url = songs[index]
    local songName = url:match(".*/(.*)")
    update_song_display(songName)

    local response = http.get(url, nil, true)
    if not response then return end

    local decoder = dfpwm.make_decoder()
    local data = response.readAll()
    response.close()

    for i = 1, #data, 16 * 64 do
        if isPaused then return end
        if not isPlaying then return end
        local buffer = decoder(data:sub(i, i + 16 * 64 - 1))
        audioBuffer = buffer
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

local function play_shuffle()
    fetch_song_list()
    if #songs == 0 then return end
    shuffle(songs)
    while true do
        if isPlaying then
            play_song(currentIndex)
            currentIndex = currentIndex + 1
            if currentIndex > #songs then currentIndex = 1 end
        end
        os.pullEvent()
    end
end

local function handle_buttons()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if x >= 3 and x <= 9 and y == 6 then
            isPlaying = false
            play_song(math.max(1, currentIndex - 1))
        elseif x >= 12 and x <= 18 and y == 6 then
            isPlaying = false
            play_song(math.min(#songs, currentIndex + 1))
        elseif x >= 3 and x <= 9 and y == 9 then
            isPaused = true
            isPlaying = false
            if audioBuffer then
                speaker.stopAudio()
            end
        elseif x >= 12 and x <= 18 and y == 9 then
            isPaused = false
            isPlaying = true
            play_song(currentIndex)
        else
            for i = 1, #songs do
                if y == i + 2 and x >= 2 and x <= 18 then
                    isPlaying = true
                    play_song(i)
                    return
                end
            end
        end
    end
end

local function draw_version()
    monitor.setCursorPos(1, 15)  -- Position deux lignes après les boutons
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
parallel.waitForAny(play_shuffle, handle_buttons)
