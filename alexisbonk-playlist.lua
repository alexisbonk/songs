local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
local monitor = peripheral.find("monitor")

if not speaker then error("Aucun haut-parleur trouvé !") end
if not monitor then error("Aucun écran trouvé !") end

local GITHUB_RAW_URL = "https://github.com/alexisbonk/songs/raw/refs/heads/main/"
local SONG_LIST_URL = "https://api.github.com/repos/alexisbonk/songs/contents/"

local songs = {}
local currentIndex = 1
local isPlaying = true

local function fetch_song_list()
    local response = http.get(SONG_LIST_URL)
    if not response then error("Impossible de récupérer la liste des fichiers") end

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

local function play_song(index)
    if index < 1 or index > #songs then return end
    currentIndex = index
    local url = songs[index]

    local response = http.get(url, nil, true)
    if not response then return end

    local decoder = dfpwm.make_decoder()
    local data = response.readAll()
    response.close()

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.write("🎵 Lecture : " .. url:match(".*/(.*)"))
    
    for i = 1, #data, 16 * 64 do
        if not isPlaying then return end

        local buffer = decoder(data:sub(i, i + 16 * 64 - 1))
        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

local function play_shuffle()
    fetch_song_list()
    if #songs == 0 then error("Aucune chanson trouvée !") end

    shuffle(songs)
    while true do
        if isPlaying then
            play_song(currentIndex)
            currentIndex = currentIndex + 1
            if currentIndex > #songs then currentIndex = 1 end
        end
    end
end

local function handle_buttons()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")

        if y == 2 then
            isPlaying = false
            play_song(math.max(1, currentIndex - 1)) -- Précédent
        elseif y == 4 then
            isPlaying = false
            play_song(math.min(#songs, currentIndex + 1)) -- Suivant
        elseif y == 6 then
            isPlaying = false -- Arrêter la lecture
        elseif y == 8 then
            isPlaying = true
            play_song(currentIndex) -- Rejouer
        end
    end
end

local function draw_buttons()
    monitor.clear()
    monitor.setCursorPos(1, 2)
    monitor.write("⏮️ Précédent")
    monitor.setCursorPos(1, 4)
    monitor.write("⏭️ Suivant")
    monitor.setCursorPos(1, 6)
    monitor.write("⏹️ Stop")
    monitor.setCursorPos(1, 8)
    monitor.write("🔄 Rejouer")
end

draw_buttons()
parallel.waitForAny(play_shuffle, handle_buttons)
