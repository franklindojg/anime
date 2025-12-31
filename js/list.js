document.addEventListener("DOMContentLoaded", () => {

  /* ===============================
     CATÁLOGO (index.html)
  =============================== */

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

  /* ===============================
     ANIME.HTML → EPISODIOS
  =============================== */

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

});
