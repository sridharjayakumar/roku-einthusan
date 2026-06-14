sub init()
    m.videoNode = m.top.findNode("videoNode")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.errorLabel = m.top.findNode("errorLabel")

    m.seekBarGroup = m.top.findNode("seekBarGroup")
    m.currentTimeLabel = m.top.findNode("currentTimeLabel")
    m.durationLabel = m.top.findNode("durationLabel")
    m.seekTrackProgress = m.top.findNode("seekTrackProgress")
    m.stateLabel = m.top.findNode("stateLabel")

    m.videoNode.observeField("state", "onVideoStateChange")
    m.videoNode.observeField("position", "onPositionChange")

    m.seekBarVisible = false
    m.hideTimer = CreateObject("roSGNode", "Timer")
    m.hideTimer.duration = 4
    m.hideTimer.repeat = false
    m.hideTimer.observeField("fire", "onHideTimer")

    m.saveTimer = CreateObject("roSGNode", "Timer")
    m.saveTimer.duration = 30
    m.saveTimer.repeat = true
    m.saveTimer.observeField("fire", "onSaveTimer")

    m.trackWidth = 1760
    m.currentMovieId = ""
    m.resumePosition = 0
    m.hasResumed = false
end sub

sub onMovieIdChanged()
    movieId = m.top.movieId
    if movieId = "" then return

    m.currentMovieId = movieId
    m.hasResumed = false
    m.resumePosition = getSavedPosition(movieId)

    m.loadingLabel.visible = true
    m.errorLabel.visible = false
    m.seekBarGroup.visible = false
    m.videoNode.control = "stop"

    task = CreateObject("roSGNode", "HttpTask")
    task.observeField("response", "onStreamResponse")
    task.request = {
        url: m.top.serverUrl + "/stream/" + movieId,
        method: "GET",
        token: m.top.sessionToken
    }
    task.control = "run"
end sub

sub onStreamResponse(event as Object)
    result = event.getData()
    m.loadingLabel.visible = false

    if result.code <> 200
        showError("Failed to get stream URL")
        return
    end if

    parsed = ParseJson(result.body)
    if parsed = invalid
        showError("No stream URL available")
        return
    end if

    streamUrl = ""
    streamFormat = "mp4"
    if parsed.mp4 <> invalid and parsed.mp4 <> ""
        streamUrl = parsed.mp4
        streamFormat = "mp4"
    else if parsed.hls <> invalid and parsed.hls <> ""
        streamUrl = parsed.hls
        streamFormat = "hls"
    end if

    if streamUrl = ""
        showError("No stream URL available")
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    content.url = streamUrl
    content.streamFormat = streamFormat

    m.videoNode.content = content
    m.videoNode.control = "play"
    m.top.setFocus(true)
end sub

sub onVideoStateChange()
    state = m.videoNode.state
    if state = "error"
        showError("Playback error")
    else if state = "finished"
        clearSavedPosition(m.currentMovieId)
        m.saveTimer.control = "stop"
        m.top.playbackDone = true
    else if state = "paused"
        savePosition()
        showSeekBar("PAUSED")
    else if state = "playing"
        if not m.hasResumed and m.resumePosition > 30
            m.hasResumed = true
            m.videoNode.seek = m.resumePosition
            showSeekBar("Resuming at " + formatTime(m.resumePosition))
            startHideTimer()
        else
            m.hasResumed = true
        end if
        m.saveTimer.control = "start"
        startHideTimer()
    end if
end sub

sub onPositionChange()
    if m.seekBarVisible
        updateSeekBar()
    end if
end sub

sub onSaveTimer()
    savePosition()
end sub

sub savePosition()
    if m.currentMovieId = "" then return
    position = m.videoNode.position
    if position > 10
        registry = CreateObject("roRegistrySection", "playback")
        registry.Write(m.currentMovieId, Int(position).toStr())
        registry.Flush()
    end if
end sub

function getSavedPosition(movieId as String) as Integer
    registry = CreateObject("roRegistrySection", "playback")
    if registry.Exists(movieId)
        saved = registry.Read(movieId)
        return Val(saved)
    end if
    return 0
end function

sub clearSavedPosition(movieId as String)
    if movieId = "" then return
    registry = CreateObject("roRegistrySection", "playback")
    registry.Delete(movieId)
    registry.Flush()
end sub

sub showSeekBar(stateText as String)
    m.seekBarVisible = true
    m.seekBarGroup.visible = true
    m.stateLabel.text = stateText
    m.hideTimer.control = "stop"
    updateSeekBar()
end sub

sub startHideTimer()
    m.hideTimer.control = "stop"
    m.hideTimer.control = "start"
end sub

sub onHideTimer()
    m.seekBarVisible = false
    m.seekBarGroup.visible = false
end sub

sub updateSeekBar()
    position = m.videoNode.position
    duration = m.videoNode.duration

    m.currentTimeLabel.text = formatTime(position)
    m.durationLabel.text = formatTime(duration)

    if duration > 0
        progress = position / duration
        barWidth = Int(m.trackWidth * progress)
        if barWidth < 0 then barWidth = 0
        if barWidth > m.trackWidth then barWidth = m.trackWidth
        m.seekTrackProgress.width = barWidth
    end if
end sub

function formatTime(seconds as Dynamic) as String
    if seconds = invalid or seconds <= 0 then return "0:00"
    totalSecs = Int(seconds)
    hrs = totalSecs \ 3600
    mins = (totalSecs mod 3600) \ 60
    secs = totalSecs mod 60

    if hrs > 0
        return hrs.toStr() + ":" + zeroPad(mins) + ":" + zeroPad(secs)
    else
        return mins.toStr() + ":" + zeroPad(secs)
    end if
end function

function zeroPad(n as Integer) as String
    if n < 10
        return "0" + n.toStr()
    end if
    return n.toStr()
end function

sub showError(message as String)
    m.errorLabel.text = message
    m.errorLabel.visible = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back"
        savePosition()
        m.saveTimer.control = "stop"
        m.videoNode.control = "stop"
        m.top.playbackDone = true
        return true
    else if key = "OK" or key = "play"
        if m.videoNode.state = "playing"
            m.videoNode.control = "pause"
        else if m.videoNode.state = "paused"
            m.videoNode.control = "resume"
        end if
        return true
    else if key = "fastforward"
        seekTo = m.videoNode.position + 300
        m.videoNode.seek = seekTo
        showSeekBar(">> +5min")
        startHideTimer()
        return true
    else if key = "rewind"
        seekTo = m.videoNode.position - 300
        if seekTo < 0 then seekTo = 0
        m.videoNode.seek = seekTo
        showSeekBar("<< -5min")
        startHideTimer()
        return true
    else if key = "right"
        seekTo = m.videoNode.position + 30
        m.videoNode.seek = seekTo
        showSeekBar("> +30s")
        startHideTimer()
        return true
    else if key = "left"
        seekTo = m.videoNode.position - 15
        if seekTo < 0 then seekTo = 0
        m.videoNode.seek = seekTo
        showSeekBar("< -15s")
        startHideTimer()
        return true
    end if
    return false
end function
