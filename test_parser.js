const fs = require('fs');
const t = fs.readFileSync('naver_theme.html', 'utf8');
const rx = /<a href="\/sise\/sise_group_detail.naver\?type=theme&no=\d+">([^<]+)<\/a>/g;
const links = [];
let m;
while ((m = rx.exec(t)) !== null) {
    links.push(m[1]);
}
console.log(links.slice(0, 20));
