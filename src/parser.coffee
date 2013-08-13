# ### begin original comment by jashkenas
# The CoffeeScript parser is generated by [Jison](http://github.com/zaach/jison)
# from this grammar file. Jison is a bottom-up parser generator, similar in
# style to [Bison](http://www.gnu.org/software/bison), implemented in JavaScript.
# It can recognize [LALR(1), LR(0), SLR(1), and LR(1)](http://en.wikipedia.org/wiki/LR_grammar)
# type grammars. To create the Jison parser, we list the pattern to match
# on the left-hand side, and the action to take (usually the creation of syntax
# tree nodes) on the right. As the parser runs, it
# shifts tokens from our token stream, from left to right, and
# [attempts to match](http://en.wikipedia.org/wiki/Bottom-up_parsing)
# the token sequence against the grammar below. When a match can be made, it
# reduces into the [nonterminal](http://en.wikipedia.org/wiki/Terminal_and_nonterminal_symbols)
# (the enclosing name at the top), and we proceed from there.
#
# If you run the `cake build:parser` command, Jison constructs a parse table
# from our grammar and saves it into `lib/parser.js`.
# ### end original comment by jashkenas

# The only dependency is on the **Jison.Parser**.
# {Parser} = require 'jison' # the only dependency is not needed any more.

# Jison DSL
# ---------

{identifier, keyword} = require './parserutil'
yy = require '../lib/coffee-script/nodes'

# some global variable used by the parser
text = '' # the text which is being parsed, this could be any sequence, not only strincs.
textLength = 0 # the length of text
cursor = 0  # the current position of parsing, use text[cursor] to get current character in parsed stream
tabWidth = 4 # the tab width, when meet a tab, column += tabWidth
parseCache = {} # {tag+start: [result, cursor]}, memorized parser result
symbolToTagMap = {}  # {symbol: tag}, from rule symbol map to a shorter memo tag, for memory efficeny
tags = {}  # {tag: true}, record tags that has been used to avoid conflict
symbolToParentsMap = {} # {symbol:[parent...]}, the map from symbol to their all of parents for left recursive symbols
baseRules = {} # {symbole: rule's function}

# parse @data from @start with the rule function @root
exports.parse = (data, root, options) ->
  o = options or {}
  if typeof start == 'object' then start = 0; options = start
  text = data
  textLength = text.length
  cursor = o.start or 0
  tabWidth = o.tabWidth or 4
  parseCache = {}
  baseRules = {}
  symbolToParentsMap = {}
  memoNames = ['Expression', 'Body', 'Line', 'Block', 'Invocation', 'Value', 'Assignable',
               'SimpleAssignable', 'For', 'If', 'Operation']
  for symbol in memoNames then setMemoTag(symbol)
  addLeftRecursiveParentChildrens(
     Expression: ['Invocation', 'Value', 'Operation', 'Invocation', 'Assign', 'While', 'For'],
     Value: ['Assignable'],
     Assignable: ['SimpleAssignable'],
     SimpleAssignable: ['Value', 'Invocation'],
     Assign: ['Assignable'],
     Invocation: ['Value', 'Invocation'],
     For: ['Expression'],
     If: ['Expression'],
     Operation: ['Expression', 'SimpleAssignable']
  )
  setRecursiveRules(grammar)
  setMemorizeRules(grammar, ['Body', 'Line', 'Block', 'Statement'])
  generateLinenoColumn()
  grammar.Root(0)

lineColumnList = []
generateLinenoColumn = () ->
  i = 0
  lineno = column = 0
  while i<textLength
    c = text[i]
    if c is '\r'
      lineColumnList[i++] = [lineno, column]
      if text[i] is '\n'
        lineColumnList[i++] = [lineno, column]
      lineno++; column = 0
    else if c is '\n'
      lineColumnList[i++] = [lineno, column]
      lineno++; column = 0
    else if c is '\t'
      lineColumnList[i++] = [lineno, column]
      column += tabWidth
    else
      lineColumnList[i++] = [lineno, column]
      column++

# some utilities used by the parser
# on succeed any matcher should not return a value which is not null or undefined, except the root symbol.

# set a shorter start part of symbol as the tag used in parseCache
setMemoTag = (symbol) ->
  i = 1
  while 1
    if hasOwnProperty.call(tags, symbol.slice(0, i)) in tags then i++
    else break
  tag = symbol.slice(0, i)
  symbolToTagMap[symbol] = tag
  tags[tag] = true

# set the symbols in grammar which  memorize their rule's result.
setMemorizeRules = (grammar, symbols) ->
  for symbol in symbols
    baseRules[symbol] = grammar[symbol]
    rules[symbol] = memorize(symbol)

# set all the symbols in grammar which  are left recursive.
setRecursiveRules = (grammar) ->
  map = symbolToParentsMap
  for symbol of map
    baseRules[symbol] = grammar[symbol]
    rules[symbol] = recursive(symbol)

