/* =====================================================
   UTILIDADES GLOBALES
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
    cover: "img/dragon-ball-super.png",
    json: "js/dragonBallSuper.json"
  }
];
