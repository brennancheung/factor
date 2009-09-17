! Copyright (C) 2009 Doug Coleman.
! See http://factorcode.org/license.txt for BSD license.
USING: help.markup help.syntax http.server.filters kernel
multiline furnace.actions furnace.alloy ;
IN: furnace.recaptcha

HELP: <recaptcha>
{ $values
    { "responder" "a responder" }
    { "obj" object }
}
{ $description "A " { $link filter-responder } " wrapping another responder. Set the domain, public, and private keys using the key you get by registering with Recaptcha." } ;

HELP: recaptcha-error
{ $var-description "Set to the error string returned by the Recaptcha server." } ;

HELP: recaptcha-valid?
{ $var-description "Set to " { $link t } " if the user solved the last Recaptcha correctly." } ;

HELP: validate-recaptcha
{ $description "Validates a Recaptcha using the Recaptcha web service API." } ;

ARTICLE: "recaptcha-example" "Recaptcha example"
"There are several steps to using the Recaptcha library."
{ $list
    { "Wrap the responder in a " { $link <recaptcha> } }
    { "Add a handler calling " { $link validate-recaptcha } " in the " { $slot "submit" } " of the " { $link page-action } }
    { "Put the chloe tag " { $snippet "<recaptcha/>" } " in the template for your " { $link action } }
}
"An example follows:"
{ $code
HEREDOC: RECAPTCHA-TUTORIAL
USING: db.sqlite kernel http.server.dispatchers db.sqlite
furnace.actions furnace.recaptcha furnace.conversations
furnace.redirection xml.syntax html.templates.chloe.compiler
io.streams.string http.server.responses furnace.alloy http.server ;
TUPLE: recaptcha-app < dispatcher recaptcha ;

: recaptcha-db ( -- obj )
    "recaptcha-example" <sqlite-db> ;

: <recaptcha-challenge> ( -- obj )
    <action>
        [
            begin-conversation
            validate-recaptcha
            recaptcha-valid? cget "?good" "?bad" ? >url <continue-conversation>
        ] >>submit
        [
            <XML <t:chloe xmlns:t="http://factorcode.org/chloe/1.0">
            <html><body><form submit="" method="post"><t:recaptcha/></form></body></html>
            </t:chloe> XML>
            compile-template [ call( -- ) ] with-string-writer "text/html" <content>
        ] >>display ;

: <recaptcha-app> ( -- obj )
    \ recaptcha-app new-dispatcher
        <recaptcha-challenge> "" add-responder
        <recaptcha>
        "concatenative.org" >>domain
        "6LeJWQgAAAAAAFlYV7SuBClE9uSpGtV_ZS-qVON7" >>public-key
        "6LeJWQgAAAAAALh-XJgSSQ6xKygRgJ8-029Ip2Xv" >>private-key
        recaptcha-db <alloy> ;

<recaptcha-app> main-responder set-global
RECAPTCHA-TUTORIAL
}

;

ARTICLE: "furnace.recaptcha" "Recaptcha"
"The " { $vocab-link "furnace.chloe-tags.recaptcha" } " vocabulary implements support for the Recaptcha. Recaptcha is a web service that provides the user with a captcha, a test that is easy to solve by visual inspection, but hard to solve by writing a computer program. Use a captcha to protect forms from abusive users." $nl

"The recaptcha responder is a " { $link filter-responder } " that wraps another responder. Set the " { $slot "domain" } ", " { $slot "public-key" } ", and " { $slot "private-key" } " slots of this responder to your Recaptcha account information." $nl

"Wrapping a responder with Recaptcha:"
{ $subsection <recaptcha> }
"Validating recaptcha:"
{ $subsection validate-recaptcha }
"Symbols set after validation:"
{ $subsection recaptcha-valid? }
{ $subsection recaptcha-error }
{ $subsection "recaptcha-example" } ;

ABOUT: "furnace.recaptcha"