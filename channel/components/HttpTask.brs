sub init()
    m.top.functionName = "executeRequest"
end sub

sub executeRequest()
    req = m.top.request
    if req = invalid then return

    url = req.url
    method = req.method
    if method = invalid then method = "GET"
    body = req.body
    token = req.token

    transfer = CreateObject("roUrlTransfer")
    transfer.setUrl(url)
    transfer.setCertificatesFile("common:/certs/ca-bundle.crt")
    transfer.initClientCertificates()

    port = CreateObject("roMessagePort")
    transfer.setMessagePort(port)

    if token <> invalid and token <> ""
        transfer.addHeader("x-session-token", token)
    end if

    if method = "POST"
        transfer.addHeader("Content-Type", "application/json")
        transfer.asyncPostFromString(body)
    else
        transfer.asyncGetToString()
    end if

    msg = wait(30000, port)

    result = { code: -1, body: "" }
    if msg <> invalid
        result.code = msg.getResponseCode()
        result.body = msg.getString()
    end if

    m.top.response = result
end sub
