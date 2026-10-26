"""Turn a Claude Code session export into a readable markdown history.

Usage (from the repo root, after the app's session Export puts a zip in Downloads):
    unzip the export somewhere outside the repo, then
    py -3 -I tools/transcript_to_md.py <export>/transcript.jsonl docs/history/session-NN-topic.md "Session NN: title (date)" [--chat-only]
--chat-only keeps just the conversation: the user's messages, their answers to Claude's
multiple-choice questions, and Claude's final reply each turn (no tool notes, no progress
chatter). That's the part a later session needs to read between the lines.
Read the result before committing it: it is published to GitHub.
"""
import json,sys,re
args=[a for a in sys.argv[1:] if not a.startswith('--')]
chat_only='--chat-only' in sys.argv
src,dst=args[0],args[1]
title=args[2] if len(args)>2 else "Session history"
out=["# "+title,"",
"Cleaned transcript of a Claude Code session: the user's messages and Claude's replies.",
("Only the conversation is kept: Claude's final reply each turn, with no tool calls, tool output or system text."
 if chat_only else "Tool calls are shown as one-line notes; hidden reasoning, tool output and system text are left out."),
"Read it for *how the user thinks*: what they reacted to, what they picked, what they pushed back on.",""]
turn=[]          # chat-only: Claude's text blocks this turn; only the last (the final reply) is kept
asks=set()       # ids of Claude's multiple-choice questions, to keep the user's answers
def flush():
    global turn
    if chat_only and turn: out.extend(["","### 🤖 Claude","",turn[-1],""])
    turn=[]
SKIP_TOOLS={'mcp__ccd_turn__update_plan','mcp__ccd_turn__wrap_up','ToolSearch'}
# C:\Users\name, /c/Users/name, and the C--Users-name form in Claude's folder names
HOME=re.compile(r'(?:[A-Za-z]:|/[A-Za-z])[\\/]+Users[\\/]+[^\\/\s`]+|\b[A-Za-z]--Users-[^\\/\s`-]+',re.I)
def scrub(t,cwd):
    """The repo is public: make paths repo-relative and hide the home folder (it holds the Windows user name)."""
    if cwd:
        for form in(cwd,cwd.replace('\\','/')):   # the project path, written with either slash
            for sep in('\\','/'): t=t.replace(form+sep,'')
            t=t.replace(form,'<project folder>')
        t=t.replace(re.sub(r'[^A-Za-z0-9]','-',cwd),'<project>')  # Claude's folder names spell out the repo's path
    return HOME.sub('~',t)
def note_path(p,cwd):
    """A file outside the repo (temp files and so on) is shown by its name only."""
    p=scrub(p,cwd)
    return re.split(r'[\\/]',p)[-1] if re.match(r'~|[A-Za-z]:|/',p) else p
def clean_user(t):
    t=re.sub(r'<system-reminder>.*?</system-reminder>','',t,flags=re.S)
    t=re.sub(r'</?pasted_content[^>]*>','',t)
    return t.strip()
last=None
for line in open(src,encoding='utf-8'):
    d=json.loads(line)
    cwd=d.get('cwd','')
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
            flush()
            out+=["","---","","## 🧑 User","",scrub(txt,cwd),""]; last='user'
        elif t=='user' and bt=='tool_result' and b.get('tool_use_id') in asks:
            r=b.get('content')
            r=r if isinstance(r,str) else " ".join(x.get('text','') for x in r if isinstance(x,dict))
            r=re.sub(r'\s*You can now continue.*$','',r,flags=re.S).strip()
            flush()
            out+=["","---","","## 🧑 User (answering Claude's multiple-choice question)","",scrub(r,cwd),""]; last='user'
        elif t=='assistant' and bt=='text' and b['text'].strip():
            if chat_only: turn.append(scrub(b['text'].strip(),cwd)); continue
            if last!='assistant': out+=["","### 🤖 Claude",""]
            out+=[scrub(b['text'].strip(),cwd),""]; last='assistant'
        elif t=='assistant' and bt=='tool_use':
            n=b['name']
            if n=='AskUserQuestion':
                asks.add(b.get('id'))
                if chat_only:
                    for q in b.get('input',{}).get('questions',[]):
                        opts=" / ".join(o.get('label','') for o in q.get('options',[]))
                        turn.append(scrub(f"(Asked: {q.get('question','')} Options: {opts})",cwd))
            if chat_only or n in SKIP_TOOLS: continue
            inp=b.get('input',{})
            desc=inp.get('description') or (note_path(inp['file_path'],cwd) if inp.get('file_path') else '') or inp.get('query') or ''
            if last!='assistant': out+=["","### 🤖 Claude",""]
            out.append(f"> _[{n}] {scrub(str(desc),cwd)[:120]}_"); last='assistant'
flush()
open(dst,'w',encoding='utf-8',newline='\n').write("\n".join(out)+"\n")
print(len(out))
