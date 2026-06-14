sub init()
    m.languageGrid = m.top.findNode("languageGrid")

    m.languageGrid.observeField("itemSelected", "onLanguageItemSelected")
    m.top.observeField("focusedChild", "onFocusChanged")

    populateLanguages()
    m.languageGrid.setFocus(true)
end sub

sub onFocusChanged()
    if m.top.isInFocusChain() and not m.languageGrid.hasFocus()
        m.languageGrid.setFocus(true)
    end if
end sub

sub populateLanguages()
    languages = [
        { name: "Hindi", code: "hindi" },
        { name: "Tamil", code: "tamil" },
        { name: "Telugu", code: "telugu" },
        { name: "Malayalam", code: "malayalam" },
        { name: "Kannada", code: "kannada" },
        { name: "Bengali", code: "bengali" },
        { name: "Marathi", code: "marathi" },
        { name: "Punjabi", code: "punjabi" }
    ]

    content = CreateObject("roSGNode", "ContentNode")
    for each lang in languages
        item = content.createChild("ContentNode")
        item.title = lang.name
        item.description = lang.code
        item.HDPosterUrl = "pkg:/images/languages/" + lang.code + ".png"
    end for

    m.languageGrid.content = content
end sub

sub onLanguageItemSelected()
    index = m.languageGrid.itemSelected
    content = m.languageGrid.content
    if content <> invalid and index >= 0 and index < content.getChildCount()
        item = content.getChild(index)
        m.top.selectedLanguage = item.description
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    return false
end function
