(() => {
  "use strict";
  const nav = document.getElementById("nav");
  const toggle = document.getElementById("nav-toggle");
  const links = document.getElementById("nav-links");
  const main = document.querySelector("main, .legal-page");
  const footer = document.querySelector("footer");
  const mobile = window.matchMedia("(max-width: 760px)");
  if (!nav || !toggle || !links) return;
  toggle.setAttribute("aria-controls", links.id);
  toggle.setAttribute("aria-expanded", "false");
  function setMenu(open, restoreFocus = false) {
    links.classList.toggle("open", open);
    toggle.classList.toggle("active", open);
    document.body.classList.toggle("menu-open", open);
    document.body.style.overflow = open ? "hidden" : "";
    toggle.setAttribute("aria-expanded", String(open));
    toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    if (main) main.inert = open;
    if (footer) footer.inert = open;
    if (open) links.querySelector("a")?.focus();
    else if (restoreFocus) toggle.focus();
  }
  toggle.addEventListener("click", () =>
    setMenu(toggle.getAttribute("aria-expanded") !== "true"),
  );
  nav.addEventListener("click", (event) => {
    if (event.target.closest("a")) setMenu(false);
  });
  window.closeMenu = () => setMenu(false);
  document.addEventListener("keydown", (event) => {
    if (toggle.getAttribute("aria-expanded") !== "true") return;
    if (event.key === "Escape") {
      event.preventDefault();
      setMenu(false, true);
    }
    if (event.key === "Tab") {
      const focusable = [...nav.querySelectorAll("a,button")].filter(
        (el) => el.getClientRects().length && getComputedStyle(el).visibility !== "hidden",
      );
      const current = focusable.indexOf(document.activeElement);
      const next = current < 0 ? 0 :
        (current + (event.shiftKey ? -1 : 1) + focusable.length) % focusable.length;
      event.preventDefault();
      focusable[next]?.focus();
    }
  });
  mobile.addEventListener("change", () => {
    if (!mobile.matches) setMenu(false);
  });
  const updateNav = () =>
    nav.classList.toggle(
      "scrolled",
      document.body.classList.contains("legal-body") || window.scrollY > 48,
    );
  window.addEventListener("scroll", updateNav, { passive: true });
  updateNav();
  // Keep ordinary navigation visible if this script cannot initialize.
  nav.classList.add("menu-ready");
})();
