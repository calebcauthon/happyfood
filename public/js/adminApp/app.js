angular.module('adminApp', ['services', 'ui.bootstrap', 'ui.router', 'lr.upload'])

.config(function($stateProvider, $urlRouterProvider) {

  $urlRouterProvider.otherwise("/recipes");

  $stateProvider
    .state('recipes', {
      url: "/recipes",
      templateUrl: "js/adminApp/partials/recipes.html",
      controller: 'recipesAdminCtrl',
      controllerAs: 'ctrl'
    })

    .state('edit-recipe', {
      url: "/edit-recipe",
      templateUrl: "js/adminApp/partials/edit-recipe.html",
      controller: 'editRecipeAdminCtrl',
      controllerAs: 'ctrl',
      params: { recipe: null }
    })

    .state('add-recipe', {
      url: "/add-recipe",
      templateUrl: "js/adminApp/partials/edit-recipe.html",
      controller: 'addRecipeAdminCtrl',
      controllerAs: 'ctrl'
    })
})

.controller('addRecipeAdminCtrl', function($scope, $http, $location, upload) {
  var ctrl = this;

  ctrl.serving_options = [];

  ctrl.remove = function(option) {
    option.removed = true;
  };

  ctrl.add_serving_option = function(servings, dollars) {
    ctrl.serving_options.push({
      servings: servings,
      dollars: dollars
    });
  };

  ctrl.uploading = false;
  ctrl.uploadFile = function () {
    ctrl.uploading = true;
    upload({
      url: '/admin/add-recipe-image',
      method: 'POST',
      data: {
        image: angular.element(document.getElementById('recipe-image'))
      }
    }).then(function (response) {
      return response.data.url;
    }).then(function(url) {
      ctrl.recipe_image_url = url;
      ctrl.uploading = false;
    });
  };

  ctrl.save = function(name, url, serving_options) {
    $http.post('/admin/add-recipe', {
      name: name,
      url: url,
      serving_options: serving_options
    }).then(function() {
      $state.go('recipes');
    });
  };
})

.controller('editRecipeAdminCtrl', function($scope, $http, $location, upload, $state, $stateParams) {
  var ctrl = this;

  var recipe = $stateParams.recipe;

  ctrl.recipe_name = recipe.name;
  ctrl.serving_options = recipe.serving_options;
  ctrl.recipe_image_url = recipe.image_url;
  ctrl.recipe_id = recipe._id.$oid;

  ctrl.remove = function(option) {
    option.removed = true;
  };

  ctrl.add_serving_option = function(servings, dollars) {
    ctrl.serving_options.push({
      servings: servings,
      dollars: dollars
    });
  };

  ctrl.uploading = false;
  ctrl.uploadFile = function () {
    ctrl.uploading = true;
    upload({
      url: '/admin/add-recipe-image',
      method: 'POST',
      data: {
        image: angular.element(document.getElementById('recipe-image'))
      }
    }).then(function (response) {
      return response.data.url;
    }).then(function(url) {
      ctrl.recipe_image_url = url;
      ctrl.uploading = false;
    });
  };

  ctrl.save = function(name, url, serving_options) {
    $http.post('/admin/update-recipe', {
      recipe_id: recipe._id.$oid,
      name: name,
      url: url,
      serving_options: serving_options
    }).then(function() {
      $state.go('recipes');
    });
  };
})

.controller('recipesAdminCtrl', function($http, $uibModal, $log, $state, recipes) {
  var ctrl = this;

  ctrl.confirmRemoval = function(recipe) {
    var modalInstance = $uibModal.open({
      templateUrl: 'confirmRemoval.html',
      controller: function($scope, $uibModalInstance, recipe) {
        $scope.recipe = recipe;

        $scope.ok = function() {
          $uibModalInstance.close(recipe);
        };

        $scope.cancel = function() {
          $uibModalInstance.dismiss();
        };
      },
      size: 'sm',
      resolve: {
        recipe: function () {
          return recipe;
        }
      }
    });

    modalInstance.result.then(function (result) {
      $http.post('/admin/remove-recipe', { recipe_id: recipe._id.$oid }).then(function() {
        getRecipes();
      });
    }, function () {
      $log.info('Modal dismissed at: ' + new Date());
    });
  };

  ctrl.edit = function(recipe) {
    $state.go('edit-recipe', { recipe: recipe });
  };

  function getRecipes() {
    recipes.get().then(function(all_recipes) {
      ctrl.recipes = all_recipes;
    });
  }

  getRecipes();
})