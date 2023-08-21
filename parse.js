function parse(code) {
    function createFields(fields, body) {
        const output = [];
        for (let i = 0; i < fields.length; i++) {
            const field = fields[i];
            if (body.includes(`@${i + 1}`)) {
                output.push(`{:${field}, ${field}}`);
            } else {
                output.push(`:${field}`);
            }
        }

        return output.join(', ');
    }

    function createBody(fields, body) {
        for (let i = 0; i < fields.length; i++) {
            const field = fields[i];
            body = body.replaceAll(`@${i + 1}`, field);
        }

        return body;
    }

    return code.split('\n')
        .map(e => e.split('~>'))
        .map(([a, b]) => [a, b.split(' do ')])
        .map(([a, [b, c]]) => [a.trim(), b.trim().split(' '), c.trim().slice(0, -4)])
        .map(([name, fields, body]) => {
            return `defr ${name}(${createFields(fields, body)}), do: ${createBody(fields, body)}`
        })
        .join('\n');
}