# add direct left recursive parent->children relation for @parentChildrens to global variable symbolToParentsMap
addLeftRecursiveParentChildrens = (parentChildrens...) ->
  map = symbolToParentsMap
  for parentChildren in parentChildrens
    for parent, children of parentChildren
      for symbol in children
        list = map[symbol] ?= []
        if parent isnt symbol and parent not in list then list.push parent

# add left recursive parent->children relation to @symbolToParentsMap for symbols in @recursiveCircles
addLeftRecursiveCircles = (recursiveCircles...) ->
  map = symbolToParentsMap
  for circle in recursiveCircles
    i = 0
    length = circle.length
    while i<length
      if i==length-1 then j = 0 else j = i+1
      symbol = circle[i]; parent = circle[j]
      list = map[symbol] ?= []
      if parent isnt symbol and parent not in list then list.push parent
      i++

# make @symbol a left recursive symbol, which means to wrap baseRules[symbol] with recursive,
# when recursiv(symbol)(start) is executed, all of left recursive rules which @symbol depend on will be computed
# and memorized, until no change exists.
recursive = (symbol) ->
  map = symbolToParentsMap
  tag = symbolToTagMap[symbol]
  agenda = [] # dynamic list included all left recursive symbols which depend on @symbol
  addParent = (parent) ->
    agenda.unshift(parent)
    parents =  map[parent]
    if parents then for parent in parents
      if parent not in agenda
        agenda.unshift(parent)
        addParent(parent)
  addParent(symbol)
  (start) ->
    hash0 = tag+start
    m = parseCache[hash0]
    if m then cursor = m[1]; return m[0]
    while agenda.length  # exist any symbols which depend on the changed result?
      symbol = agenda.pop()
      hash = tag+start
      m = parseCache[hash]
      if not m then m = parseCache[hash] = [undefined, start]
      rule = baseRules[symbol]
      changed = false
      while 1
        if (result = rule(start)) and (result isnt m[0] or cursor isnt m[1])
          parseCache[hash] = m = [result, cursor]
          changed = true
        else break
      # if any new result exists, recompute the symbols which may be depend on the new result.
      if changed then for parent in map[symbol]
        if parent not in agenda then agenda.push parent
    m = parseCache[hash0]
    cursor = m[1]
    m[0]

# memorize result and cursor for @symbol which is not left recursive.
# left recursive should be wrapped by recursive(symbol)!!!
memorize = memorize = (symbol) ->
  tag = symbolToTagMap[symbol]
  rule = baseRules[symbol]
  hash = tag+start
  (start) ->
    m = parseCache[hash]
    if m then cursor = m[1]; m[0]
    else
      result = rule(start)
      parseCache[hash] = [result, cursor]
      result

# lookup the memorized result and reached cursor for @symbol at the position of @start
exports.memo = memo = (symbol) ->
  tag = symbolToTagMap[symbol]
  (start) ->
    m = parseCache[tag+start]
    if m then cursor = m[1]; m[0]

# compute exps in sequence, return the result of the last one.
# andp and orp are used to compose the matchers
# the effect is the same as by using the Short-circuit evaluation, like below:
# exps[0](start) and exps[2](cursor] ... and exps[exps.length-1](cursor)
andp = (exps...) -> (start) ->
  cursor = start
  for exp in exps
    if not(result = exp(cursor)) then return result
  return result

# compute exps in parallel, return the result of the first which is not evaluated to false.
# the effect is the same as by using the Short-circuit evaluation, like below:
# exps[0](start) or exps[2](cursor] ... or exps[exps.length-1](cursor)
orp = (exps...) -> (start) ->
for exp in exps
  if result = exp(start) then return result
  return result

# applicaton of not operation
# notp is not useful  except to compose the matchers.
# It's not unnessary, low effecient and ugly to write "notp(exp)(start)",
# so don't write "notp(exp)(start)", instead "not exp(start)".
notp = (exp) -> (start) -> not exp(start)

# compute the global variable lineno and column Synchronously
# It's important and noteworthy that how to keep lineno and column having the correct value at any time.
# pay attention to that!
next = () ->
  c = text[cursor++]
  if c is '\r'
    if text[cursor] is '\n' then c = text[cursor++]
    lineno++; column = 0
  else if c is '\n' then lineno++; column = 0
  return c

# change both cursor and column
step = (n=1) -> cursor += n; column += n

# match one character
char = (c) -> (start) ->
  cursor = start
  setlinecolumen()
  if next()==c then cursor = start+1; return c

# match a literal string.
# There should not have newline character("\r\n") in literal string!
# Otherwise the lineno and column will be updated wrongly.
literal = (string) -> (start) ->
  n = string.length
  if text.slice(start,  stop = start+n)==string
    cursor = stop; column += n; true

