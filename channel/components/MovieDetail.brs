sub init()
    m.moviePoster = m.top.findNode("moviePoster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.yearLabel = m.top.findNode("yearLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.synopsisLabel = m.top.findNode("synopsisLabel")
    m.castLabel = m.top.findNode("castLabel")
    m.loadingLabel = m.top.findNode("loadingLabel")

    m.playButton = m.top.findNode("playButton")
    m.playButtonBg = m.top.findNode("playButtonBg")
    m.playButtonLabel = m.top.findNode("playButtonLabel")

    m.markWatchedButton = m.top.findNode("markWatchedButton")
    m.markWatchedBg = m.top.findNode("markWatchedBg")
    m.markWatchedLabel = m.top.findNode("markWatchedLabel")

    m.posterCard = m.top.findNode("posterCard")
    m.detailCard = m.top.findNode("detailCard")

    m.top.observeField("focusedChild", "onFocusChanged")

    m.focusedButton = "play"
    m.hasSavedPosition = false
end sub

sub onFocusChanged()
    if m.top.isInFocusChain()
        updateButtonFocus()
    end if
end sub

sub updateButtonFocus()
    if m.focusedButton = "play"
        m.playButtonBg.color = "#00F5FF"
        m.playButtonLabel.color = "#003739"
        m.markWatchedBg.color = "#282A2D"
        m.markWatchedLabel.color = "#B9CACA"
    else
        m.playButtonBg.color = "#1A3A3B"
        m.playButtonLabel.color = "#00DCE5"
        m.markWatchedBg.color = "#00F5FF"
        m.markWatchedLabel.color = "#003739"
    end if
end sub

sub onMovieIdChanged()
    movieId = m.top.movieId
    if movieId = "" then return

    m.loadingLabel.visible = true
    m.playButton.visible = false
    m.markWatchedButton.visible = false
    m.titleLabel.text = ""
    m.metaLabel.text = ""
    m.yearLabel.text = ""
    m.synopsisLabel.text = ""
    m.castLabel.text = ""
    m.moviePoster.uri = ""

    task = CreateObject("roSGNode", "HttpTask")
    task.observeField("response", "onMetaResponse")
    task.request = {
        url: m.top.serverUrl + "/meta/" + movieId,
        method: "GET",
        token: m.top.sessionToken
    }
    task.control = "run"
end sub

sub onMetaResponse(event as Object)
    result = event.getData()
    m.loadingLabel.visible = false

    if result.code <> 200
        m.loadingLabel.text = "Failed to load movie details"
        m.loadingLabel.visible = true
        return
    end if

    meta = ParseJson(result.body)
    if meta = invalid
        m.loadingLabel.text = "Invalid response"
        m.loadingLabel.visible = true
        return
    end if

    m.titleLabel.text = UCase(meta.title)
    m.yearLabel.text = meta.year

    metaStr = meta.year
    if meta.runtime <> invalid and meta.runtime <> ""
        metaStr = meta.runtime + "  |  " + meta.year
    end if
    m.metaLabel.text = metaStr

    m.synopsisLabel.text = meta.synopsis
    m.moviePoster.uri = meta.poster

    if meta.cast <> invalid and meta.cast.count() > 0
        castStr = ""
        for i = 0 to meta.cast.count() - 1
            if i > 0 then castStr = castStr + ", "
            castStr = castStr + meta.cast[i]
        end for
        m.castLabel.text = "Cast: " + castStr
    end if

    saveWatchingMeta(meta)
    checkSavedPosition()

    m.playButton.visible = true
    m.focusedButton = "play"
    updateButtonFocus()
    m.top.setFocus(true)
end sub

sub checkSavedPosition()
    movieId = m.top.movieId
    registry = CreateObject("roRegistrySection", "playback")
    if registry.Exists(movieId)
        position = Val(registry.Read(movieId))
        if position > 30
            m.hasSavedPosition = true
            m.playButtonLabel.text = "Continue Watching"
            m.markWatchedButton.visible = true
            return
        end if
    end if
    m.hasSavedPosition = false
    m.playButtonLabel.text = "Play Movie"
end sub

sub saveWatchingMeta(meta as Object)
    movieId = m.top.movieId
    registry = CreateObject("roRegistrySection", "watching")
    lang = ""
    if meta.lang <> invalid
        lang = LCase(meta.lang)
    end if
    if lang = ""
        lang = getCurrentLang()
    end if

    registry.Write(movieId + "_lang", lang)
    if meta.title <> invalid then registry.Write(movieId + "_title", meta.title)
    if meta.poster <> invalid then registry.Write(movieId + "_poster", meta.poster)
    registry.Flush()
end sub

function getCurrentLang() as String
    registry = CreateObject("roRegistrySection", "watching")
    if registry.Exists("current_lang")
        return registry.Read("current_lang")
    end if
    return "tamil"
end function

sub onPlayPressed()
    m.top.playRequested = m.top.movieId
end sub

sub onMarkWatchedPressed()
    movieId = m.top.movieId
    registry = CreateObject("roRegistrySection", "playback")
    registry.Delete(movieId)
    registry.Flush()

    watchReg = CreateObject("roRegistrySection", "watching")
    watchReg.Delete(movieId + "_lang")
    watchReg.Delete(movieId + "_title")
    watchReg.Delete(movieId + "_poster")
    watchReg.Flush()

    m.hasSavedPosition = false
    m.playButtonLabel.text = "Play Movie"
    m.markWatchedButton.visible = false
    m.focusedButton = "play"
    updateButtonFocus()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "OK"
        if m.focusedButton = "play"
            onPlayPressed()
        else if m.focusedButton = "markWatched"
            onMarkWatchedPressed()
        end if
        return true
    end if

    if key = "right"
        if m.focusedButton = "play" and m.markWatchedButton.visible
            m.focusedButton = "markWatched"
            updateButtonFocus()
            return true
        end if
    else if key = "left"
        if m.focusedButton = "markWatched"
            m.focusedButton = "play"
            updateButtonFocus()
            return true
        end if
    end if

    return false
end function
