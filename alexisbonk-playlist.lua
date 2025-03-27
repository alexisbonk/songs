local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")
local monitor = peripheral.find("monitor")

if not speaker then
    print("Aucun haut-parleur trouvé !")
    return
end

if not monitor then
    print("Aucun écran trouvé !")
    return
end

monitor.setTextScale(2) -- Agrandir le texte pour les 4 moniteurs
monitor.clear()

local GITHUB_RAW_URL = "https://github.com/alexisbonk/songs/raw/refs/heads/main/"
local SONG_LIST_URL = "https://api.github.com/repos/alexisbonk/songs/contents/"

local songs = {}
local currentIndex = 1
local isPlaying = true

local function fetch_song_list()
    print("Récupération de la liste des chansons...")
    local response = http.get(SONG_LIST_URL)
    if not response then
        print("Impossible de récupérer la liste des fichiers.")
        return
    end

    local data = textutils.unserializeJSON(response.readAll())
    response.close()

    for _, file in pairs(data) do
        if file.name:match("%.dfpwm$") then
            table.insert(songs, GITHUB_RAW_URL .. file.name)
        end
    end

    if #songs == 0 then
        print("Aucune chanson trouvée dans le dépôt GitHub.")
    else
        print("Chansons récupérées :", #songs)
    end
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

local function play_song(index)
    if index < 1 or index > #songs then
        print("Index de chanson invalide.")
        return
    end
    currentIndex = index
    local url = songs[index]

    print("Lecture de :", url:match(".*/(.*)"))
    local response = http.get(url, nil, true)
    if not response then
        print("Impossible de récupérer la chanson :", url)
        return
    end

    local decoder = dfpwm.make_decoder()
    local data = response.readAll()
    response.close()

    monitor.clear()
    monitor.setCursorPos(2, 2)
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
    if #songs == 0 then return end

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

        if x >= 3 and x <= 9 and y == 6 then
            print("⏮️ Chanson précédente")
            isPlaying = false
            play_song(math.max(1, currentIndex - 1))
        elseif x >= 12 and x <= 18 and y == 6 then
            print("⏭️ Chanson suivante")
            isPlaying = false
            play_song(math.min(#songs, currentIndex + 1))
        elseif x >= 3 and x <= 9 and y == 9 then
            print("⏹️ Arrêt de la lecture")
            isPlaying = false
        elseif x >= 12 and x <= 18 and y == 9 then
            print("🔄 Rejouer la chanson")
            isPlaying = true
            play_song(currentIndex)
        end
    end
end

local function draw_buttons()
    monitor.clear()
    monitor.setCursorPos(3, 6)
    monitor.write("⏮️ Précédent")
    monitor.setCursorPos(12, 6)
    monitor.write("⏭️ Suivant")
    monitor.setCursorPos(3, 9)
    monitor.write("⏹️ Stop")
    monitor.setCursorPos(12, 9)
    monitor.write("🔄 Rejouer")
end

draw_buttons()
parallel.waitForAny(play_shuffle, handle_buttons)
