import { mkdirSync, writeFileSync, readFileSync } from 'node:fs';
import { Resvg } from '@resvg/resvg-js';
import opentype from 'opentype.js';

const out = 'website/public/brand';
mkdirSync(out, { recursive: true });
const font = opentype.parse(readFileSync('assets/brand/DM-Sans.ttf').buffer);
const blue = '#315da8', pale = '#93b8f5', ink = '#202938', dark = '#151b24', paper = '#f7f8fa';
// One source of geometry for every production asset. The left bar is saved state.
const shapes = {
  session: 'M24 8H32C46 8 56 18 56 32S46 56 32 56H24V48H32C41 48 48 41 48 32S41 16 32 16H24ZM8 8H16V56H8Z',
  continuity: 'M8 8H32C46 8 56 18 56 32S46 56 32 56H8V36H32V44H16V48H32C41 48 48 41 48 32S41 16 32 16H16V28H8Z',
  ledger: 'M8 8H28V16H16V48H28V56H8ZM36 8H56V56H36V48H48V16H36ZM24 28H40V36H24Z'
};
function svg(w, h, content, title = 'DASP — Durable Actor Session Protocol') {
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img"><title>${title}</title>${content}</svg>`;
}
function mark(color, name='session', x=0, y=0, scale=1) {
  return `<path fill="${color}" d="${shapes[name]}" transform="translate(${x} ${y}) scale(${scale})"/>`;
}
function text(label, x, y, size, color) {
  let paths = '';
  for (const letter of label) {
    const glyph = font.charToGlyph(letter);
    const path = glyph.getPath(x, y, size);
    path.fill = color;
    paths += path.toSVG(2);
    x += glyph.advanceWidth * size / font.unitsPerEm;
  }
  return paths;
}
function save(name, content) { writeFileSync(`${out}/${name}`, content); }
function png(name, content, width) {
  save(name, new Resvg(content, { fitTo: { mode: 'width', value: width } }).render().asPng());
}
for (const [name] of Object.entries(shapes)) {
  for (const [mode, accent, foreground] of [['light',blue,ink],['dark',pale,paper],['black','#000','#000'],['white','#fff','#fff']]) {
    const prefix = name === 'session' ? 'dasp' : `concept-${name}`;
    save(`${prefix}-mark-${mode}.svg`, svg(64,64,mark(accent,name)));
    save(`${prefix}-horizontal-${mode}.svg`, svg(248,64,mark(accent,name)+text('DASP',80,48,48,foreground)));
    save(`${prefix}-stacked-${mode}.svg`, svg(200,152,mark(accent,name,52,0,1.5)+text('DASP',30,142,44,foreground)));
  }
}
save('dasp-wordmark-light.svg', svg(168,64,text('DASP',0,48,48,ink)));
save('dasp-wordmark-dark.svg', svg(168,64,text('DASP',0,48,48,paper)));
const icon = svg(64,64,`<rect width="64" height="64" rx="12" fill="${blue}"/>`+mark('#fff','session',8,8,.75));
save('dasp-icon.svg',icon);
save('dasp-favicon.svg',icon);
for (const size of [16,32,48,180,192,512]) png(`dasp-icon-${size}.png`,icon,size);
png('dasp-mark-1024.png',svg(64,64,mark(blue)),1024);
// ICO with one PNG frame, supported by current browsers and desktop systems.
const icoPng = new Resvg(icon,{fitTo:{mode:'width',value:32}}).render().asPng();
const header = Buffer.alloc(22);
header.writeUInt16LE(1,2); header.writeUInt16LE(1,4);
header[6]=32; header[7]=32; header.writeUInt16LE(1,10); header.writeUInt16LE(32,12);
header.writeUInt32LE(icoPng.length,14); header.writeUInt32LE(22,18);
save('dasp-favicon.ico',Buffer.concat([header,icoPng]));
const og = svg(1200,630,
  `<rect width="1200" height="630" fill="${dark}"/>`+
  mark(pale,'session',72,58,1)+text('DASP',154,106,48,paper)+
  text('Durable Actor',72,270,76,paper)+text('Session Protocol',72,360,76,paper)+
  text('Commands. Saved outcomes. Recovery.',76,447,30,pale)+
  `<path d="M76 502H1124" stroke="#35465d"/>`+
  text('An open protocol for durable actors',76,556,23,'#b8c4d6')+
  mark(pale,'session',875,186,3.6));
save('dasp-social.svg',og);
png('dasp-social.png',og,1200);
save('site.webmanifest',JSON.stringify({
  name:'Durable Actor Session Protocol',short_name:'DASP',start_url:'/dasp/',scope:'/dasp/',
  display:'standalone',background_color:paper,theme_color:blue,
  icons:[192,512].map(size=>({src:`/dasp/brand/dasp-icon-${size}.png`,sizes:`${size}x${size}`,type:'image/png',purpose:'any'}))
},null,2)+'\n');
console.log('Built DASP brand assets, icons, and 1200 × 630 social preview.');
