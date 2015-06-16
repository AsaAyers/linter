Path = require 'path'
{CompositeDisposable, Emitter} = require 'atom'
LinterViews = require './linter-views'
EditorLinter = require './editor-linter'
H = require './helpers'

class Linter
  constructor: ->
    @lintOnFly = true # A default art value, to be immediately replaced by the observe config below
    @_subscriptions = new CompositeDisposable

    @_emitter = new Emitter
    @_editorLinters = new Map
    @views = new LinterViews this # Used by editor-linter to trigger views.render
    @messagesProject = new Map # Values set in editor-linter and consumed in views.render
    @activeEditor = atom.workspace.getActiveTextEditor()
    @h = H
    @linters = [] # Values are pushed here from Main::consumeLinter

    @_subscriptions.add atom.config.observe 'linter.showErrorInline', (showBubble) =>
      @views.showBubble = showBubble
    @_subscriptions.add atom.config.observe 'linter-plus.lintOnFly', (value) =>
      @lintOnFly = value
    @_subscriptions.add atom.workspace.onDidChangeActivePaneItem (editor) =>
      @activeEditor = editor
      # Exceptions thrown here prevent switching tabs
      try
        @getLinter(editor)?.lint(false)
        @views.render()
      catch error
        atom.notifications.addError error.message, {detail: error.stack, dismissable: true}
    @_subscriptions.add atom.workspace.observeTextEditors (editor) =>
      currentEditorLinter = new EditorLinter @, editor
      @_editorLinters.set editor, currentEditorLinter
      @_emitter.emit 'linters-observe', currentEditorLinter
      currentEditorLinter.lint false
      editor.onDidDestroy =>
        currentEditorLinter.destroy()
        @_editorLinters.delete currentEditorLinter

  getActiveEditorLinter: ->
    return @getLinter @activeEditor

  getLinter: (editor) ->
    return @_editorLinters.get editor

  eachLinter: (callback) ->
    @h.genValue @_editorLinters, callback

  observeLinters: (callback) ->
    @eachLinter callback
    @_emitter.on 'linters-observe', callback

  deactivate: ->
    @_subscriptions.dispose()
    @eachLinter (linter) ->
      linter.destroy()
    @views.destroy()

module.exports = Linter