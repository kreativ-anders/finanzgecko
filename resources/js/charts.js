// charts.js — bewusst ohne externe Chart-Library gebaut.
// Grund: die App muss offline funktionieren; ein selbstgeschriebener,
// winziger SVG-Linienchart und ein CSS-Conic-Gradient-Donut brauchen keine
// CDN-Abhängigkeit, die der Service Worker sonst extra cachen müsste.

// points: [{ label: "2025-03", value: number|null }]
// Lücken (value === null) werden als echte Lücke gezeichnet, nicht verbunden.
export function renderLineChart(container, points, { color = "#00c878", height = 140 } = {}) {
  container.innerHTML = "";
  if (!points || points.length === 0) {
    container.innerHTML = `<p class="empty-hint">Noch keine Daten.</p>`;
    return;
  }

  const width = container.clientWidth || 320;
  const padding = 24;
  const values = points.map((p) => p.value).filter((v) => v != null);

  if (values.length === 0) {
    container.innerHTML = `<p class="empty-hint">Noch keine Daten.</p>`;
    return;
  }

  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;

  const stepX = points.length > 1 ? (width - padding * 2) / (points.length - 1) : 0;

  function xAt(i) {
    return padding + i * stepX;
  }
  function yAt(v) {
    return padding + (1 - (v - min) / range) * (height - padding * 2);
  }

  // Segmente bauen: jede Kette aufeinanderfolgender Nicht-Null-Werte wird
  // eine eigene <polyline>, damit Lücken sichtbar bleiben.
  const segments = [];
  let current = [];
  points.forEach((p, i) => {
    if (p.value == null) {
      if (current.length) segments.push(current);
      current = [];
    } else {
      current.push([xAt(i), yAt(p.value)]);
    }
  });
  if (current.length) segments.push(current);

  const svgNS = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(svgNS, "svg");
  svg.setAttribute("viewBox", `0 0 ${width} ${height}`);
  svg.setAttribute("width", "100%");
  svg.setAttribute("height", height);
  svg.classList.add("line-chart");

  // Nulllinie, falls Werte negativ werden können (Kredit-Konten)
  if (min < 0 && max > 0) {
    const zeroY = yAt(0);
    const zeroLine = document.createElementNS(svgNS, "line");
    zeroLine.setAttribute("x1", padding);
    zeroLine.setAttribute("x2", width - padding);
    zeroLine.setAttribute("y1", zeroY);
    zeroLine.setAttribute("y2", zeroY);
    zeroLine.setAttribute("stroke", "#555");
    zeroLine.setAttribute("stroke-dasharray", "4 4");
    svg.appendChild(zeroLine);
  }

  segments.forEach((seg) => {
    const pointsAttr = seg.map(([x, y]) => `${x},${y}`).join(" ");
    const poly = document.createElementNS(svgNS, "polyline");
    poly.setAttribute("points", pointsAttr);
    poly.setAttribute("fill", "none");
    poly.setAttribute("stroke", color);
    poly.setAttribute("stroke-width", "2.5");
    poly.setAttribute("stroke-linecap", "round");
    poly.setAttribute("stroke-linejoin", "round");
    svg.appendChild(poly);

    seg.forEach(([x, y]) => {
      const dot = document.createElementNS(svgNS, "circle");
      dot.setAttribute("cx", x);
      dot.setAttribute("cy", y);
      dot.setAttribute("r", "3");
      dot.setAttribute("fill", color);
      svg.appendChild(dot);
    });
  });

  container.appendChild(svg);

  // dezente Achsenbeschriftung: erster / letzter Monat
  const labels = document.createElement("div");
  labels.className = "chart-labels";
  labels.innerHTML = `<span>${points[0].label}</span><span>${points[points.length - 1].label}</span>`;
  container.appendChild(labels);
}

// segments: [{ label, value, color }]
export function renderDonut(container, segments) {
  container.innerHTML = "";
  const total = segments.reduce((sum, s) => sum + Math.max(s.value, 0), 0);

  if (total <= 0) {
    container.innerHTML = `<p class="empty-hint">Noch keine Daten.</p>`;
    return;
  }

  let acc = 0;
  const stops = segments
    .filter((s) => s.value > 0)
    .map((s) => {
      const start = (acc / total) * 360;
      acc += s.value;
      const end = (acc / total) * 360;
      return `${s.color} ${start}deg ${end}deg`;
    })
    .join(", ");

  const wrap = document.createElement("div");
  wrap.className = "donut-wrap";

  const donut = document.createElement("div");
  donut.className = "donut";
  donut.style.background = `conic-gradient(${stops})`;
  wrap.appendChild(donut);

  const legend = document.createElement("ul");
  legend.className = "donut-legend";
  segments
    .filter((s) => s.value > 0)
    .forEach((s) => {
      const pct = ((s.value / total) * 100).toFixed(1);
      const li = document.createElement("li");
      li.innerHTML = `<span class="dot" style="background:${s.color}"></span> ${s.label} — ${pct}%`;
      legend.appendChild(li);
    });
  wrap.appendChild(legend);

  container.appendChild(wrap);
}
