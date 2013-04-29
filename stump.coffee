isnode = require('isnode')

extend = (object, properties) ->
  for own key, val of properties
    object[key] = val
  return object

merge = (options, overrides) ->
  return extend(extend({}, options), overrides)

type_to_string = (obj) ->
  if obj == undefined or obj == null
    return String obj
  classToType = new Object
  for name in "Boolean Number String Function Array Date RegExp".split(" ")
    classToType["[object " + name + "]"] = name.toLowerCase()
  myClass = Object.prototype.toString.call obj
  if myClass of classToType
    return classToType[myClass]
  return "object"

glocount = 0

dummyinspect = (arg1) ->
  return arg1
genericinspect = dummyinspect

colors = require('enkicolor')
# colors = require('./colors')

if isnode
  fs = require('fs')
  # colors = require('./colors')
  util = require('util')
  genericinspect = (arg) ->
    util.inspect(arg, false, 6, true)
    # JSON.stringify(util.inspect(arg, false, 6, true))

  # decklog = fs.createWriteStream('logs/deck.log')
  # clientlog = fs.createWriteStream('logs/client.log')
  # serverlog = fs.createWriteStream('logs/server.log')
  # otherlog = fs.createWriteStream('logs/other.log')
  # for lfile in [decklog, clientlog, serverlog]
  #   for abc in [1..10]
  #     lfile.write( colors['red']('**********************************************************************\n') )
else
  # colors = {}
  # for x in ['green', 'grey', 'cyan', 'yellow', 'red', 'bold', 'magenta', 'blue']
  #   colors[x] = (arg) ->
  #     return arg
  # decklog = null
  # clientlog = null
  # serverlog = null


defaults =
  delimiter: '-'
  delimiterColor: 'green'
  levels:
    trace       : 'grey'
    debug       : 'cyan'
    info        : 'green'
    warn        : 'yellow'
    error       : 'red'
    line        : 'bold'
    zalgo       : 'magenta'
  prefixCol: 'blue'
  dateCol: 'grey'
  suppress:
    TRACE: false
    DEBUG: false
  suppress_start: 
    TRACE: [
     # 'RefTracker',
    #  'FanoutClient', 
    #  'RootObject'
    ]
    DEBUG: [
       # 'RefTracker'
    ]
  
  LOGCHANNELS: {
    'default': ['console' ]
    # 'server': ['console' ]
    # 'client': ['console' ]
  }
  logchan: 'default'

obj_for_display = (obj, context, myinspect) =>
  context = context || {}
  if not context.final?
    context.final = true
  if not isnode
    return obj

  context.seenbook = context.seenbook || []

  typ = type_to_string(obj)
  processq = null

  if typ == 'object' or typ == 'function'
    if obj instanceof Error
      return obj
    if obj in context.seenbook
      return '<CIRCULAR>'
    context.seenbook.push(obj)
    if obj._refid
      typ = 'ref'
      processq = '<REF ' + obj.get_refpath().join('/') + '>'
    else
      processq = {}
      tmpcnt = 0
      for key, val of obj #XXX: own or not?
        tmpcnt += 1
        if not (context.skipunderscore and key.indexOf('_') == 0)
          processq[key] = obj_for_display(val, merge(context, {final: false}), myinspect )
      if tmpcnt == 0
        processq = obj
  else if typ == 'array'
    processq = []
    for elem, i in obj
      processq.push obj_for_display(elem, merge(context, {final: false}), myinspect )
  else if typ == 'undefined'
    return undefined
  else if typ == 'null'
    return null
  else
    return obj

  # return processq
  if not context.final
    return processq
  else
    return myinspect(processq, false, 6, true)

class StumpLog
  constructor: (desc_callback, custom, @parent, @root) ->
    @root = @root || @parent || @
    custom = custom || {}
    @config = merge(defaults, custom)

    @desc_callback = desc_callback || ->
      return ''

    if type_to_string( @desc_callback ) != 'function'
      @desc_callback = ->
        return desc_callback

    for key, val of @config.levels
      @[key] = @_log.bind(@, key)

  log: (args...) =>
    @info(args...)

  _log: (level, args...) =>
    lchans = @config.LOGCHANNELS[ @config.logchan ]

    colormsg = @_prep_log_console(colors, genericinspect, level, args...)
    nocolors = {
      green: (a) => a
      grey: (a) => a
      blue: (a) => a
      bold: (a) => a
      red: (a) => a
      cyan: (a) => a
    }
    glocount += 1

    for chan in lchans
      if not chan
        continue
      if chan == 'console'
        console.log.apply console, colormsg
      # else
      #   colorline = colormsg.join(' ') + '\n'
      #   plainline = colorline.replace(/\u001b\[..?m/g, '')
        
      #   newstr = (x.replace(/./g, ' ') for x in plainline.split(/\n/g) ).join("\n")

      #   chan.write( glocount + ' ' + colorline )
      #   if (chan == serverlog)
      #     clientlog.write( glocount + ' ' + newstr )
      #     decklog.write( glocount + ' ' + newstr )
      #   else if (chan == clientlog)
      #     serverlog.write( glocount + ' ' + newstr )
      #     decklog.write( glocount + ' ' + newstr )
      #   else if (chan == decklog)
      #     serverlog.write( glocount + ' ' + newstr )
      #     clientlog.write( glocount + ' ' + newstr )
        # console.log.apply console, colormsg
      # else
      #   console.log 'SOMETHING ELSE', colormsg
   
   _prep_log_console: (mycolors, myinspect, level, args...) => 
    if @config.suppress[level.toUpperCase()]
      return
    level_suppress = @root.config.suppress_start[level.toUpperCase()] || []
    desc = @desc_callback()
    for x in level_suppress
      if desc.indexOf(x) >= 0
        return
    delim = mycolors[ @config.delimiterColor ]( @config.delimiter )

    dtmp = new Date()
    logmsg = [
      mycolors[ @config.dateCol ](dtmp.toLocaleTimeString() + '.' + dtmp.getMilliseconds()),
      delim,
      mycolors[ @config['levels'][level] ]( level.toUpperCase() ),
      delim
    ]
    for elem in @get_logchain()
      logmsg.push( mycolors.bold( mycolors[ @config['prefixCol'] ]( elem ) ) )
      logmsg.push( delim )
    for arg in args
      if arg == null
        arg = '[null]'
      if arg == undefined
        arg = '[undefined]'
      logmsg.push( 
        mycolors[ @config['levels'][level] ](
          obj_for_display(arg, {}, myinspect)
        ) 
      )

    return logmsg

  get_logchain: ->
    x = this
    coll = []
    while x
      tmp = ( x.desc_callback?() || x.desc_callback )
      if tmp and tmp.length > 0
        coll.push( tmp)
      x = x.parent
    return coll.reverse()

  sub: (desc_callback) =>
    sublog = new StumpLog(desc_callback, @config, @, @root)
    return sublog

  suppress: (level) =>
    @config.suppress[level.toUpperCase()] = true

  stumpify: (target, desc_callback) =>
    sublog = @sub(desc_callback)
    for key, val of sublog.config.levels
      target[key] = sublog[key]
    target.stumpify = sublog.stumpify
    target.log = sublog.log
    target._stump = sublog

module.exports = new StumpLog()
module.exports.StumpLog = StumpLog
module.exports.obj_for_display = obj_for_display
