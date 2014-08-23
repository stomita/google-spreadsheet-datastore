#global process 

module.exports = (grunt) ->

  pkg = grunt.file.readJSON("package.json")

  require("load-grunt-tasks")(grunt)

  grunt.initConfig
    pkg: pkg
    watch:
      lib:
        files: ["src/**"]
        tasks: ["build", "test"]

      test:
        files: ["test/**"]
        tasks: ["test"]

    coffee:
      lib:
        files: [
          expand: true
          cwd: "lib/"
          src: ["**/*.coffee"]
          dest: "build/lib"
          ext: ".js"
        ]

      test:
        files: [
          expand: true
          cwd: "test/"
          src: ["**/*.test.coffee"]
          dest: "build/test"
          ext: ".test.js"
        ]

      options:
        sourceMap: true

    copy:
      dist:
        files: [
          expand: true
          cwd: "assets/"
          src: ["vendor/**"]
          dest: "build/assets"
        ,
          expand: true
          cwd: "test/creds"
          src: ["*"]
          dest: "build/test/creds"
        ]

    clean:
      all:
        src: ["build/*"]

  grunt.registerTask "build", ["coffee", "copy"]
  grunt.registerTask "default", ["build"]