# zero or more whitespaces, ie. space or tab.
# tab '\t' is counted as tabWidth spaces, and the columen is updated in this manner.
# the whitespaces width+1 is returned as result( +1 to avoid 0 as the result, which is a falsic value)!!!
# newline is not included!!!
spaces = (start) ->
  n = 0
  cursor = start
  while 1
    c = text[cursor]
    cursor++
    if c==' ' then n++
    else if c=='\t' then n += tabWidth
    else break
  column += n
  return n+1

# one or more whitespaces, ie. space or tab.
# tab '\t' is counted as tabWidth spaces, and the columen is updated in this manner.
# newline is not included!!!
spaces1 = (start) ->
  n = 0
  cursor = start
  while 1
    c = text[cursor]
    cursor++
    if c==' ' then n++
    else if c=='\t' then n += tabWidth
    else break
  if n then return column += n; n

# first, match @left, then match @item, at last match @right
# left and right is set to spaces by default.
wrap = (item, left=spaces, right=spaces) -> (start) ->
  if left(start) and result = item(cursor) and right(cursor)
    return result

# Grammatical rules of Coffeescript

exports.grammar = grammar = cs = {}

# The **Root** is the top-level node in the syntax tree.
cs.Root = (start) ->
  skipHeadSpaces(start)  # skip the spaces at the begin of program, including line comment.
  if cursor is textLength then new yy.Block
  else
    body = cs.Body(cursor)
    # and skipTailSpaces(cursor); body # is skipTailSpaces necessary? wait to see.

# skip the spaces at the begin of program, including line comment.
skipHeadSpaces = (start) ->
  while1: while c = next()
    switch c
      when ' ', 't', '\r', '\n' then continue
      when '#'
        while c = next()
          if c and c!='\r' and c!='n' then continue
          else break
      else
        `break while1`;
        undefined # workarounds of coffeescript's transpilation feature.
  if column isnt 0 then throw new Error("Effect Code Line should at column 0, the begin of a line.")


# Any list of statements and expressions, separated by line breaks or semicolons.
cs.Body = (start) ->
  lines = []
  x = cs.Line(start)
  if x then lines.push(x)
  while 1
    if cs.TERMINATOR(cursor)
      if x = cs.Line(cursor) then lines.push x
    else break
  yy.Block.wrap(lines)

# Block and statements, which make up a line in a body.
# The comment above is by jashkenas. Should it be Expression?
cs.Line = (start) ->
  cs.Statement(cursor)\
  or cs.Expression(cursor)

# Pure statements which cannot be expressions.
cs.Statement = (start) ->
   cs.Return(start)\
   or cs.Comment(start)\
   or cs.Break(start)\
   or Continue(start)
   # Break and Continue is my repacement to STATEMENT in original grammar.coffee

# A return statement from a function body.
cs.Return = (start) ->
  if word_return(start) and spacesConcatLine(cursor)
    if exp = cs.Expression(cursor) then new yy.Return exp
    else new yy.Return

# A block comment.
cs.Comment = (start) -> cs.HERECOMMENT(start)
cs.HERECOMMENT = (start) ->
  cursor = start
  c = next()
  if c=='#'
    if text.slice(cursor, cursor+2) is '##'
      column += 2; cursor += 2
      while 1
        c = next()
        if c isnt '#' then continue
        if text.slice(cursor, cursor+2) is '##' then return true
  else while 1 then if c is '\n' then return true

cs.Break = (start) -> if word_break(start) and spaces(cursor)  then new yy.Literal('break')
Continue = (start) -> if word_continue(start) and spaces(cursor)  then new yy.Literal('continue')

word_return = literal('return')
word_break = literal('break')
word_continue = literal('continue')

# All the different types of expressions in our language. The basic unit of
# CoffeeScript is the **cs.Expression** -- everything that can be an expression
# is one. Blocks serve as the building blocks of many other grammar, making
# them somewhat circular.
cs.Expression = (start) ->
  recValue(start)\
  or recOperation(start)\
  or recInvocation(start)\
  or recAssign(start)\
  or recIf(start)\
  or recWhile(start)\
  or recFor(start)\
  or cs.Switch(start)\
  or cs.Throw(start)\
  or cs.Class(start)\
  or cs.Try(start)\
  or cs.Code(start)       #(param) -> ... or -> ..

recValue = memo('Value')
recInvocation = memo('Invocation')
recoAssign = memo('Assign')
recIf = memo('If')
recWhile = memo('While')
recFor = memo('For')

# An indented block of expressions. Note that the [Rewriter](rewriter.html)
# will convert some postfix forms into blocks for us, by adjusting the
# token stream.
cs.Block = (start) ->
  if INDENT(start)
    if OUTDENT(cursor) then new yy.Block
    else if body = cs.Body(cursor) and  OUTDENT(cursor) then body

# A literal identifier, a variable name or property.
cs.Identifier = (start) -> cs.IDENTIFIER(start)

