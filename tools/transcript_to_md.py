"""Turn a Claude Code session export into a readable markdown history.

Usage (from the repo root, after the app's session Export puts a zip in Downloads):
    unzip the export somewhere outside the repo, then
    py -3 -I tools/transcript_to_md.py <export>/transcript.jsonl docs/history/session-NN-topic.md "Session NN: title (date)"
Read the result before committing it: it is published to GitHub.
"""
import json,sys,re
src,dst=sys.argv[1],sys.argv[2]
title=sys.argv[3] if len(sys.argv)>3 else "Session history"
out=["# "+title,"",
"Cleaned transcript of a Claude Code session: the user's messages and Claude's replies.",
"Tool calls are shown as one-line notes; hidden reasoning, tool output and system text are left out.",
"Read it for *how the user thinks*: what they reacted to, what they picked, what they pushed back on.",""]
SKIP_TOOLS={'mcp__ccd_turn__update_plan','mcp__ccd_turn__wrap_up','ToolSearch'}
def clean_user(t):
    t=re.sub(r'<system-reminder>.*?</system-reminder>','',t,flags=re.S)
    t=re.sub(r'</?pasted_content[^>]*>','',t)
    return t.strip()
last=None
for line in open(src,encoding='utf-8'):
    d=json.loads(line)
    if d.get('isMeta') or d.get('isSidechain'): continue
    t=d.get('type')
    if t not in('user','assistant'): continue
    c=d.get('message',{}).get('content')
    blocks=[{'type':'text','text':c}] if isinstance(c,str) else c
    for b in blocks:
        bt=b.get('type')
        if t=='user' and bt=='text':
            txt=clean_user(b['text'])
            if not txt or txt.startswith(('[SYSTEM NOTIFICATION','Another Claude session','<task-notification','<agent-message')) or txt=='Tool loaded.' or 'side-sessions-event' in txt: continue
            out+=["","---","","## 🧑 User","",txt,""]; last='user'
        elif t=='assistant' and bt=='text' and b['text'].strip():
            if last!='assistant': out+=["","### 🤖 Claude",""]
            out+=[b['text'].strip(),""]; last='assistant'
        elif t=='assistant' and bt=='tool_use':
            n=b['name']
            if n in SKIP_TOOLS: continue
            inp=b.get('input',{})
            desc=inp.get('description') or inp.get('file_path') or inp.get('query') or ''
            if last!='assistant': out+=["","### 🤖 Claude",""]
            out.append(f"> _[{n}] {str(desc)[:120]}_"); last='assistant'
open(dst,'w',encoding='utf-8',newline='\n').write("\n".join(out)+"\n")
print(len(out))
