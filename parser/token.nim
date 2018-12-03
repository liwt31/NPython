from tables import newTable

type
  Token* {.pure.} = enum
    Endmarker
    Name
    Number
    String
    Newline
    Indent
    Dedent
    Lpar
    Rpar
    Lsqb
    Rsqb
    Colon
    Comma
    Semi
    Plus
    Minus
    Star
    Slash
    Vbar
    Amper
    Less
    Greater
    Equal
    Dot
    Percent
    Lbrace
    Rbrace
    Eqequal
    Notequal
    Lessequal
    Greaterequal
    Tilde
    Circumflex
    Leftshift
    Rightshift
    Doublestar
    Plusequal
    Minequal
    Starequal
    Slashequal
    Percentequal
    Amperequal
    Vbarequal
    Circumflexequal
    Leftshiftequal
    Rightshiftequal
    Doublestarequal
    Doubleslash
    Doubleslashequal
    At
    Atequal
    Rarrow
    Ellipsis
    Op
    Errortoken
    Comment
    Nl
    Encoding

let strTokenMap* = {
                   "(": Token.Lpar,
                   ")": Token.Rpar,
                   "[": Token.Lsqb,
                   "]": Token.Rsqb,
                   ":": Token.Colon,
                   ",": Token.Comma,
                   ";": Token.Semi,
                   "+": Token.Plus,
                   "-": Token.Minus,
                   "*": Token.Star,
                   "/": Token.Slash,
                   "|": Token.Vbar,
                   "&": Token.Amper,
                   "<": Token.Less,
                   ">": Token.Greater,
                   "=": Token.Equal,
                   ".": Token.Dot,
                   "%": Token.Percent,
                   "{": Token.Lbrace,
                   "}": Token.Rbrace,
                   "==": Token.Eqequal,
                   "!=": Token.Notequal,
                   "<=": Token.Lessequal,
                   ">=": Token.Greaterequal,
                   "~": Token.Tilde,
                   "^": Token.Circumflex,
                   "<<": Token.Leftshift,
                   ">>": Token.Rightshift,
                   "**": Token.Doublestar,
                   "+=": Token.Plusequal,
                   "-=": Token.Minequal,
                   "*=": Token.Starequal,
                   "/=": Token.Slashequal,
                   "%=": Token.Percentequal,
                   "&=": Token.Amperequal,
                   "|=": Token.Vbarequal,
                   "^=": Token.Circumflexequal,
                   "<<=": Token.Leftshiftequal,
                   ">>=": Token.Rightshiftequal,
                   "**=": Token.Doublestarequal,
                   "//": Token.Doubleslash,
                   "//=": Token.Doubleslashequal,
                   "@": Token.At,
                   "@=": Token.Atequal,
                   "->": Token.Rarrow,
                   "...": Token.Ellipsis
                   }.newTable
