// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/trays_social"
import topbar from "../vendor/topbar"

const LazyLoad = {
  mounted() {
    const loadImage = (img) => {
      const src = img.dataset.src
      if (src) {
        img.onload = () => img.classList.add("lazy-loaded")
        img.onerror = () => img.classList.add("lazy-loaded")
        img.src = src
        img.removeAttribute("data-src")
      }
    }

    const rect = this.el.getBoundingClientRect()
    const isInViewport = rect.top < window.innerHeight + 100 && rect.bottom > -100

    if (isInViewport) {
      loadImage(this.el)
      return
    }

    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          loadImage(entry.target)
          observer.unobserve(entry.target)
        }
      })
    }, { rootMargin: "100px" })

    observer.observe(this.el)
    this.observer = observer
  },
  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

const InfiniteScroll = {
  mounted() {
    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.pushEvent("load-more", {})
        }
      })
    }, { rootMargin: "200px" })

    this.observer.observe(this.el)
  },
  destroyed() {
    if (this.observer) this.observer.disconnect()
  }
}

// CookTimer — reads `data-started-at` (ISO 8601 UTC) from the host element
// and updates its textContent every second with elapsed `mm:ss` (or `h:mm:ss`
// past an hour). Ticks client-side so the server isn't pinged every second.
// When the attribute disappears (cook stops the timer), the interval is
// cleared.
const CookTimer = {
  mounted() {
    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  },
  updated() {
    this.tick()
  },
  destroyed() {
    if (this.interval) clearInterval(this.interval)
  },
  tick() {
    const startedAt = this.el.dataset.startedAt
    if (!startedAt) {
      if (this.interval) clearInterval(this.interval)
      this.interval = null
      return
    }

    const start = new Date(startedAt).getTime()
    if (isNaN(start)) return

    const elapsed = Math.max(0, Math.floor((Date.now() - start) / 1000))
    const h = Math.floor(elapsed / 3600)
    const m = Math.floor((elapsed % 3600) / 60)
    const s = elapsed % 60
    const pad = (n) => n.toString().padStart(2, "0")

    this.el.textContent = h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`
  }
}

// AdSlot — sponsored-slot loader for the public recipe pages (W159). The
// server renders the slot with first-party house copy; this hook only
// requests a third-party network script when the server handed it a
// data-script-url (nil config = no attribute = no-op). Consent guards run
// before any request: the Global Privacy Control browser signal and the
// first-party opt-out (cookie set at /privacy/ads-choices, or the
// localStorage mirror) both short-circuit. The script is requested at most
// once per page no matter how many slots render.
// NOTE: the router's @csp_header intentionally still blocks all third-party
// script origins — until a follow-up amends the CSP for a vetted network,
// the injection below is additionally a no-op at the browser level.
// Defense in depth: nil config, consent guards, AND CSP.
const AdSlot = {
  mounted() {
    const url = this.el.dataset.scriptUrl
    if (!url) return
    if (navigator.globalPrivacyControl) return
    if (
      document.cookie.split("; ").includes("trays_ads_opt_out=1") ||
      localStorage.getItem("trays:ads-opt-out") === "1"
    ) return
    if (window.__traysAdScriptRequested) return
    window.__traysAdScriptRequested = true

    const script = document.createElement("script")
    script.async = true
    script.src = url
    const siteId = this.el.dataset.siteId
    if (siteId) script.dataset.siteId = siteId
    document.head.appendChild(script)
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, LazyLoad, InfiniteScroll, CookTimer, AdSlot},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => {
  topbar.show(300)
  document.querySelector("main")?.classList.add("phx-navigating")
})
window.addEventListener("phx:page-loading-stop", _info => {
  topbar.hide()
  document.querySelector("main")?.classList.remove("phx-navigating")
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

