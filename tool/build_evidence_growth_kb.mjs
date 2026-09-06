// Usage: node tool/build_evidence_growth_kb.mjs <pdftotext-layout-output>
// Emits reviewed, page-addressable source records. It never writes files.
import fs from 'node:fs';
const pages = fs.readFileSync(process.argv[2], 'utf8').split('\f');
const lines = pages.flatMap((page, i) => page.split('\n').map(text => ({text, page: i + 1})))
  .filter(l => !/Harvard Positive Psychology|《哈佛幸福课》六大模块成长闭环知识库/.test(l.text));
const heading = /^\s*(?:(?:信念|目标|行动|失败与完美主义|复盘|改变)｜)?([BGAFRC](?:-AUDIT-\d{2}|-EXT2?-\d{2}|\d{2}))｜(.+)/;
const starts = lines.flatMap((l, i) => heading.test(l.text) ? [i] : []);
const labels = /^(?:原案例\/实验|为什么属于六模块|引导\s*\/\s*提醒|边界|产品化动作|原文直译|原文\/课堂核心|证据类型|课程结论|Tal 的结论|Tal 的引导|Tal\/课程的引导|Tal 的提醒|提醒\s*\/\s*(?:警告|误用边界)|为什么这样|为什么值得补|为什么|课程证据(?:\s*\/\s*(?:论证|原例))?|Tal 怎么教你做|怎么教你做|强启发\/应用价值|现实触发条件|闭环连接|课程来源|知识库触发语|Tal 母库连接|外部专家理论|融合角色|Tal 体系尚未充分解决的问题|新增机制|外部证据基础|重要边界\s*\/\s*防误用|新的诊断问题|新的行动方法|AI\s*触发条件|闭环位置|正式入库建议|专家\s*\/\s*学科|专家延伸Ⅰ连接|为什么第二层才需要它)(?:[：｜]|\s{2,})/;
const cards = [];
for (let s=0;s<starts.length;s++) {
  const from=starts[s], to=starts[s+1]??lines.length;
  const match=lines[from].text.match(heading);
  const originalId=match[1];
  if (cards.some(c=>c.originalId===originalId)) continue;
  const block=lines.slice(from,to);
  const fields={}; let key='title'; fields.title=match[2].trim();
  let lastPage=lines[from].page;
  for (const line of block.slice(1)) {
    const text=line.text.trim();
    if (/^(?:模块\s*[一二三四五六0-9]|补充审计｜|v3\.5｜|新的总闭环｜|统一使用规则|Tal 课堂原文|\d+\.\s)/.test(text)) break;
    const field=text.match(labels);
    if (field) {
      key=field[0].replace(/[：｜]\s*$/, '').trim();
      fields[key]=(fields[key]??'')+text.slice(field[0].length).trim();
    } else if (text) { fields[key]+=(fields[key]?' ':'')+text; }
    if(text) lastPage=line.page;
  }
  const pick=(...names)=>names.map(n=>Object.entries(fields).find(([k])=>k.replace(/\s/g,'')===n.replace(/\s/g,''))?.[1]).find(Boolean)??'';
  const claim=pick('课程结论','Tal 的结论','外部专家理论','为什么属于六模块');
  const howTo=pick('Tal 怎么教你做','怎么教你做','新的行动方法','产品化动作');
  if (!claim || !howTo) continue;
  const title=fields.title;
  const context=pick('Tal 的引导','Tal/课程的引导','Tal 母库连接','引导 / 提醒');
  const mechanism=pick('为什么这样','为什么','新增机制','为什么值得补','为什么属于六模块');
  const boundary=pick('Tal 的提醒','提醒 / 警告','提醒 / 误用边界','重要边界/防误用','边界');
  const story=pick('课程证据','课程证据/论证','课程证据 / 原例','外部证据基础','原案例/实验');
  const locator=pick('课程来源','证据类型','闭环位置');
  cards.push({originalId,title,claim,howTo,context,mechanism,boundary,story,
    trigger:pick('现实触发条件','AI 触发条件','新的诊断问题'),
    sourceClass:originalId.includes('EXT2')?'K_EXT2':originalId.includes('EXT')?'K_EXT1':'K_TAL',
    pages:Array.from({length:lastPage-lines[from].page+1},(_,i)=>lines[from].page+i),
    locator,fields});
}
process.stdout.write(JSON.stringify(cards));
