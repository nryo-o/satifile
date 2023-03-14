import { Elm } from "./elm/Main.elm"

const logo = require("../assets/Logo.png")
const logoRed = require("../assets/LogoRed.png")



import 'webcomponent-qr-code'

const elm = Elm.Main.init({
  flags: {
    apiUrl: process.env.API_URL,
    assets: {
      logo,
      logoRed
    }
  }
})

elm.ports.portSend.subscribe(subscribeHandler)

const toElm = elm.ports.portReceive.send

function subscribeHandler(action: Action): void {
  switch (action.tag) {
    case "copy":
      void navigator.clipboard.writeText(action.text).then(() => toElm({ tag: "copied" }))
      break

    default:
      return
  }

  return
}
