/* =====================================================
   PLAYER – IFRAME UNIVERSAL (MEGA + OK + DRIVE)
   ✔ MEGA embed (/file, #!, /embed)
   ✔ JSON mixto (string / object)
   ✔ Fullscreen real
   ✔ Oculta StatusBar Android
===================================================== */

const iframe = qs("player");
const status = qs("status");

const playerAnime = getParam("anime");
const playerEp = parseInt(getParam("ep"), 10);

/* =====================================================
   ANDROID: OCULTAR BARRA SUPERIOR
===================================================== */

if (window.Capacitor?.Plugins?.StatusBar) {
  Capacitor.Plugins.StatusBar.hide();
}

/* =====================================================
   INICIO
===================================================== */

if (iframe && playerAnime && playerEp) {
  const anime = ANIMES.find(a => a.id === playerAnime);
  if (anime) {
    loadEpisode(anime, playerEp);
  }
}

/* =====================================================
   CARGA DE EPISODIO
===================================================== */

async function loadEpisode(anime, epNumber) {
  try {
    if (status) status.textContent = "Cargando episodio " + epNumber + "...";

    const res = await fetch(anime.json);
    const data = await res.json();

    const episode = data.find(e => String(e.episode) === String(epNumber));
    if (!episode || !episode.servers || episode.servers.length === 0) {
      if (status) status.textContent = "Episodio no disponible";
      return;
    }

    // 👉 Soporte servers como string u objeto
    let raw = episode.servers[0];
    let url = typeof raw === "string" ? raw : raw.url;

    if (!url) {
      if (status) status.textContent = "Servidor inválido";
      return;
    }

    url = normalizeUrl(url);
    iframe.src = url;

    if (status) {
      status.textContent = `Reproduciendo episodio ${epNumber}`;
    }

  } catch (e) {
    console.error(e);
    if (status) status.textContent = "Error al cargar episodio";
  }
}

/* =====================================================
   NORMALIZACIÓN DE URLS
===================================================== */

function normalizeUrl(url) {
  if (typeof url !== "string") return url;

  // //ok.ru → https
  if (url.startsWith("//")) {
    url = "https:" + url;
  }

  // MEGA → embed
  return megaToEmbed(url);
}

/* =====================================================
   MEGA → EMBED (TODOS LOS FORMATOS)
===================================================== */

function megaToEmbed(url) {
  // Ya es embed
  if (url.includes("mega.nz/embed/")) return url;

  // https://mega.nz/file/ID#KEY
  if (url.includes("mega.nz/file/")) {
    const [base, key] = url.split("#");
    const id = base.split("/file/")[1];
    return `https://mega.nz/embed/${id}#${key}`;
  }

  // https://mega.nz/#!ID!KEY
  if (url.includes("mega.nz/#!")) {
    const [id, key] = url.split("#!")[1].split("!");
    return `https://mega.nz/embed/${id}#${key}`;
  }

  return url;
}

/* =====================================================
   AL SALIR → MOSTRAR BARRA ANDROID
===================================================== */

window.addEventListener("beforeunload", () => {
  if (window.Capacitor?.Plugins?.StatusBar) {
    Capacitor.Plugins.StatusBar.show();
  }
});
