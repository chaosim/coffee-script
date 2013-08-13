exports.identifier = (text, start) ->
  cursor = start
  switch text[cursor]
    when  '$', '_','a','b','c','d','e','f','g','h','i','j','k','l','m','n',\
           'o','p','q','r','s','t','u','v','w','x','y','z',\
           'A','B','C','D','E','F','G','H','I','J','K','L','M',\
           'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
      cursor++
      while 1
        switch text[cursor]
          when '$','_','0','1','2','3','4','5','6','7','8','9',\
                'a','b','c','d','e','f','g','h','i','j','k','l','m','n',\
                'o','p','q','r','s','t','u','v','w','x','y','z',\
                'A','B','C','D','E','F','G','H','I','J','K','L','M',\
                'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
            cursor++
  stop = cursor
  if stop==start then return
  w = keyword(start)
  if w and cursor==stop then undefined
  else cursor

number = (text, textLength,  start) ->
  cursor = start
  switch text[cursor]
    when '+', '-', '0','1','2','3','4','5','6','7','8','9'
      cursor++
  switch text[cursor++]
    when '0'
      switch [cursor++]
        when 'o'
          while 1
            switch [cursor]
              when  '0','1','2','3','4','5','6','7'
                cursor++
              when '8', '9'
                break
        when 'x'
          while 1
            switch [cursor]
              when  '0','1','2','3','4','5','6','7', '8'
                cursor++
              else break
        when 'b'
          while 1
            switch [cursor]
              when  '0','1'
                cursor++
              when '2','3','4','5','6','7','8','9'
                cursor++

exports.isdigit = (c) ->
  switch c
    when '0','1','2','3','4','5','6','7','8','9'
      true

exports.isletter = exports.isalpha = (c) ->
  switch c
    when 'a','b','c','d','e','f','g','h','i','j','k','l','m','n',\
        'o','p','q','r','s','t','u','v','w','x','y','z',\
        'A','B','C','D','E','F','G','H','I','J','K','L','M',\
        'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
      true

exports.islower = (c) ->
  switch c
    when 'a','b','c','d','e','f','g','h','i','j','k','l','m','n',\
         'o','p','q','r','s','t','u','v','w','x','y','z'
      true

exports.isupper = (c) ->
  switch c
    when  'A','B','C','D','E','F','G','H','I','J','K','L','M',\
          'N','O','P','Q','R','S','T','U','V','W','X','Y','Z'
      true

exports.wordNumMap = wordNumMap = {}
i = 1
for w in ['__bind', '__extends',  '__hasProp',  '__indexOf',  '__slice',  'break',  'by',  'case',
          'catch',  'class',  'const',  'continue',  'debugger',  'default',  'delete',  'do',  'else',
          'enum',  'export',  'extends',  'false',  'finally',  'for',  'function',  'if',  'implements',
          'import',  'in',  'instanceof',  'interface',  'let',  'loop',  'native',  'new',  'null',  'of',
          'package',  'private',  'protected',  'public',  'return',  'static',  'super',  'switch',
          'then',  'this',  'throw',  'true',  'try',  'typeof',  'undefined',  'unless',  'until',
          'var',  'void',  'when',  'while',  'with',  'yield']
  wordNumMap[w] = i++

