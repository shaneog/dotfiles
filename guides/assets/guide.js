// Shared behavior for the guides. No dependencies and no build step.
//
// Everything here is an enhancement: with JavaScript off, each page still reads
// top to bottom, every diagram is drawn in its finished state, and the header
// keeps its link back to the first page.

// The one list of pages. The header navigation and the previous/next links at
// the foot of each page are both built from it, so adding a guide is one line.
const PAGES = [
  { file: "index.html", title: "Start here" },
  { file: "install.html", title: "New Mac" },
  { file: "layout.html", title: "Where files live" },
  { file: "shell.html", title: "Opening a terminal" },
  { file: "keys.html", title: "Keys and 1Password" },
  { file: "tools.html", title: "Toolbox" },
  { file: "tests.html", title: "Staying healthy" },
];

const root = document.documentElement;
const here = location.pathname.split("/").pop() || "index.html";
const current = PAGES.findIndex((page) => page.file === here);

function buildNav() {
  const nav = document.querySelector(".site-nav");
  if (!nav) return;
  nav.replaceChildren(
    ...PAGES.map((page, i) => {
      const a = document.createElement("a");
      a.href = page.file;
      a.textContent = page.title;
      if (i === current) a.setAttribute("aria-current", "page");
      return a;
    }),
  );
  nav.querySelector("[aria-current]")?.scrollIntoView({ block: "nearest", inline: "center" });
}

function buildPager() {
  const pager = document.querySelector(".pager");
  if (!pager || current < 0) return;
  const link = (page, cls, label) => {
    const a = document.createElement("a");
    a.href = page.file;
    a.className = cls;
    const small = document.createElement("small");
    small.textContent = label;
    a.append(small, page.title);
    return a;
  };
  if (current > 0) pager.append(link(PAGES[current - 1], "prev", "← Previous"));
  if (current < PAGES.length - 1) pager.append(link(PAGES[current + 1], "next", "Next →"));
}

// Light, dark, or whatever the system says. The choice is remembered when the
// browser allows it, and the page is correct without it.
function setupTheme() {
  const button = document.querySelector("[data-theme-toggle]");
  if (!button) return;
  const systemDark = () => matchMedia("(prefers-color-scheme: dark)").matches;
  const isDark = () => (root.dataset.theme ? root.dataset.theme === "dark" : systemDark());
  button.hidden = false;
  const label = () => {
    button.textContent = isDark() ? "Light" : "Dark";
    button.setAttribute("aria-label", `Switch to the ${isDark() ? "light" : "dark"} theme`);
  };
  button.addEventListener("click", () => {
    root.dataset.theme = isDark() ? "light" : "dark";
    try {
      localStorage.setItem("guides-theme", root.dataset.theme);
    } catch {
      // Private windows and file:// pages may refuse storage.
    }
    label();
  });
  label();
}

// Figures animate when they scroll into view, and again on Replay. Elements
// marked .seq are numbered in document order, which is what staggers them.
function setupFigures() {
  const figures = document.querySelectorAll("[data-animate]");
  for (const figure of figures) {
    figure.querySelectorAll(".seq, .fill").forEach((el, i) => el.style.setProperty("--i", i));
    figure.querySelector("[data-replay]")?.addEventListener("click", () => {
      figure.classList.remove("is-playing");
      // Reading a layout property forces the removal to apply first, so the
      // animations restart instead of being treated as already finished.
      void figure.offsetWidth;
      figure.classList.add("is-playing");
    });
  }
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("is-playing");
        observer.unobserve(entry.target);
      }
    },
    { threshold: 0.25 },
  );
  figures.forEach((figure) => observer.observe(figure));
}

// The step-by-step walkthrough. Its steps are ordinary list items in the page:
// the name in <strong>, the explanation in .explain. This shows one at a time
// in the panel and lights up where it sits in the diagram.
function setupWalks() {
  for (const walk of document.querySelectorAll("[data-walk]")) {
    const steps = [...walk.querySelectorAll("[data-step]")];
    const panel = walk.querySelector("[data-walk-panel]");
    const count = walk.querySelector("[data-walk-count]");
    const play = walk.querySelector("[data-walk-play]");
    if (!steps.length || !panel) continue;
    let index = 0;
    let timer = null;

    const show = (next) => {
      index = (next + steps.length) % steps.length;
      steps.forEach((step, i) => {
        step.classList.toggle("is-active", i === index);
        step.classList.toggle("is-done", i < index);
      });
      const step = steps[index];
      const stage = step.closest(".stage");
      const where = document.createElement("span");
      where.className = "where";
      where.textContent = stage?.dataset.label ?? "";
      const name = document.createElement("strong");
      name.textContent = step.querySelector("strong")?.textContent ?? "";
      const text = document.createElement("p");
      text.innerHTML = step.querySelector(".explain")?.innerHTML ?? "";
      panel.replaceChildren(where, name, text);
      panel.style.setProperty("--tone", stage ? getComputedStyle(stage).getPropertyValue("--tone") : "");
      if (count) count.textContent = `${index + 1} / ${steps.length}`;
    };

    const stop = () => {
      clearInterval(timer);
      timer = null;
      if (play) {
        play.textContent = "Play";
        play.setAttribute("aria-pressed", "false");
      }
    };

    steps.forEach((step, i) => {
      step.tabIndex = 0;
      step.addEventListener("click", () => {
        stop();
        show(i);
      });
      step.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
        stop();
        show(i);
      });
    });
    walk.querySelector("[data-walk-prev]")?.addEventListener("click", () => {
      stop();
      show(index - 1);
    });
    walk.querySelector("[data-walk-next]")?.addEventListener("click", () => {
      stop();
      show(index + 1);
    });
    play?.addEventListener("click", () => {
      if (timer) return stop();
      play.textContent = "Pause";
      play.setAttribute("aria-pressed", "true");
      if (index === steps.length - 1) show(0);
      timer = setInterval(() => {
        if (index === steps.length - 1) return stop();
        show(index + 1);
      }, 3200);
    });
    show(0);
  }
}

function setupCopy() {
  if (!navigator.clipboard) return;
  for (const pre of document.querySelectorAll("pre[data-copy]")) {
    const button = document.createElement("button");
    button.className = "btn copy";
    button.type = "button";
    button.textContent = "Copy";
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(pre.querySelector("code").textContent.trim());
        button.textContent = "Copied";
      } catch {
        button.textContent = "Select and copy";
      }
      setTimeout(() => (button.textContent = "Copy"), 1600);
    });
    pre.append(button);
  }
}

buildNav();
buildPager();
setupTheme();
setupFigures();
setupWalks();
setupCopy();