# All of our immediate values. Generally these can be passed straight
# through and printed to JavaScript.
cs.Literal = (start) ->
  cs.NUMBER(start)\
  or cs.STRING(start)\
  or cs.JS(start)\
  or cs.REGEX(start)\
  or cs.DEBUGGER(start)\
  or cs.UNDEFINED(start)\
  or cs.NULL(start)\
  or cs.BOOL(start)

recAssignable = memo('Assignable')
  # Assignment of a variable, property, or index to a value.
cs.Assign = (start) ->
  if left = recAssignable(start) and wrap('=')(cursor)
    if exp = cs.Expression(cursor)\
       or cs.TERMINATOR(cursor) and exp = cs.Expression(cursor)\
       or INDENT(cursor) and exp = cs.Expression and OUTDENT(cursor)
      new yy.Assign left, exp

# Assignment when it happens within an object literal. The difference from
# the ordinary **cs.Assign** is that these allow numbers and strings as keys.
cs.AssignObj = (start) ->
  if x = cs.Comment then return x
  if left = cs.ObjAssignable(start)
    if wrap(':')
      if exp = cs.Expression(cursor)\
         or INDENT(cursor) and exp = cs.Expression(cursor) and OUTDENT(cursor)
        new yy.Assign LOC(1)(new yy.Value(left)), exp, 'object'
    else new yy.Value left

cs.ObjAssignable = (start) ->
  cs.Identifier(start)\
  or Number(start)\
  or String(start)\
  or cs.ThisProperty(start)

# The **cs.Code** node is the function literal. It's defined by an indented block
# of **cs.Block** preceded by a function arrow, with an optional parameter
# list.
cs.Code = (start) ->
  if PARAM_START(start) and params = cs.ParamList(cursor) and PARAM_END(cursor) \
      and funcGlyph = cs.FuncGlyph(cursor) and body = cs.Block(cursor)
    new yy.Code params, body, funcGlyph
  else if funcGlyph = cs.FuncGlyph(cursor) and body = cs.Block(cursor)
    new yy.Code [], body, funcGlyph

# CoffeeScript has two different symbols for functions. `->` is for ordinary
# functions, and `=>` is for functions bound to the current value of *this*.
cs.FuncGlyph = (start) ->
  if wrap('->')(start) then  'func'
  else if wrap('=>') then 'boundfunc'

# An optional, trailing comma.
cs.OptComma = (start) ->
  spaces(start)
  if char(',') then spaces(cursor); [true]
  [false]

# The list of parameters that a function accepts can be of any length.
cs.ParamList = (start) ->
  if param = cs.Param(start)
    result = [param]
    while 1
      meetComma = cs.OptComma(cursor)
      if cs.TERMINATOR(cursor) and param = cs.Param(cursor) then result.push(param)
      else if INDENT(cursor)
        params = cs.ParamList(cursor)
        for p in params then result.push(p)
        OUTDENT(cursor)
      else if meetComma[0] and param = cs.Param(cursor) then result.push(param)
      else break
    result

# A single parameter in a function definition can be ordinary, or a splat
# that hoovers up the remaining arguments.
cs.Param = (start) ->
  v = cs.ParamVar(start)
  if wrap('...')(cursor) then new yy.Param v, null, on
  else if wrap('=')(cursor) and exp = cs.Expression(cursor) then  new yy.Param v, exp
  else new yy.Param v

# Function Parameters
cs.ParamVar = (start) ->
  cs.Identifier(start)\
  or cs.ThisProperty(start)\
  or cs.Array(start)\
  or cs.Object(start)

# A splat that occurs outside of a parameter list.
cs.Splat = (start) ->
  if exp = cs.Expression(start) and wrap('...')(cursor)
    new yy.Splat exp

# Variables and properties that can be assigned to.
cs.SimpleAssignable = (start) ->
 if value = recValue(start) and accessor = cs.Accessor(cursor) then value.add accessor
 else if caller = recInvocation(start) and accessor = cs.Accessor(cursor)
  new yy.Value caller, [].concat accessor
 else if thisProp = cs.ThisProperty(start) then thisProp
 else if name = cs.Identifier(start) then  new yy.Value name

# Everything that can be assigned to.
cs.Assignable = (start) ->
  recSimpleAssignable(start)\
  or cs.newyyValue(cs.Array)(start)\
  or cs.newyyValue(cs.Object)(start)

# The types of things that can be treated as values -- assigned to, invoked
# as functions, indexed into, named as a class, etc.
cs.Value = (start) ->
  recAssignable(start)\
  or cs.newyyValue(cs.Literal)(start)\
  or cs.newyyValue(cs.Parenthetical)(start)\
  or cs.newyyValue(cs.Range)(start)\
  or cs.This(start)

