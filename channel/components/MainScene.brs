sub init()
    m.serverUrl = "{{NAS_URL}}"

    m.loginScreen = m.top.findNode("loginScreen")
    m.homeScreen = m.top.findNode("homeScreen")
    m.searchScreen = m.top.findNode("searchScreen")
    m.movieGrid = m.top.findNode("movieGrid")
    m.movieDetail = m.top.findNode("movieDetail")
    m.videoPlayer = m.top.findNode("videoPlayer")

    m.loginScreen.observeField("loginResult", "onLoginResult")
    m.homeScreen.observeField("selectedLanguage", "onLanguageSelected")
    m.searchScreen.observeField("movieSelected", "onMovieSelected")
    m.movieGrid.observeField("movieSelected", "onMovieSelected")
    m.movieDetail.observeField("playRequested", "onPlayRequested")
    m.videoPlayer.observeField("playbackDone", "onPlaybackDone")

    m.sessionToken = ""
    m.screenStack = []

    checkSavedSession()
end sub

sub checkSavedSession()
    ' Proxy auto-authenticates via env vars, so go straight to home.
    ' Login screen is kept as fallback if proxy session expires.
    showScreen("home")
end sub

sub showScreen(screenName as String)
    m.loginScreen.visible = false
    m.homeScreen.visible = false
    m.searchScreen.visible = false
    m.movieGrid.visible = false
    m.movieDetail.visible = false
    m.videoPlayer.visible = false

    if screenName = "login"
        m.loginScreen.visible = true
        m.loginScreen.setFocus(true)
    else if screenName = "home"
        m.homeScreen.visible = true
        m.homeScreen.setFocus(true)
    else if screenName = "search"
        m.searchScreen.visible = true
        m.searchScreen.setFocus(true)
    else if screenName = "movieGrid"
        m.movieGrid.visible = true
        m.movieGrid.setFocus(true)
    else if screenName = "movieDetail"
        m.movieDetail.visible = true
        m.movieDetail.setFocus(true)
    else if screenName = "videoPlayer"
        m.videoPlayer.visible = true
        m.videoPlayer.setFocus(true)
    end if

    m.screenStack.push(screenName)
    m.top.currentScreen = screenName
end sub

sub goBack()
    if m.screenStack.count() > 1
        m.screenStack.pop()
        previousScreen = m.screenStack[m.screenStack.count() - 1]
        m.screenStack.pop()
        showScreen(previousScreen)
    end if
end sub

sub onLoginResult()
    result = m.loginScreen.loginResult
    if result <> invalid and result.token <> invalid
        m.sessionToken = result.token
        registry = CreateObject("roRegistrySection", "auth")
        registry.Write("sessionToken", m.sessionToken)
        registry.Flush()
        showScreen("home")
    end if
end sub

sub onLanguageSelected()
    lang = m.homeScreen.selectedLanguage
    if lang <> ""
        registry = CreateObject("roRegistrySection", "watching")
        registry.Write("current_lang", lang)
        registry.Flush()

        m.searchScreen.serverUrl = m.serverUrl
        m.searchScreen.sessionToken = m.sessionToken
        m.searchScreen.selectedLang = lang
        showScreen("search")
    end if
end sub


sub onMovieSelected()
    movieId = ""
    if m.top.currentScreen = "movieGrid"
        movieId = m.movieGrid.movieSelected
    else if m.top.currentScreen = "search"
        movieId = m.searchScreen.movieSelected
    end if

    if movieId <> ""
        m.movieDetail.serverUrl = m.serverUrl
        m.movieDetail.sessionToken = m.sessionToken
        m.movieDetail.movieId = movieId
        showScreen("movieDetail")
    end if
end sub

sub onPlayRequested()
    movieId = m.movieDetail.playRequested
    if movieId <> ""
        m.videoPlayer.serverUrl = m.serverUrl
        m.videoPlayer.sessionToken = m.sessionToken
        m.videoPlayer.movieId = movieId
        showScreen("videoPlayer")
    end if
end sub

sub onPlaybackDone()
    goBack()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back"
        if m.top.currentScreen <> "home" and m.top.currentScreen <> "login"
            goBack()
            return true
        end if
    end if
    return false
end function
