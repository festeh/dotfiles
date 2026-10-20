// Pure search policy. Catalog fields are normalized once, never on every key.
function normalize(value) {
    return String(value || "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase();
}

function prepare(rows) {
    return rows.map(row => Object.assign({}, row, {
        _title: normalize(row.title),
        _search: normalize([row.title, row.detail, row.keywords].join(" "))
    }));
}

function score(text, word) {
    const exact = text.indexOf(word);
    if (exact >= 0)
        return 100 + (exact === 0 ? 35 : /[\s\-_/\.]/.test(text[exact - 1]) ? 20 : 0) - Math.min(exact, 60) * 0.2;
    let cursor = 0, previous = -1, result = 0;
    for (let i = 0; i < word.length; ++i) {
        const found = text.indexOf(word[i], cursor);
        if (found < 0) return -1;
        result += 5 + (found === previous + 1 ? 8 : 0)
            + (found === 0 || /[\s\-_/\.]/.test(text[found - 1]) ? 8 : 0)
            - Math.min(found - cursor, 20) * 0.5;
        previous = found;
        cursor = found + 1;
    }
    // Subsequence matches always stay below contiguous matches.
    return Math.min(85, result / Math.max(word.length, 1) * 5);
}

function rank(rows, query) {
    const words = normalize(query).trim().split(/\s+/).filter(Boolean);
    if (!words.length) return rows.slice();
    const matches = [];
    for (let index = 0; index < rows.length; ++index) {
        const row = rows[index];
        let total = 0, valid = true;
        for (const word of words) {
            const title = score(row._title, word);
            const all = score(row._search, word);
            if (all < 0) { valid = false; break; }
            total += Math.max(title < 0 ? -1 : title + 15, all);
        }
        if (valid) matches.push({row: row, quality: Math.floor(total / 8), index: index});
    }
    matches.sort((a, b) => b.quality - a.quality
        || (b.row.usage || 0) - (a.row.usage || 0) || a.index - b.index);
    return matches.map(match => match.row);
}

if (typeof module !== "undefined") module.exports = {normalize, prepare, score, rank};
