sub init()
    m.posterGrid = m.top.findNode("posterGrid")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.titleLabel = m.top.findNode("titleLabel")

    m.posterGrid.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onFocusChanged()
    if m.top.isInFocusChain() and not m.posterGrid.hasFocus()
        m.posterGrid.setFocus(true)
    end if
end sub

sub onLanguageChanged()
    lang = m.top.language
    if lang = "" then return

    langTitle = UCase(Left(lang, 1)) + Mid(lang, 2)
    m.titleLabel.text = langTitle + " Movies"

    m.loadingLabel.text = "Loading movies..."
    m.loadingLabel.visible = true
    m.posterGrid.visible = false

    task = CreateObject("roSGNode", "HttpTask")
    task.observeField("response", "onCatalogResponse")
    task.request = {
        url: m.top.serverUrl + "/catalog/" + lang,
        method: "GET",
        token: m.top.sessionToken
    }
    task.control = "run"
end sub

sub onCatalogResponse(event as Object)
    result = event.getData()
    m.loadingLabel.visible = false

    if result.code <> 200
        m.loadingLabel.text = "Failed to load movies"
        m.loadingLabel.visible = true
        return
    end if

    parsed = ParseJson(result.body)
    if parsed = invalid or parsed.movies = invalid or parsed.movies.count() = 0
        m.loadingLabel.text = "No movies found"
        m.loadingLabel.visible = true
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    for each movie in parsed.movies
        item = content.createChild("ContentNode")
        item.title = movie.title
        item.HDPosterUrl = movie.poster
        item.SDPosterUrl = movie.poster
        item.description = movie.id
        if movie.year <> invalid
            item.shortDescriptionLine1 = movie.year
        end if
    end for

    m.posterGrid.content = content
    m.posterGrid.visible = true
    m.posterGrid.setFocus(true)
end sub

sub onItemSelected()
    index = m.posterGrid.itemSelected
    content = m.posterGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        m.top.movieSelected = item.description
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
