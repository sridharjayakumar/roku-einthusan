sub init()
    m.emailKeyboard = m.top.findNode("emailKeyboard")
    m.passwordKeyboard = m.top.findNode("passwordKeyboard")
    m.loginButton = m.top.findNode("loginButton")
    m.errorLabel = m.top.findNode("errorLabel")
    m.loadingLabel = m.top.findNode("loadingLabel")

    m.loginButton.observeField("buttonSelected", "onLoginPressed")
    m.emailKeyboard.setFocus(true)
end sub

sub onLoginPressed()
    email = m.emailKeyboard.text
    password = m.passwordKeyboard.text

    if email = "" or password = ""
        showError("Please enter email and password")
        return
    end if

    m.errorLabel.visible = false
    m.loadingLabel.visible = true

    body = FormatJson({ email: email, password: password })

    task = CreateObject("roSGNode", "HttpTask")
    task.observeField("response", "onLoginResponse")
    task.request = {
        url: "http://192.168.1.15:3000/auth/login",
        method: "POST",
        body: body,
        token: ""
    }
    task.control = "run"
end sub

sub onLoginResponse(event as Object)
    result = event.getData()
    m.loadingLabel.visible = false

    if result.code = 200
        parsed = ParseJson(result.body)
        if parsed <> invalid and parsed.token <> invalid
            m.top.loginResult = parsed
        else
            showError("Invalid response from server")
        end if
    else
        errorMsg = "Login failed"
        parsed = ParseJson(result.body)
        if parsed <> invalid and parsed.error <> invalid
            errorMsg = parsed.error
        end if
        showError(errorMsg)
    end if
end sub

sub showError(message as String)
    m.errorLabel.text = message
    m.errorLabel.visible = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "down"
        if m.emailKeyboard.hasFocus()
            m.passwordKeyboard.setFocus(true)
            return true
        else if m.passwordKeyboard.hasFocus()
            m.loginButton.setFocus(true)
            return true
        end if
    else if key = "up"
        if m.loginButton.hasFocus()
            m.passwordKeyboard.setFocus(true)
            return true
        else if m.passwordKeyboard.hasFocus()
            m.emailKeyboard.setFocus(true)
            return true
        end if
    end if
    return false
end function
