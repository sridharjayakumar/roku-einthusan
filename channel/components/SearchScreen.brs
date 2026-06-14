sub init()
    m.searchKeyboard = m.top.findNode("searchKeyboard")
    m.searchButton = m.top.findNode("searchButton")
    m.clearButton = m.top.findNode("clearButton")
    m.resultsGrid = m.top.findNode("resultsGrid")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.noResultsLabel = m.top.findNode("noResultsLabel")
    m.titleLabel = m.top.findNode("titleLabel")

    m.continueGroup = m.top.findNode("continueGroup")
    m.continueGrid = m.top.findNode("continueGrid")

    m.searchButton.observeField("buttonSelected", "onSearchPressed")
    m.clearButton.observeField("buttonSelected", "onClearPressed")
    m.continueGrid.observeField("itemSelected", "onContinueSelected")
    m.resultsGrid.observeField("itemSelected", "onResultSelected")
    m.top.observeField("focusedChild", "onFocusChanged")

    m.currentLang = "tamil"
    m.lastQuery = ""
    m.searchKeyboard.setFocus(true)
end sub

sub onFocusChanged()
    if m.top.isInFocusChain() and not m.searchKeyboard.hasFocus() and not m.searchButton.hasFocus() and not m.clearButton.hasFocus() and not m.resultsGrid.hasFocus() and not m.continueGrid.hasFocus()
        m.searchKeyboard.setFocus(true)
    end if
end sub

sub onLangSet()
    lang = m.top.selectedLang
    if lang <> ""
        m.currentLang = lang
        langTitle = UCase(Left(lang, 1)) + Mid(lang, 2)
        m.titleLabel.text = langTitle + " - Search"
        m.searchKeyboard.text = ""
        m.resultsGrid.visible = false
        m.resultsGrid.content = invalid
        m.noResultsLabel.visible = false
        m.loadingLabel.visible = false
        loadContinueWatching()
    end if
end sub

sub loadContinueWatching()
    playbackReg = CreateObject("roRegistrySection", "playback")
    watchReg = CreateObject("roRegistrySection", "watching")
    keys = playbackReg.GetKeyList()
    content = CreateObject("roSGNode", "ContentNode")

    for each movieId in keys
        position = Val(playbackReg.Read(movieId))
        if position > 30
            langKey = movieId + "_lang"
            if watchReg.Exists(langKey)
                lang = watchReg.Read(langKey)
                if lang = m.currentLang
                    movieTitle = ""
                    moviePoster = ""
                    if watchReg.Exists(movieId + "_title")
                        movieTitle = watchReg.Read(movieId + "_title")
                    end if
                    if watchReg.Exists(movieId + "_poster")
                        moviePoster = watchReg.Read(movieId + "_poster")
                    end if
                    item = content.createChild("ContentNode")
                    item.title = movieTitle
                    item.HDPosterUrl = moviePoster
                    item.description = movieId
                end if
            end if
        end if
    end for


    if content.getChildCount() > 0
        m.continueGrid.content = content
        m.continueGroup.visible = true
    else
        m.continueGroup.visible = false
    end if
end sub

sub onContinueSelected()
    index = m.continueGrid.itemSelected
    content = m.continueGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        m.top.movieSelected = item.description
    end if
end sub

sub onClearPressed()
    m.searchKeyboard.text = ""
    m.resultsGrid.visible = false
    m.noResultsLabel.visible = false
    m.loadingLabel.visible = false
    loadContinueWatching()
    m.searchKeyboard.setFocus(true)
end sub

sub onSearchPressed()
    query = m.searchKeyboard.text
    if query = ""
        m.resultsGrid.visible = false
        m.noResultsLabel.visible = false
        loadContinueWatching()
        return
    end if

    m.lastQuery = query
    m.loadingLabel.visible = true
    m.noResultsLabel.visible = false
    m.resultsGrid.visible = false
    m.continueGroup.visible = false

    url = m.top.serverUrl + "/search?lang=" + m.currentLang + "&q=" + query.encodeUri()

    task = CreateObject("roSGNode", "HttpTask")
    task.observeField("response", "onSearchResponse")
    task.request = {
        url: url,
        method: "GET",
        token: m.top.sessionToken
    }
    task.control = "run"
end sub

sub onSearchResponse(event as Object)
    result = event.getData()
    m.loadingLabel.visible = false

    if result.code <> 200
        m.noResultsLabel.text = "No results found"
        m.noResultsLabel.visible = true
        loadContinueWatching()
        return
    end if

    parsed = ParseJson(result.body)
    if parsed = invalid or parsed.movies = invalid or parsed.movies.count() = 0
        m.noResultsLabel.text = "No results found"
        m.noResultsLabel.visible = true
        loadContinueWatching()
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    for each movie in parsed.movies
        item = content.createChild("ContentNode")
        item.title = movie.title
        item.HDPosterUrl = movie.poster
        item.description = movie.id
        if movie.year <> invalid
            item.shortDescriptionLine1 = movie.year
        end if
    end for

    m.resultsGrid.content = content
    m.resultsGrid.visible = true
end sub

sub onResultSelected()
    index = m.resultsGrid.itemSelected
    content = m.resultsGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        m.top.movieSelected = item.description
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "play"
        onSearchPressed()
        return true
    else if key = "right"
        if m.searchButton.hasFocus()
            m.clearButton.setFocus(true)
            return true
        end if
    else if key = "left"
        if m.clearButton.hasFocus()
            m.searchButton.setFocus(true)
            return true
        end if
    else if key = "down"
        if m.searchKeyboard.isInFocusChain()
            m.searchButton.setFocus(true)
            return true
        else if m.searchButton.hasFocus() or m.clearButton.hasFocus()
            if m.resultsGrid.visible
                m.resultsGrid.setFocus(true)
                return true
            else if m.continueGroup.visible
                m.continueGrid.setFocus(true)
                return true
            end if
        end if
    else if key = "up"
        if m.continueGrid.hasFocus()
            m.searchButton.setFocus(true)
            return true
        else if m.resultsGrid.hasFocus()
            m.searchButton.setFocus(true)
            return true
        else if m.searchButton.hasFocus() or m.clearButton.hasFocus()
            m.searchKeyboard.setFocus(true)
            return true
        end if
    end if

    return false
end function
