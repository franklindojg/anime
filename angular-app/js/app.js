(function () {
  'use strict';

  angular
    .module('animeApp', [])
    .controller('AnimeController', AnimeController);

  AnimeController.$inject = ['$http'];

  function AnimeController($http) {
    const vm = this;

    vm.sources = [
      { label: 'Anime populares', path: 'data/anime-populares.json' },
      { label: 'Anime clásicos', path: 'data/anime-clasicos.json' }
    ];

    vm.selectedSource = vm.sources[0].path;
    vm.searchText = '';
    vm.loading = false;
    vm.error = '';
    vm.animeList = [];
    vm.loadAnime = loadAnime;

    loadAnime();

    function loadAnime() {
      vm.loading = true;
      vm.error = '';

      $http
        .get(vm.selectedSource)
        .then(function (response) {
          vm.animeList = response.data;
        })
        .catch(function () {
          vm.error = 'No se pudo cargar el archivo JSON seleccionado.';
          vm.animeList = [];
        })
        .finally(function () {
          vm.loading = false;
        });
    }
  }
})();