# The general group of accessors into an object, by property, by prototype
# or by array index or slice.
cs.Accessor = (start) ->
  if wrap('.') and id = cs.Identifier(cursor) then new yy.Access id
  else if wrap('?.') and id = cs.Identifier(cursor) then new yy.Access id, 'soak'
  else if wrap('::') and id = cs.Identifier(cursor)
    new[LOC(1)(new yy.Access new yy.Literal('prototype')), LOC(2)(new yy.Access id)]
  else if wrap('?::') and id = cs.Identifier(cursor)
    [LOC(1)(new yy.Access new yy.Literal('prototype'), 'soak'), LOC(2)(new yy.Access id)]
  else if wrap('::') then new Access new cs.Literal 'prototype'
  else if index = cs.Index(start) then index

# Indexing into an object or array using bracket notation.
cs.Index = (start) ->
  if INDEX_START(start) and val = cs.IndexValue(cursor) and INDEX_END(cursor) then val
  if INDEX_SOAK(cursor) and cs.Index(cursor)   # id?[1]
    yy.extend $2, soak : yes

cs.IndexValue = (start) ->
  if value = cs.Expression(start) then new yy.Index value
  else if slice = cs.Slice(start) then new yy.Slice slice

# In CoffeeScript, an object literal is simply a list of assignments.
cs.Object = (start) ->
  if leftBrace = wrap('{')(start)
    spaces(cursor)
    if char('}') then new yy.Obj [], leftBrace.generated
    else if assigns = cs.AssignList(cursor)\
       and cs.OptComma(cursor) and wrap('}')(cursor)
     new yy.Obj assigns, leftBrace.generated

# Assignment of properties within an object literal can be separated by
# comma, as in JavaScript, or simply by newline.
cs.AssignList = (start) ->
  if assign = cs.AssignObj(start)
    result = [assign]
    while 1
      meetComma = cs.OptComma(cursor)
      if cs.TERMINATOR(cursor) and assign = cs.AssignObj(cursor) then result.push(assign)
      else if INDENT(cursor)
        assigns = cs.AssignList(cursor)
        for x in assigns then result.push(x)
        OUTDENT(cursor)
      else if meetComma[0] and assign = cs.AssignObj(cursor) then result.push(param)
      else break
    result

# cs.Class definitions have optional bodies of prototype property assignments,
# and optional references to the superclass.
cs.Class = (start) ->
  if CLASS(start)
    if name = cs.SimpleAssignable(cursor)
      if EXTENDS(cursor) and sup = cs.Expression(cursor)
        if body = cs.Block(cursor) then new yy.Class name, sup, body
        else new yy.Class name, sup
      else if body = cs.Block(cursor) then new yy.Class name, null, body
      else new yy.Class name
    else
      if EXTENDS(cursor) and sup = cs.Expression(cursor)
        if body = cs.Block(cursor) then new yy.Class null, sup, body
        else new yy.Class null, sup
      else if body = cs.Block(cursor) then new yy.Class null, null, body
      else new yy.Class

# Ordinary function invocation, or a chained series of calls.
cs.Invocation = (start) ->
  # left recursive
  if m1 = recValue(start) and cs.OptFuncExist(cursor) and cs.Arguments(cursor)
    new yy.Call $1, $3, $2
  else if m2 = recInvocation(start) and cs.OptFuncExist(cursor) and cs.Arguments(cursor)
    new yy.Call $1, $3, $2
  if not m1 and not m2
    if SUPER(start)
      new yy.Call 'super', [new yy.Splat new yy.Literal 'arguments']
    else if SUPER(start) and cs.Arguments(cursor)
      new yy.Call 'super', $2

# An optional existence check on a function.
cs.OptFuncExist = (start) ->
  if emptyword(start) then no
  if FUNC_EXIST(start) then yes

# The list of arguments to a function call.
cs.Arguments = (start) ->
  if CALL_START(start)
    if args = cs.ArgList(cursor) and cs.OptComma(cursor)
      args
    else result = []
    if CALL_END(cursor) then result

# A reference to the *this* current object.
cs.This = (start) ->
  if THIS(start) then new yy.Value new yy.Literal 'this'
  if wrap('')(start) then new yy.Value new yy.Literal 'this'

# A reference to a property on *this*.
cs.ThisProperty = (start) ->
  if wrap('')(start) and cs.Identifier(cursor)
    new yy.Value LOC(1)(new yy.Literal('this')), [LOC(2)(new yy.Access($2))], 'this'

# The array literal.
cs.Array = (start) ->
  if wrap('[')(start)
    if cs.ArgList(cursor) and cs.OptComma(cursor)
      result =  new yy.Arr $2
    else result = new yy.Arr []
    if wrap(']')(cursor) then result

# Inclusive and exclusive range dots.
cs.RangeDots = (start) ->
  if wrap('..')(start) then 'inclusive'
  else if wrap('...')(start) then 'exclusive'

