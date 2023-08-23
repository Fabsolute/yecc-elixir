import {
    alt,
    apply,
    buildLexer,
    expectEOF,
    expectSingleResult,
    kleft,
    kright,
    opt_sc, rep_sc,
    rule,
    seq,
    tok,
    Token,
} from 'typescript-parsec';
import {ExDeclaration, ExRule, ExSymbol, SymbolType} from './types';
import {grammarToString} from './toYecc';
import fs from 'fs';

enum TokenKind {
    DOT,
    ARROW,
    VAR,
    ATOM, // todo
    INTEGER,
    RESERVED_WORD, // todo
    STRING, // todo
    COLON,
    FLOAT,
    CHAR, // todo
    RESERVED_SYMBOL, // todo
    SPACE
}

const lexer = buildLexer([
    [false, /^\s+/g, TokenKind.SPACE],
    [false, /^%.*/g, TokenKind.SPACE],
    [true, /^\d+/g, TokenKind.INTEGER],
    [true, /^\d+(\.\d+)?/g, TokenKind.FLOAT],
    [true, /^\./g, TokenKind.DOT],
    [true, /^->/g, TokenKind.ARROW],
    [true, /^:/g, TokenKind.COLON],
    [true, /^[A-Z][A-Za-z0-9_]*/g, TokenKind.VAR],
    [true, /^[a-z][A-Za-z0-9_]*/g, TokenKind.ATOM],
    [true, /^'.*?'/g, TokenKind.ATOM],
    [true, /^".*?"/g, TokenKind.STRING],
    [true, /^[{},\[\]|()-\\#<>$"']/g, TokenKind.RESERVED_SYMBOL],
]);

function applyDeclaration([head, body]: [ExSymbol, ExSymbol[]]): ExDeclaration {
    return {
        kind: 'declaration',
        data: {head, body},
    };
}

function applyRule(tokens: [ExSymbol, ExSymbol[], ExSymbol[] | undefined]): ExRule {
    return {
        kind: 'rule',
        data: {
            head: tokens[0],
            symbols: tokens[1],
            code: tokens[2],
        },
    };
}

// <factory service="doctrine.orm.read_only_bfc_entity_manager" method="getRepository" />


function applySymbol(token: Token<TokenKind>): ExSymbol {
    let type: SymbolType | undefined = undefined;
    switch (token.kind) {
        case TokenKind.VAR:
            type = SymbolType.VAR;
            break;
        case TokenKind.INTEGER:
            type = SymbolType.INTEGER;
            break;
        case TokenKind.ATOM:
            type = SymbolType.ATOM;
            break;
        case TokenKind.RESERVED_WORD:
            type = SymbolType.RESERVED_WORD;
            break;
        case TokenKind.FLOAT:
            type = SymbolType.FLOAT;
            break;
        case TokenKind.STRING:
            type = SymbolType.STRING;
            break;
        case TokenKind.CHAR:
            type = SymbolType.CHAR;
            break;
        case TokenKind.RESERVED_SYMBOL:
            type = SymbolType.RESERVED_SYMBOL;
            break;
        case TokenKind.ARROW:
            type = SymbolType.ARROW;
            break;
        case TokenKind.COLON:
            type = SymbolType.COLON;
            break;
    }

    if (!type) {
        throw 'bad symbol';
    }

    return {
        kind: type,
        data: token.text,
    };
}

const GRAMMAR = rule<TokenKind, (ExDeclaration | ExRule)[]>();
const DECLARATION = rule<TokenKind, ExDeclaration>();
const RULE = rule<TokenKind, ExRule>();
const SYMBOL = rule<TokenKind, ExSymbol>();
const SYMBOLS = rule<TokenKind, ExSymbol[]>();
const STRING = rule<TokenKind, ExSymbol>();
const STRINGS = rule<TokenKind, ExSymbol[]>();
const HEAD = rule<TokenKind, ExSymbol>();
const ATTACHED_CODE = rule<TokenKind, ExSymbol[] | undefined>();
const TOKENS = rule<TokenKind, ExSymbol[]>();
const TOKEN = rule<TokenKind, ExSymbol>();

GRAMMAR.setPattern(
    rep_sc(
        alt(
            DECLARATION,
            RULE,
        ),
    ),
);

DECLARATION.setPattern(
    kleft(
        apply(
            seq(
                SYMBOL,
                alt(
                    SYMBOLS,
                    STRINGS,
                ),
            ),
            applyDeclaration,
        ),
        tok(TokenKind.DOT),
    ),
);

RULE.setPattern(
    apply(
        seq(
            kleft(
                HEAD,
                tok(TokenKind.ARROW),
            ),
            SYMBOLS,
            kleft(
                ATTACHED_CODE,
                tok(TokenKind.DOT),
            ),
        ),
        applyRule,
    ),
);

SYMBOL.setPattern(
    apply(
        alt(
            tok(TokenKind.VAR),
            tok(TokenKind.ATOM),
            tok(TokenKind.INTEGER),
            tok(TokenKind.RESERVED_WORD),
        ),
        applySymbol,
    ),
);

SYMBOLS.setPattern(
    apply(seq(SYMBOL, rep_sc(SYMBOL)), ([a, b]) => [a, ...b]),
);

STRING.setPattern(
    apply(
        tok(TokenKind.STRING),
        applySymbol,
    ),
);

STRINGS.setPattern(
    apply(
        seq(STRING, rep_sc(STRING)),
        ([a, b]) => [a, ...b],
    ),
);

HEAD.setPattern(SYMBOL);

ATTACHED_CODE.setPattern(
    opt_sc(
        kright(
            tok(TokenKind.COLON),
            TOKENS,
        ),
    ),
);

TOKENS.setPattern(
    apply(seq(TOKEN, rep_sc(TOKEN)), (([a, b]) => [a, ...b])),
);

TOKEN.setPattern(
    apply(
        alt(
            tok(TokenKind.VAR),
            tok(TokenKind.ATOM),
            tok(TokenKind.FLOAT),
            tok(TokenKind.INTEGER),
            tok(TokenKind.STRING),
            tok(TokenKind.CHAR),
            tok(TokenKind.RESERVED_SYMBOL),
            tok(TokenKind.RESERVED_WORD),
            tok(TokenKind.ARROW),
            tok(TokenKind.COLON),
        ),
        applySymbol,
    ),
);

const code = fs.readFileSync(__dirname + '/file.yrl').toString();

let token = lexer.parse(code);

// do {
//     console.log({kind: token.kind, value: token.text});
//     token = token.next;
// } while (token);

fs.writeFileSync(__dirname + '/../lib/file.ex',
    grammarToString(
        expectSingleResult(expectEOF(GRAMMAR.parse(token))),
    ),
);
