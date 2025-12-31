/* =====================================================
   UTILIDADES
===================================================== */

function qs(id) {
  return document.getElementById(id);
}

function getParam(name) {
  return new URLSearchParams(window.location.search).get(name);
}

/* =====================================================
   CATÁLOGO BASE
===================================================== */

const ANIMES = [
  {
    id: "blackclover_links",
    title: "Black Clover",
    cover: "img/black.png",
    json: "js/blackclover_links.json"
  },
  {
    id: "dragonBallSuper",
    title: "Dragon Ball Super",
    cover: "img/dragon-ball-super.jpg",
    json: "js/dragonBallSuper.json"
  }
];

/* =====================================================
   INDEX.HTML → CATÁLOGO
===================================================== */

const catalog = qs("catalog");

if (catalog) {
  ANIMES.forEach(anime => {
    const card = document.createElement("div");
    card.className = "card";

    card.innerHTML = `
      <img src="${anime.cover}" loading="lazy">
      <div class="title">${anime.title}</div>
    `;

    card.onclick = () => {
      location.href = `anime.html?id=${anime.id}`;
    };

    catalog.appendChild(card);
  });
}

/* =====================================================
   ANIME.HTML → LISTA DE EPISODIOS
===================================================== */

const animeId = getParam("id");
const episodesContainer = qs("episodes");
const animeTitle = qs("animeTitle");

if (animeId && episodesContainer) {
  const anime = ANIMES.find(a => a.id === animeId);

  if (!anime) {
    if (animeTitle) animeTitle.textContent = "Anime no encontrado";
  } else {
    if (animeTitle) animeTitle.textContent = anime.title;
    loadEpisodes(anime);
  }
}

async function loadEpisodes(anime) {
  try {
    const res = await fetch(anime.json);
    const data = await res.json();

    episodesContainer.innerHTML = "";

    data.forEach(item => {
      if (!item.episode || !item.servers || item.servers.length === 0) return;

      const ep = document.createElement("div");
      ep.className = "episode";
      ep.textContent = "Episodio " + item.episode;

      ep.onclick = () => {
        location.href = `player.html?anime=${anime.id}&ep=${item.episode}`;
      };

      episodesContainer.appendChild(ep);
    });

  } catch (e) {
    console.error(e);
    episodesContainer.innerHTML = "<p>Error cargando episodios</p>";
  }
}

/* =====================================================
   PLAYER.HTML → IFRAME EMBED (SEGURO)
===================================================== */

const iframe = qs("player");
const status = qs("status");

const playerAnime = getParam("anime");
const playerEp = parseInt(getParam("ep"), 10);

if (iframe && playerAnime && playerEp) {
  const anime = ANIMES.find(a => a.id === playerAnime);
  if (anime) {
    loadEpisode(anime, playerEp);
  }
}

async function loadEpisode(anime, epNumber) {
  try {
    if (status) {
      status.textContent = "Cargando episodio " + epNumber + "...";
    }

    const res = await fetch(anime.json);
    const data = await res.json();

    const episode = data.find(e => String(e.episode) === String(epNumber));

    if (!episode || !episode.servers || episode.servers.length === 0) {
      if (status) status.textContent = "Episodio no disponible";
      return;
    }

    let url = episode.servers[0];

    // Corrige URLs sin protocolo (//ok.ru)
    if (url.startsWith("//")) {
      url = "https:" + url;
    }

    iframe.src = url;

    if (status) {
      status.textContent = "Reproduciendo episodio " + epNumber;
    }

  } catch (e) {
    console.error(e);
    if (status) status.textContent = "Error al cargar episodio";
  }
}