# The CoffeeScript range literal.
cs.Range = (start) ->
  if wrap('[')(start) and cs.Expression(cursor) and cs.RangeDots(cursor) and cs.Expression(cursor) wrap(']')
    new yy.Range $2, $4, $3

# cs.Array slice literals.
cs.Slice = (start) ->
  # don't use recExpression here
  if cs.Expression(start) and cs.RangeDots(cursor) and cs.Expression(cursor)
    new yy.Range $1, $3, $2
  if cs.Expression(start) and cs.RangeDots(cursor)
    new yy.Range $1, null, $2
  if cs.RangeDots(start) and cs.Expression(cursor) then new yy.Range null, $2, $1
  if cs.RangeDots(start) then  new yy.Range null, null, $1

# The **cs.ArgList** is both the list of objects passed into a function call,
# as well as the contents of an array literal
# (i.e. comma-separated expressions). Newlines work as well.
cs.ArgList = (start) ->
  if cs.Arg(start) then  [$1]
  else if cs.ArgList(start) and wrap(',') and cs.Arg(cursor) then  $1.concat $3
  else if cs.ArgList(start) and cs.OptComma(cursor) and cs.TERMINATOR(cursor) and cs.Arg(cursor) then $1.concat $4
  else if INDENT(start) and cs.ArgList(cursor) and cs.OptComma(cursor) and OUTDENT(cursor) then $2
  else if cs.ArgList(start) and cs.OptComma(cursor) and INDENT(cursor) and cs.ArgList(cursor) and cs.OptComma(cursor) and OUTDENT(cursor)
    $1.concat $4

# Valid arguments are Blocks or Splats.
cs.Arg = (start) -> cs.Expression(start) or cs.Splat(start)

# Just simple, comma-separated, required arguments (no fancy syntax). We need
# this to be separate from the **cs.ArgList** for use in **cs.Switch** blocks, where
# having the newlines wouldn't make sense.
cs.SimpleArgs = (start) ->
  if exp = cs.Expression(start)
    result = [exp]
    while 1
      if wrap(',')
        if exp = cs.Expression(cursor) then result.push(exp)
        else return
    result

# The variants of *try/catch/finally* exception handling blocks.
cs.Try = (start) ->
  test =  TRY(start) and cs.Block(cursor)
  if test
    if cs.Catch(cursor) and catch_ = cs.Block(cursor)
      if FINALLY(cursor) and final = cs.Block(cursor)
        new yy.Try test, catch_[0], catch_[1], final
      else new yy.Try test, catch_[0], catch_[1]
    else if FINALLY(cursor) and final = cs.Block(cursor)
      new yy.Try test, null, null, final
    else new yy.Try test

# A catch clause names its error and runs a block of code.
cs.Catch = (start) ->
  if CATCH(start)
    if vari = cs.Identifier(cursor) and  body = cs.Block(cursor) then  [vari, body]
    if obj = cs.Object(cursor)
      if body = cs.Block(cursor) then [LOC(2)(new yy.Value(obj)), body]
    else if body = cs.Block(cursor) then [null, body]

# cs.Throw an exception object.
cs.Throw = (start) ->
  if THROW(start) and cs.Expression(cursor) then  new yy.Throw $2

# cs.Parenthetical expressions. Note that the **cs.Parenthetical** is a **cs.Value**,
# not an **cs.Expression**, so if you need to use an expression in a place
# where only values are accepted, wrapping it in parentheses will always do
# the trick.
cs.Parenthetical = (start) ->
  if wrap('(')(start)
    if body = cs.Body(start)
      if wrap(')')(cursor) then new yy.Parens body
    if INDENT(start) and cs.Body(cursor) and OUTDENT(cursor)
      if wrap(')')(cursor)  then new yy.Parens $3

# The condition portion of a while loop.
cs.WhileSource = (start) ->
  if WHILE(start)
    if test = cs.Expression(cursor)
      if WHEN(cursor) and value = cs.Expression(cursor)
        new yy.While test, guard: value
      else new yy.While $2
  else if UNTIL(start)
    if test = cs.Expression(cursor)
      if WHEN(cursor) and value = cs.Expression(cursor)
        new yy.While $2, invert: true, guard: $4
      else new yy.While $2, invert: true

# The while loop can either be normal, with a block of expressions to execute,
# or postfix, with a single expression. There is no do..while.
cs.While = (start) ->
  if exp = recExpression(start) and cs.WhileSource(cursor)
    return $2.addBody LOC(1) yy.Block.wrap([$1])
  if exp then retturn exp
  else if cs.WhileSource(start) and cs.Block(cursor)  then $1.addBody $2
  else if cs.Statement(start) and  cs.WhileSource(cursor) then $2.addBody LOC(1) yy.Block.wrap([$1])
  else if body = cs.Loop(start) then body

