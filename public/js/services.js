angular.module('services', [])

.service('recipes', function($http) {
  var self = {};

  var result;

  self.get = _.memoize(function() {
    return $http.post('/admin/recipes.json').then(function(response) {
      return response.data;
    });
  });

  return self;
})