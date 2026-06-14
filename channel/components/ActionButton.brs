sub init()
    m.buttonBg = m.top.findNode("buttonBg")
    m.buttonLabel = m.top.findNode("buttonLabel")
    m.top.observeField("focusedChild", "onFocusChanged")
end sub

sub onTextChanged()
    m.buttonLabel.text = m.top.text
end sub

sub onFocusChanged()
    if m.top.hasFocus()
        m.buttonBg.color = "#00F5FF"
        m.buttonLabel.color = "#003739"
    else
        m.buttonBg.color = "#282A2D"
        m.buttonLabel.color = "#B9CACA"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "OK"
        m.top.buttonSelected = m.top.buttonSelected + 1
        return true
    end if
    return false
end function