cs.Loop = (start) ->
  if LOOP(start)
    if body = cs.Block(cursor) then new yy.While(LOC(1) new yy.Literal 'true').addBody body
    else if body = cs.Expression(cursor)
      new yy.While(LOC(1) new yy.Literal 'true').addBody LOC(2) cs.Block.wrap [body]

# cs.Array, object, and range comprehensions, at the most generic level.
# Comprehensions can either be normal, with a block of expressions to execute,
# or postfix, with a single expression.
cs.For = (start) ->
  if action = recExpression(start)  and test = cs.ForBody(cursor) then new yy.For action, test
  if action then return action
  if action = cs.Statement(start)  and test = cs.ForBody(cursor) then new yy.For action, test
  else if test = cs.ForBody(start) and  action = cs.Block(cursor) then  new yy.For action, test

cs.ForBody = (start) ->
  if range = FOR(start) and cs.Range(cursor) then source: LOC(2) new yy.Value(range)
  else if start = cs.ForStart(start) and src = cs.ForSource(cursor)
    src.own = start.own; src.name = start[0]; src.index = start[1];
    src

cs.ForStart = (start) ->
  if FOR(start)
    if OWN(cursor)
      if vari = cs.ForVariables(cursor) then vari.own = yes; vari
    else if vari = cs.ForVariables(cursor) then vari

# An array of all accepted values for a variable inside the loop.
# cs.This enables support for pattern matchin
cs.ForValue = (start) ->
  if id = cs.Identifier(start) then id
  else if prop = cs.ThisProperty(start) then prop
  else if cs.Array(start) then  new yy.Value arr
  else if obj = cs.Object(start) then  new yy.Value obj

# An array or range comprehension has variables for the current element
# and (optional) reference to the current index. Or, *key, value*, in the case
# of object comprehensions.
cs.ForVariables = (start) ->
  if v = cs.ForValue(start)
     if wrap(',')(cursor) and v3 = cs.ForValue(cursor) then  [v1, v3]
     else [v]

# The source of a comprehension is an array or object with an optional guard
# clause. cs.If it's an array comprehension, you can also choose to step through
# in fixed-size increments.
cs.ForSource = (start) ->
  if FORIN(start) and source = cs.Expression(cursor)
    if WHEN(cursor) and guard = cs.Expression(cursor)
      if BY(cursor) and step = cs.Expression(cursor) then source: source, guard: guard, step: step
      else source: source, guard: guard, object: yes
    else source: source
  if FOROF(start) and source = cs.Expression(cursor)
    if WHEN(cursor) and guard = cs.Expression(cursor)
      if BY(cursor) and step = cs.Expression(cursor) then source: source, guard: guard, step: step
      else source: source, guard: guard, object: yes
    else source: source

cs.Switch = (start) ->
  if SWITCH(start)
    if INDENT(cursor)
      if whens = cs.Whens(cursor)
        if ELSE(cursor) cs.Block(cursor)   new yy.Switch null, whens, else_
        else new yy.Switch test, whens
      OUTDENT(cursor)
    else if test = cs.Expression(cursor)
      if INDENT(cursor)
        if whens = cs.Whens(cursor)
          if ELSE(cursor) and  cs.Block(cursor)   new yy.Switch null, whens, else_
          else new yy.Switch test, whens
    OUTDENT(cursor)

cs.Whens = (start) ->
  result =[]
  while 1
    if LEADING_WHEN(start)
      if args = cs.SimpleArgs(cursor) and action = cs.Block(cursor) and may(cs.TERMINATOR)(cursor)
        result.push([args, action])
      else return result

# The most basic form of *if* is a condition and an action. The following
# if-related grammar are broken up along these lines in order to avoid
# ambiguity.
cs.IfBlock = (start) ->
  if IF(start) and test = cs.Expression(cursor) and body = cs.Block(cursor)
    new yy.If test, body, type: $1
  if cs.IfBlock(start) and  ELSE(cursor) and IF(cursor) and cs.Expression(cursor) and cs.Block(cursor)
    $1.addElse new yy.If $4, $5, type: $3

# The full complement of *if* expressions, including postfix one-liner
# *if* and *unless*.
cs.If = (start) ->
  if if_ = cs.IfBlock(start)
    if ELSE(cursor) and elseBody = cs.Block(cursor)  then if_.addElse elseBody
    else if_
  if cs.Statement(start)  and POST_IF(cursor) and cs.Expression(cursor)
    new yy.If $3, LOC(1)(cs.Block.wrap [$1]), type: $2, statement: true

