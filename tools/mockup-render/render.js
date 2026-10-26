// 把 docs/assets/user-flow/source/ 里的页面设计源文件（.dc.html）导出成 PNG 截图。
// 用一个很小的模板解释器代替设计画布的运行时：只支持这些文件用到的 {{}}、<sc-for>、<sc-if>。
// 用法见 tools/README.md。
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '../..');
const srcDir = process.argv[2] || path.join(root, 'docs/assets/user-flow/source');
const outDir = process.argv[3] || path.join(root, 'docs/assets/user-flow');
const fontDir = process.env.NOTO_SC_DIR;
if (!fontDir) { console.error('请先设置 NOTO_SC_DIR（见 tools/README.md）'); process.exit(1); }
const boards = [
  ['Main', '01-home'], ['NewGame', '02-new-game'], ['Table', '03-table'],
  ['Capture', '04-capture'], ['Confirm', '05-confirm'], ['NotWin', '05b-not-win'],
  ['Details', '06-details'], ['Result', '07-result'], ['Ledger', '08-ledger'],
  ['Settle', '09-settle'], ['TileStyles', 'tile-styles']
];

const shim = `
window.renderDC = function (src) {
  const doc = new DOMParser().parseFromString(src, 'text/html');
  const xdc = doc.querySelector('x-dc');
  const helmet = xdc.querySelector('helmet');
  if (helmet) { helmet.querySelectorAll('style').forEach((s) => document.head.appendChild(s.cloneNode(true))); helmet.remove(); }
  class DCLogic { constructor(p) { this.props = p || {}; this.state = {}; } setState(s) { Object.assign(this.state, s); } }
  const code = doc.querySelector('script[data-dc-script]').textContent;
  const Component = new Function('DCLogic', code + '\\nreturn Component;')(DCLogic);
  const vals = new Component({}).renderVals();
  const HOLE = /\\{\\{\\s*([^}]+?)\\s*\\}\\}/g;
  const resolve = (p, scope) => {
    if (p === 'true') return true; if (p === 'false') return false;
    if (/^-?\\d+(\\.\\d+)?$/.test(p)) return Number(p);
    return p.split('.').reduce((o, k) => (o == null ? undefined : o[k]), scope);
  };
  const whole = (v) => { const m = /^\\s*\\{\\{\\s*([^}]+?)\\s*\\}\\}\\s*$/.exec(v || ''); return m && m[1]; };
  const sub = (s, scope) => s.replace(HOLE, (_, p) => { const v = resolve(p, scope); return v == null ? '' : String(v); });
  const render = (node, scope) => {
    if (node.nodeType === 3) return [document.createTextNode(sub(node.textContent, scope))];
    if (node.nodeType !== 1) return [];
    const kids = (sc) => Array.from(node.childNodes).flatMap((c) => render(c, sc));
    const tag = node.tagName.toLowerCase();
    if (tag === 'sc-for') {
      const list = resolve(whole(node.getAttribute('list')), scope) || [];
      const as = node.getAttribute('as');
      return list.flatMap((it, i) => kids({ ...scope, [as]: it, $index: i }));
    }
    if (tag === 'sc-if') return resolve(whole(node.getAttribute('value')), scope) ? kids(scope) : [];
    const el = document.importNode(node, false);
    for (const a of Array.from(node.attributes)) {
      el.removeAttribute(a.name);
      if (/^on/i.test(a.name) || a.name.startsWith('hint-')) continue;
      const w = whole(a.value);
      if (w) { const v = resolve(w, scope); if (v === false || v == null || typeof v === 'function') continue; el.setAttribute(a.name, String(v)); }
      else el.setAttribute(a.name, sub(a.value, scope));
    }
    kids(scope).forEach((k) => el.appendChild(k));
    return [el];
  };
  Array.from(xdc.childNodes).flatMap((c) => render(c, vals)).forEach((n) => document.body.appendChild(n));
};`;

(async () => {
  const fontCss = fs.readFileSync(path.join(fontDir, 'package/400.css'), 'utf8') + fs.readFileSync(path.join(fontDir, 'package/600.css'), 'utf8') + fs.readFileSync(path.join(fontDir, 'package/700.css'), 'utf8');
  const fontFace = fontCss.replace(/url\(\.\/files\//g, 'url(file://' + path.join(fontDir, 'package/files') + '/');
  const browser = await chromium.launch();
  const page = await browser.newPage({ deviceScaleFactor: 2, viewport: { width: 1000, height: 900 } });
  fs.mkdirSync(outDir, { recursive: true });
  for (const [name, out] of boards) {
    const src = fs.readFileSync(path.join(srcDir, name + '.dc.html'), 'utf8');
    const html = '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><style>' + fontFace +
      ' body{margin:0;background:#fff} body *{font-family:Inter,"Noto Sans SC",sans-serif !important}</style></head><body></body></html>';
    const tmp = path.join(outDir, '.tmp.html');
    fs.writeFileSync(tmp, html);
    await page.goto('file://' + tmp);
    await page.addScriptTag({ content: shim });
    await page.evaluate((s) => window.renderDC(s), src);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(400);
    await page.locator('body > div').first().screenshot({ path: path.join(outDir, out + '.png') });
    console.log('rendered', out);
  }
  fs.unlinkSync(path.join(outDir, '.tmp.html'));
  await browser.close();
})();
