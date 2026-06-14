sub init()
    m.posterImage = m.top.findNode("posterImage")
    m.titleLabel = m.top.findNode("titleLabel")
end sub

sub onContentChanged()
    content = m.top.itemContent
    if content <> invalid
        m.posterImage.uri = content.HDPosterUrl
        m.titleLabel.text = content.title
    end if
end sub
