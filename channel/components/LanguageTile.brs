sub init()
    m.tileLabel = m.top.findNode("tileLabel")
    m.tileBg = m.top.findNode("tileBg")
    m.tileImage = m.top.findNode("tileImage")
    m.tileOverlay = m.top.findNode("tileOverlay")
end sub

sub onContentChanged()
    content = m.top.itemContent
    if content <> invalid
        m.tileLabel.text = content.title
        if content.HDPosterUrl <> invalid and content.HDPosterUrl <> ""
            m.tileImage.uri = content.HDPosterUrl
        end if
    end if
end sub

sub onFocusChanged()
    if m.top.itemHasFocus
        m.tileLabel.color = "#FFFFFF"
        m.tileOverlay.opacity = 0.0
    else
        m.tileLabel.color = "#849495"
        m.tileOverlay.opacity = 0.3
    end if
end sub