exports.keyword = keyword = (text, start) ->
  cursor = start
  switch text[cursor++]
    when '_'
      if text[cursor++]=='_' then switch text[cursor++]
        when 'b' then if text.slice(cursor, cursor+=3)=='ind' then '__bind'
        when 'e' then if text.slice(cursor, cursor+=6)=='xtends' then  '__extends'
        when 'h' then if text.slice(cursor, cursor+=6)=='asProp' then  '__hasProp'
        when 'i' then if text.slice(cursor, cursor+=6)=='ndexOf' then  '__indexOf'
        when 's' then if text.slice(cursor, cursor+=4)=='lice' then  '__slice'
    when 'b'
      switch text[cursor++]
        when 'r' then if text.slice(cursor, cursor+=3)=='eak' then  'break'
        when 'y' then  'by'
    when 'c'
      switch text[cursor++]
        when 'a'
          switch text[cursor++]
            when 's' then if text[cursor++]=='e' then  'case'
            when 't' then if text.slice(cursor, cursor+=2)=='ch' then  'catch'
        when 'l' then if text.slice(cursor, cursor+=3)=='ass' then  'class'
        when 'o'
          if text[cursor++]=='n'
            switch text[cursor++]
              when 's' then if text[cursor++]=='t' then  'const'
              when 't' then if text.slice(cursor, cursor+=4)=='inue' then  'continue'
    when 'd'
      switch text[cursor++]
        when 'e'
          switch text[cursor++]
            when 'b' then if text.slice(cursor, cursor+=5)=='ugger' then  'debugger'
            when 'f' then if text.slice(cursor, cursor+=4)=='ault' then  'default'
            when 'l' then if text.slice(cursor, cursor+=3)=='ete' then  'delete'
        when 'o' then 'do'
    when 'e'
      switch text[cursor++]
        when 'l' then if text.slice(cursor, cursor+=2)=='se' then  'else'
        when 'n' then if text.slice(cursor, cursor+=2)=='um' then  'enum'
        when 'x'
          switch text[cursor++]
            when 'p' then if text.slice(cursor, cursor+=3)=='ort' then  'export'
            when 't' then if text.slice(cursor, cursor+=4)=='ends' then  'extends'
    when 'f'
      switch text[cursor++]
        when 'a' then if text.slice(cursor, cursor+=3)=='lse' then  'false'
        when 'i' then if text.slice(cursor, cursor+=5)=='nally' then  'finally'
        when 'o' then if text[cursor++]=='r' then 'for'
        when 'u' then if text.slice(cursor, cursor+=5)=='nction' then  'function'
    when 'i'
      switch text[cursor++]
        when 'f' then  'if'
        when 'm'
          switch text[cursor++]
            when 'p'
              switch text[cursor++]
                when 'l' then if text.slice(cursor, cursor+=6)=='ements' then  'implements'
                when 'o' then if text.slice(cursor, cursor+=2)=='rt' then  'import'
        when 'n'
          switch text[cursor++]
            when 's' then if text.slice(cursor, cursor+=7)=='tanceof' then  'instanceof'
            when 't' then if text.slice(cursor, cursor+=6)=='erface' then  'interface'
            else cursor--; 'in'
    when 'l'
      switch text[cursor++]
        when 'e' then if text[cursor++]=='t' then  'let'
        when 'o' then if text.slice(cursor, cursor+=2)=='op' then  'loop'
    when 'n'
      switch text[cursor++]
        when 'a' then if text.slice(cursor, cursor+=4)=='tive' then  'native'
        when 'e' then if text[cursor++]=='w' then  'new'
        when 'u' then if text.slice(cursor, cursor+=2)=='ll' then  'null'
    when 'o' then if text[cursor++]=='f' then  'of'
    when 'p'
      switch text[cursor++]
        when 'a' then if text.slice(cursor, cursor+=5)=='ckage' then  'package'
        when 'r'
          switch text[cursor++]
            when 'i' then if text.slice(cursor, cursor+=4)=='vate' then  'private'
            when 'o' then if text.slice(cursor, cursor+=6)=='tected' then  'protected'
        when 'u' then if text.slice(cursor, cursor+=4)=='blic' then  'blic'
    when 'r' then if text.slice(cursor, cursor+=5)=='eturn' then 'return'
    when 's'
      switch text[cursor++]
        when 't' then if text.slice(cursor, cursor+=4)=='atic' then  'static'
        when 'u' then if text.slice(cursor, cursor+=3)=='per' then  'super'
        when 'w' then if text.slice(cursor, cursor+=4)=='itch' then  'switch'
    when 't'
      switch text[cursor++]
        when 'h'
          switch text[cursor++]
            when 'e' then if text[cursor++]=='n' then  'then'
            when 'i' then if text[cursor++]=='s' then  'this'
            when 'r' then if text.slice(cursor, cursor+=2)=='ow' then  'throw'
        when 'r'
          switch text[cursor++]
            when 'u' then if text[cursor++]=='e' then  'true'
            when 'y' then  'try'
        when 'y' then if text.slice(cursor, cursor+=4)=='peof' then  'typeof'
    when 'u'
      switch text[cursor++]
        when 'n'
          switch text[cursor++]
            when 'd' then if text.slice(cursor, cursor+=6)=='efined' then  'undefined'
            when 'l' then if text.slice(cursor, cursor+=3)=='ess' then  'unless'
            when 't' then if text.slice(cursor, cursor+=2)=='il' then  'until'
    when 'v'
      switch text[cursor++]
        when 'a' then if text[cursor++]=='r' then  'var'
        when 'o' then if text.slice(cursor, cursor+=2)=='id' then  'void'
    when 'w'
      switch text[cursor++]
        when 'h'
          switch text[cursor++]
            when 'e' then if text[cursor++]=='n' then  'when'
            when 'i' then if text.slice(cursor, cursor+=3)=='le' then  'while'
        when 'i' then if text.slice(cursor, cursor+=2)=='th' then  'with'
    when 'w'then if text.slice(cursor, cursor+=4)=='ield' then  'yield'
