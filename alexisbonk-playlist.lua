local dfpwm = require("cc.audio.dfpwm")
local speaker = peripheral.find("speaker")

if not speaker then
    print("Aucun haut-parleur trouvé !")
end

local GITHUB_RAW_URL = "https://github.com/alexisbonk/songs/raw/refs/heads/main/"
local SONG_LIST_URL = "https://api.github.com/repos/alexisbonk/songs/contents/"

local function fetch_song_list()
    local response = http.get(SONG_LIST_URL)
    if not response then error("Impossible de récupérer la liste des fichiers") end

    local data = textutils.unserializeJSON(response.readAll())
    response.close()

    local songs = {}
    for _, file in pairs(data) do
        if file.name:match("%.dfpwm$") then
            table.insert(songs, GITHUB_RAW_URL .. file.name)
        end
    end
    return songs
end

local function play_song(url)
    local response = http.get(url, nil, true)
    if not response then return end

    local decoder = dfpwm.make_decoder()
    local data = response.readAll()
    response.close()

    for i = 1, #data, 16 * 64 do
        local buffer = decoder(data:sub(i, i + 16 * 64 - 1))

        while not speaker.playAudio(buffer) do
            os.pullEvent("speaker_audio_empty")
        end
    end
end

local function shuffle(tbl)
    for i = #tbl, 2, -1 do
        local j = math.random(i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
end

local function play_shuffle()
    local songs = fetch_song_list()
    if #songs == 0 then print("Aucune chanson trouvée !") end

    while true do
        shuffle(songs)
        for _, song in ipairs(songs) do
            play_song(song)
        end
    end
end

play_shuffle()
