app = angular.module('MyApp',['ui.router','ngProgress'])
fs = require 'fs-extra'
_ = require 'lodash'
okay = require 'okay'
gate = require 'gate'

app.directive 'mycanvas',->
    {
        restrict:'E'
        template:'<canvas width="1280" height="720" ng-click="$state.go(\'noSel\')" id="imgcanvas"></canvas>'
        replace:true
        link:(scope,elem,attrs)->
            drawCanvas = ()->
                ctx = elem[0].getContext('2d')
                fg = new Image()
                bg = new Image()
                bg.src = attrs.bgSrc
                fg.src = attrs.fgSrc
                g = gate.create()
                fg.onload = g.latch()
                bg.onload = g.latch()
                g.await ->
                    ctx.clearRect(0,0,1280,720)
                    ctx.drawImage(bg,0,0)
                    ctx.drawImage(fg,attrs.xpos,-70)

            scope.$watch 'fgimageSrc',->drawCanvas()
            scope.$watch 'bgimageSrc',->drawCanvas()
            scope.$watch 'xpos',_.throttle drawCanvas,500


    }

genFgList = ($q)->
    deferred = $q.defer()
    ok = _.partial okay,(err)->
        deferred.reject err
    fs.readdir 'img/fgimage',ok (files)->
        deferred.notify 25
        g = gate.create()
        for f in files
            fs.stat 'img/fgimage/' + f,g.latch {data:1,name:g.val(f)}
        g.await ok (stats,g)->
            deferred.notify 50
            stats = _.filter stats,(stat)->stat.data.isDirectory()
            for dir in stats
                fs.readdir 'img/fgimage/' + dir.name,g.latch dir.name,1
            g.await ok (files)->
                deferred.notify 75
                files = for k,v of files
                    pics = v.filter (f)->require('path').extname(f) == '.png'
                    continue if pics.length is 0
                    {
                        dir:k
                        pics
                    }
                deferred.resolve files
    return deferred.promise

genBgList = ($q)->
    deferred = $q.defer()
    ok = _.partial okay,(err)->
        deferred.reject err
    fs.readdir 'img/bgimage',ok (files)->
        deferred.resolve files.filter (f)->require('path').extname(f) == '.png'
    return deferred.promise


app.config ($stateProvider,$urlRouterProvider,$compileProvider)->
    $compileProvider.imgSrcSanitizationWhitelist(/^\s*(https?|ftp|mailto|file|app):/) #Bypass security settings
    $stateProvider.state('noSel',{
        template:''
        url:'/index'
    })
    $stateProvider.state('fgDir',{
        url:'/fgdir'
        templateUrl:'partial/fgDir.html'
        controller:($scope,$q,ngProgress,$state,$rootScope)->
            $scope.goToDir = (dir)->
                $rootScope.currDir = dir
                $state.go 'fgImg'
            ngProgress.color('blue')
            genFgList($q)
            .then (dirs)->
                ngProgress.color('green')
                ngProgress.complete()
                $scope.dirs = dirs

            .then null,null,(stat)->
                ngProgress.set stat
            .catch (err)->
                ngProgress.color 'red'
                setTimeout ->
                    alert err.message
                    ngProgress.reset()
                    $state.go 'noSel'
                ,700
    }).state('fgImg',{
        url:'/fgimg'
        templateUrl:'partial/fgImg.html'
        controller:($scope,$rootScope)->
            $scope.setFg = (dir,file)->
                $rootScope.fgimage = {dir:dir,file:file}
                $rootScope.fgimageSrc = 'app://host/img/fgimage/'+dir+'/'+file
    })
    $stateProvider.state('bgImg',{
        url:'/bgimg'
        templateUrl:'partial/bgImg.html'
        controller:($scope,$q,$state,$rootScope)->
            $scope.setBg = (file)->
                $rootScope.bgimage = file
                $rootScope.bgimageSrc = 'app://host/img/bgimage/'+file
            genBgList($q)
            .then (imgs)->
                $scope.imgs = imgs
            .catch (err)->
                setTimeout ->
                    alert err.message
                    $state.go 'noSel'
                ,700

    })

app.run ($rootScope,$state,$stateParams,ngProgress)->
    #Better access in expressions
    $rootScope.$state = $state
    $rootScope.$stateParams = $stateParams
    $rootScope.bgimage = 'img13b.png'
    $rootScope.bgimageSrc = 'app://host/img/bgimage/img13b.png'
    $rootScope.fgimage = {dir:'pab1',file:'2.png'}
    $rootScope.fgimageSrc = 'app://host/img/fgimage/pab1/2.png'
    $rootScope.xpos = 105

    $rootScope.saveImg = ->
        ngProgress.color 'blue'
        ngProgress.start()
        canvas = document.getElementById('imgcanvas')
        buf = new Buffer canvas.toDataURL('image/png').substr('data:image/png;base64,'.length),'base64'
        fname = 'saved/'+$rootScope.bgimage[0...-4] + '+' + $rootScope.fgimage.dir + '-' \
            + $rootScope.fgimage.file[0...-4] + '@' + $rootScope.xpos + '.png'
        try
            fs.writeFileSync fname,buf
            setTimeout ->
                ngProgress.color 'green'
                ngProgress.set(99)
                ngProgress.complete()
            ,500

        catch e
            ngProgress.color 'red'
            setTimeout ->
                alert e.message
                ngProgress.reset()
            ,700
    #Remove select window
    $state.go 'noSel'
    #window.scrollTo(0,31);
