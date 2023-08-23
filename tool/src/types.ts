export enum SymbolType {
    VAR = 'var',
    INTEGER = 'integer',
    ATOM = 'atom',
    RESERVED_WORD = 'reserved_word',
    FLOAT = 'float',
    STRING = 'string',
    CHAR = 'char',
    RESERVED_SYMBOL = 'reserved_symbol',
    ARROW = 'arrow',
    COLON = 'colon',
}

type Node<T extends string, K> = {
    kind: T;
    data: K;
};

export type ExSymbol = Node<SymbolType, string>;
export type ExDeclaration = Node<'declaration', { head: ExSymbol; body: ExSymbol[]; }>;
export type ExRule = Node<'rule', { head: ExSymbol; symbols: ExSymbol[]; code: ExSymbol[] | undefined }>;
