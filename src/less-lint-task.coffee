{CSSLint} = require 'csslint'
{Parser} = require 'less'
_ = require 'underscore'
{findLessLineNumber, findPropertyLineNumber, getPropertyName} = require './linter'

defaultLessOptions =
  compress: false
  dumpLineNumbers: 'comments'
  optimization: null
  yuicompress: false

module.exports = (grunt) ->
  grunt.registerMultiTask 'lesslint', 'Validate LESS files with CSS Lint', ->
    configLessOptions = @options.less ? grunt.config.get('less.options')
    lessOptions = grunt.util._.extend({}, configLessOptions, defaultLessOptions)
    parser = new Parser(lessOptions)

    fileCount = 0
    errorCount = 0

    rules = {}
    CSSLint.getRules().forEach ({id}) -> rules[id] = 1

    cssLintOptions = @options.csslint ? grunt.config.get('csslint.options')
    for id, enabled of cssLintOptions
      if cssLintOptions[id]
        rules[id] = cssLintOptions[id]
      else
        delete rules[id]

    @filesSrc.forEach (file) ->
      grunt.verbose.write("Linting '#{file}'")
      fileCount++

      less = grunt.file.read(file)
      parser.parse less, (error, tree) ->
        if error?
          errorCount++
          grunt.log.writeln("Error parsing #{file.yellow}")
          grunt.log.writeln(error.message)
        else
          css = tree.toCSS()
          results = CSSLint.verify(css, rules)
          return unless results.messages?.length > 0

          grunt.log.writeln("#{file.yellow} (#{results.messages.length})")

          lessLines = less.split('\n')
          cssLines = css.split('\n')

          messages = _.groupBy results.messages, (message) -> message.message
          for ruleMessage, ruleMessages of messages
            rule = ruleMessages[0].rule
            grunt.log.writeln(ruleMessage + " (#{rule.id})".grey)
            grunt.log.writeln(rule.desc) if rule.desc and rule.desc isnt ruleMessages

            for {line, message, rule} in ruleMessages
              line--
              lessLineNumber = findLessLineNumber(cssLines, line)
              continue if lessLineNumber < 0

              if cssPropertyName = getPropertyName(cssLines[line])
                lessLineNumber = findPropertyLineNumber(lessLines, lessLineNumber, cssPropertyName)
                if lessLineNumber >= 0
                  errorCount++
                  errorPrefix = "#{lessLineNumber + 1} >>".red
                  grunt.log.writeln("#{errorPrefix} #{lessLines[lessLineNumber].trim()}")

    if errorCount is 0
      grunt.log.writeln("#{'>>'.green} #{fileCount} files lint free.")
    else
      grunt.log.writeln()
      grunt.log.writeln("#{'>>'.red} #{errorCount} linting errors in #{fileCount} files.")
      false
