// RFC 4180 CSV: quoted fields may hold commas, newlines and doubled quotes.
function parse(text) {
  const rows = [];
  let row = [], field = "", quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ",") { row.push(field); field = ""; }
    else if (c === "\n") { row.push(field); rows.push(row); row = []; field = ""; }
    else if (c !== "\r") field += c;
  }
  if (field || row.length) { row.push(field); rows.push(row); }
  return rows;
}

let header = [], rows = [];

function render() {
  const grid = document.getElementById("grid");
  const head = "<tr>" + header.map(h => `<th>${escape(h)}</th>`).join("") + "</tr>";
  grid.innerHTML = head + rows.map(r => "<tr>" + r.map(c => `<td>${escape(c)}</td>`).join("") + "</tr>").join("");
}

function escape(s) {
  return s.replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
}

window.ppp = {
  command(id) {
    if (id === "sort") { rows.sort((a, b) => (a[0] ?? "").localeCompare(b[0] ?? "", undefined, { numeric: true })); render(); }
    if (id === "simulate-hang") { for (;;) {} }
  },
};

fetch("/__ppp__/file")
  .then(r => r.text())
  .then(text => {
    [header = [], ...rows] = parse(text);
    render();
    // Force layout so "ready" means laid out, not just parsed. (requestAnimationFrame never fires in occluded windows.)
    void document.body.offsetHeight;
    webkit.messageHandlers.ppp.postMessage({ type: "ready" });
  })
  .catch(e => webkit.messageHandlers.ppp.postMessage({ type: "error", message: String(e) }));
