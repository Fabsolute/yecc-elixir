import {ExDeclaration, ExRule, ExSymbol, SymbolType} from './types';

let var_counter = 0;
const definedVars: Record<string, string> = {
    '"true"': 'ex_true',
    '"false"': 'ex_false',
    '"nil"': 'ex_nil',
    '"end"': 'ex_end',
    '"fn"': 'ex_fn',
    '"do"': 'ex_do',
    '","': 'pn_comma',
    '";"': 'pn_semicolon',
    '"("': 'pn_left_paren',
    '")"': 'pn_right_paren',
    '"["': 'pn_left_bracket',
    '"]"': 'pn_right_bracket',
    '"<<"': 'pn_left_shift',
    '">>"': 'pn_right_shift',
    '"{"': 'pn_left_brace',
    '"}"': 'pn_right_brace',
    '"."': 'pn_dot',
    '"%{}"': 'pn_map',
    '"%"': 'pn_struct',
};

export function grammarToString(grammar: (ExDeclaration | ExRule)[]) {
    let output: string[] = [];
    let last: string = '';
    for (const element of grammar) {
        if (element.kind === 'declaration') {
            output.push(declarationToString(element));
        }

        if (element.kind === 'rule') {
            const code = ruleToString(element);
            if (element.data.head.data !== last) {
                output.push(`\n${code}`);
            } else {
                output.push(code);
            }

            last = element.data.head.data;
        }
    }

    return output.join('\n');
}

function declarationToString({data: declaration}: ExDeclaration) {
    if (declaration.head.kind !== SymbolType.VAR) {
        return '# unknown declaration head';
    }

    const head = declaration.head.data;
    if (head === 'Nonterminals') {
        return `nonterminals [${atomListToString(declaration.body)}]`;
    }

    if (head === 'Terminals') {
        return `terminals [${atomListToString(declaration.body)}]`;
    }

    if (head === 'Rootsymbol') {
        return `root ${atomListToString(declaration.body)}`;
    }

    if (head === 'Expect') {
        return `expect ${atomToName(declaration.body[0].data)}`;
    }

    if (head === 'Left' || head === 'Right' || head === 'Nonassoc') {
        return `${head.toLowerCase()} ${atomToString(declaration.body[1].data)}, ${atomToName(declaration.body[0].data)}`;
    }

    return `unknown head: ${head}`;
}

function ruleToString({data: {head: {data: head}, symbols, code}}: ExRule) {
    const headWithParameters = `${head}(${atomsToParameterString(symbols, code)})`;
    const body = atomsToBodyString(symbols, code);
    const output = `defr ${headWithParameters}, do: ${body}`;
    if (output.length > 96 || body.includes('\n')) {
        return `defr ${headWithParameters} do\n${body}\nend`;
    }

    return output;
}

function atomListToString(atoms: ExSymbol[]) {
    const output: string[] = [];

    for (const atom of atoms) {
        output.push(atomToString(atom.data));
    }

    return output.join(', ');
}

function atomsToParameterString(symbols: ExSymbol[], code: ExSymbol[]) {
    const output: string[] = [];

    for (let i = 0; i < symbols.length; i++) {
        const symbol = symbols[i];
        if (isParameterUsed(i + 1, code)) {
            output.push(`{${atomToString(symbol.data)}, ${atomToName(symbol.data)}}`);
            continue;
        }

        output.push(atomToString(symbol.data));
    }
    return output.join(', ');
}

function atomsToBodyString(symbols: ExSymbol[], codeList: ExSymbol[]) {
    const output: string[] = [];

    let count = 0;
    for (const {data: code} of codeList) {
        if (/^'\$\d+'/.test(code)) {
            const num = parseInt(code.replace(/'\$(\d+)'/g, '$1')) - 1;
            output.push(atomToName(symbols[num].data));
            continue;
        }

        if (code === '{' || code === '(' || code === '[') {
            count++;
        }
        if (code === '}' || code === ')' || code === ']') {
            count--;
        }

        if (code === ',' && count === 0) {
            output.push('\n');
            continue;
        }

        if (code === '?') {
            continue;
        }

        if (code === '$') {
            output.push('?');
            continue;
        }

        if (code === 'do') {
            output.push(`:${code}`);
            continue;
        }

        if (/^'.*'$/.test(code)) {
            output.push(code.replace(/^'(.*)'$/, ':$1'));
            continue;
        }

        output.push(code);
    }

    return output.join('');
}

function atomToString(atom: string) {
    return `:${atom.replace(/'/g, '"')}`;
}

function atomToName(atom: string) {
    const atomName = atomToString(atom).replace(':', '');
    if (atomName.startsWith('"')) {
        if (!definedVars[atomName]) {
            var_counter++;
            definedVars[atomName] = `variable_${var_counter}`;
        }

        return definedVars[atomName];
    }

    return atomName;
}

function isParameterUsed(number: number, codeList: ExSymbol[]) {
    for (const code of codeList) {
        if (code.data === `'$${number}'`) {
            return true;
        }
    }

    return false;
}