# Arithmetic and logical operators, working on one or more operands.
# Here they are grouped by order of precedence. The actual precedence grammar
# are defined at the bottom of the page. It would be shorter if we could
# combine most of these grammar into a single generic *Operand OpSymbol Operand*
# -type rule, but in order to make the precedence binding possible, separate
# grammar are necessary.
cs.Operation = (start) ->
  if m = memo('Expression')(start)
    if _spaces('?')(cursor) then new yy.Existence $1
    else if wrapadd(cursor) and  cs.Expression(cursor) then  return new yy.Op '+' , $1, $3
    else if wrapsub(cursor)  and cs.Expression(cursor)  then return new yy.Op '-' , $1, $3
    else if MATH(cursor) and cs.Expression(cursor)  then return new yy.Op $2, $1, $3
    else if SHIFT(cursor) and cs.Expression(cursor)  then return new yy.Op $2, $1, $3
    else if COMPARE(cursor) and cs.Expression  then return new yy.Op $2, $1, $3
    else if LOGIC(cursor) and cs.Expression(cursor)  then return new yy.Op $2, $1, $3
    else if RELATION(cursor) and cs.Expression(cursor)
      if $2.charAt(0) is '!' then return new yy.Op($2[1..], $1, $3).invert()
      else return new yy.Op $2, $1, $3

  else if simple = memo('SimpleAssignable')(start)
      if COMPOUND_ASSIGN(cursor) and cs.Expression(start) then return new yy.Assign $1, $3, $2
      else if COMPOUND_ASSIGN(cursor) and INDENT(cursor) and cs.Expression(cursor) and OUTDENT(cursor)
        return new yy.Assign $1, $4, $2
      else if COMPOUND_ASSIGN(cursor) and cs.TERMINATOR(cursor) and cs.Expression(cursor)
        return new yy.Assign $1, $4, $2
      else if EXTENDS(cursor) and cs.Expression(cursor)  then new yy.Extends $1, $3

  if op = UNARY(start) and exp = cs.Expression(cursor) then new yy.Op op , exp
  else if wrap('-')(start) and exp = cs.Expression(cursor)  then new yy.Op '-', exp, prec: 'UNARY'
  else if wrap('+')(start) and  exp = cs.Expression(cursor) then new yy.Op '+', exp, prec: 'UNARY'
  else if wrap('++')(start) and cs.SimpleAssignable(cursor) then  new yy.Op '++', $2
  else if wrapdec(start) and cs.SimpleAssignable(cursor)  then new yy.Op '--', $2
  else if cs.SimpleAssignable(start) and wrap('--')(cursor)  then new yy.Op '--', $1, null, true
  else if cs.SimpleAssignable(start) and wrap('++')(cursor)  then new yy.Op '++', $1, null, true

wrapinc = wrap('++'); wrapdec = wrap('--');  wrapadd = wrap('+'); wrapsub = wrap('-');

_spaces = (item) -> (start) -> item(start) and  spaces(cursor)
spaces_ = (item) -> (start) -> spaces(start) and item(cursor)

cs.newyyValue = (item) -> (start) ->
  if x = item(start) then new yy.Value(x)

cs.TERMINATOR = (start) ->
  cursor = start
  while 1
    c = next
    if c==' ' or c==';' or c=='\t' then continue
    else if c=='\\'
      if text[cursor+1]=='\r' and text[cursor+2]=='\n'
        cursor += 3; lineno++; column = 0
      else if text[cursor+1]=='\n' then  cursor += 2; lineno++; column = 0
      else new ParseError(lineno, column, "meet a line concatenation symbol ('\\') which is not at the end of line.")
    else break
  true

cs.IDENTIFIER = (start) ->
  if id = identifier(start) then new yy.Literal id

cs.NUMBER = (start)-> new yy.Literal $1
cs.STRING = (start) -> new yy.Literal $1
cs.JS = (start) ->  new yy.Literal $1
cs.REGEX = (start) -> new yy.Literal $1
cs.DEBUGGER = (start) -> new yy.Literal $1
cs.UNDEFINED = (start) -> new yy.Undefined
cs.NULL = (start) -> new yy.Null
cs.BOOL = (start) -> new yy.Bool $1
cs.HERECOMMENT = (start) -> new yy.Comment $1

# Precedence
# Operators at the top of this list have higher precedence than the ones lower down.
# Following these grammar is what makes `2 + 3 * 4` parse as 2 + (3 * 4) and not (2 + 3) * 4
operators = [
  ['left',      '.', '?.', '::', '?::']
  ['left',      'CALL_START', 'CALL_END']
  ['nonassoc',  '++', '--']
  ['left',      '?']
  ['right',     'UNARY']
  ['left',      'MATH']
  ['left',      '+', '-']
  ['left',      'SHIFT']
  ['left',      'RELATION']
  ['left',      'COMPARE']
  ['left',      'LOGIC']
  ['nonassoc',  'INDENT', 'OUTDENT']
  ['right',     '=', ':', 'COMPOUND_ASSIGN', 'RETURN', 'THROW', 'EXTENDS']
  ['right',     'FORIN', 'FOROF', 'BY', 'WHEN']
  ['right',     'IF', 'ELSE', 'FOR', 'WHILE', 'UNTIL', 'LOOP', 'SUPER', 'CLASS']
  ['right',     'POST_IF']
]