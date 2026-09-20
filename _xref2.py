import re, os, glob
from collections import defaultdict

ROOT = r"C:\microcosme2"
os.chdir(ROOT)

KEYWORDS = set('''and array as asm begin case class const constructor destructor dispinterface div do downto
else end except exports file finalization finally for function goto if implementation in inherited
initialization inline interface is label library mod nil not object of or out packed procedure program
property raise record repeat resourcestring set shl shr string then threadvar try type unit until uses var
while with xor on at helper static unsafe readonly writeonly default stored index name reference deprecated
platform experimental protected public private published strict automated dispid absolute override virtual
dynamic reintroduce overload abstract sealed break continue exit halt abort assert assigned true false
create free destroy to downto shl shr forward message'''.split())

RTLFUNCS = set('''fillchar move sizeof typeof ord chr val str inc dec high low length setlength copy pos insert
delete trim trimleft trimright uppercase lowercase sametext comparetext comparestr ansipos ansiuppercase
abs sqr sqrt sin cos tan arcsin arctan arctan2 exp ln power int frac round trunc ceil floor sign pi
infinity nan maxint maxlongint maxint64 minint odd succ pred swap lo hi
inttostr strtoint strtointdef strtoint64 floattostr strtofloat format floattostrf currencytostr
datetostr timetostr strtodate strtotime encodedate encodetime decodedate decodetime now date time dayofweek
formatdatetime datetimetostr ifthen inrange ensureskip include exclude upcase intpower comparemem colortorgb
gettickcount gettickcount64 sleep beep random randomize paramstr min max
new dispose freemem getmem allocmem reallocmem addr
writeln write read readln assignfile closefile reset rewrite append
fileexists directoryexists extractfilepath extractfilename extractfileext changefileext expandfilename
deletefile copyfile renamefile forcedirectories createdir getcurrentdir setcurrentdir
succeeded failed raiselastoserror getlasterror setlasterror charinset
tobject tcomponent tform tcanvas tcolor tbitmap tpen tbrush tfont tgraphic tpicture tstrings tstringlist
tlist tthread tcriticalsection ttimer tstream tfilestream tmemorystream exception tpoint tpointf trect trectf
tsizet application screen clipboard printer mouse
result self sender
integer cardinal int64 uint64 byte word shortint smallint longint boolean char widechar ansichar pchar
pwidechar pansichar double single extended real comp currency variant olevariant text tdatetime tdate ttime
tshifstate tkey tcloseaction handle tag caption color
mr_yes mrok mrcancel mrno tarray tbytes tencoding tshiftstate tmousebutton tstopwatch tinifile
size point rect smallpoint tanh maxsingle pcardinal ereaderror fmopenread fmsharedenywrite fmcreate
twmerasebkgnd wm_erasebkgnd vk_f1 vk_f2 vk_f3 vk_f4 vk_space screentoclient keypreview
mbright mbleft ptinrect cafree poscreencenter doublebuffered onpaint onclose onmousedown
onmousemove onmouseup onmousewheel onresize onkeydown enabled terminate'''.split())

WINAPI = set('''enter leave freeandnil terminated priority waitfor createevent closehandle waitforsingleobject
waveoutopen waveoutclose waveoutprepareheader waveoutunprepareheader waveoutwrite waveoutreset
twavehdr twaveformatex psmallint pwavehdr whdr_done whdr_prepare
wave_format_pcm wave_mapper callback_event mmsyserr_noerror dword_ptr lpstr dword word bool handle
timebeginperiod timeendperiod timegettime
setwindowlongptr getwindowlongptr setlayeredwindowattributes getwindowrect getclientrect movewindow
showwindow setforegroundwindow getforegroundwindow postmessage sendmessage invalidaterect updaterect
getdc releasedc getstockobject createpen createbrushindirect selectobject deleteobject setbkmode
settextcolor setpixel moveto lineto rectangle roundrect ellipse polygon polyline fillrect framerect
textout drawtext drawtextex textextent gettextextentpoint32 bitblt stretchblt alphablend transparentblt
tblendfunction ac_src_over blendflags blendop alphaformat sourceconstantalpha
getsystemmetrics getdevicecaps createfontindirect setbrushorgex intersectcliprect
lo_word hi_word makelparam makewparam getcursorpos setcursorpos
tphigher tplower tnormal tpriority tpthreadpriority'''.split())

RTL = KEYWORDS | RTLFUNCS | WINAPI

def read_text(path):
    data = open(path, 'rb').read()
    if data.startswith(b'\xef\xbb\xbf'):
        return data[3:].decode('utf-8', errors='replace')
    try:
        return data.decode('utf-8')
    except UnicodeDecodeError:
        pass
    if b'\x00' in data[:200]:
        return data.decode('utf-16', errors='replace')
    return data.decode('cp1252', errors='replace')

def strip_code(src):
    out = []
    i, n = 0, len(src)
    def nl(chunk): return '\n' * chunk.count('\n')
    while i < n:
        c = src[i]
        if c == '{':
            j = src.find('}', i); j = (j + 1) if j != -1 else n
            out.append(nl(src[i:j])); i = j
        elif src.startswith('(*', i):
            j = src.find('*)', i); j = (j + 2) if j != -1 else n
            out.append(nl(src[i:j])); i = j
        elif src.startswith('//', i):
            j = src.find('\n', i); j = (j if j != -1 else n)
            out.append(nl(src[i:j])); i = j
        elif c == "'":
            j = i + 1
            while j < n and src[j] != "'": j += 1
            out.append("''" + nl(src[i:j+1])); i = j + 1
        elif c == '$':
            j = i + 1
            while j < n and src[j] in '0123456789abcdefABCDEF_': j += 1
            out.append('0'); i = j
        elif c == '#':
            j = i + 1
            while j < n and src[j].isdigit(): j += 1
            out.append("' '"); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)

UNIT_NAMES = {os.path.basename(f)[:-4].lower(): f for f in glob.glob('*.pas')}

class Unit:
    def __init__(self, name, path):
        self.name, self.path = name, path
        self.src = strip_code(read_text(path))
        # neutralize forward class declarations so the class-body regex
        # doesn't swallow the following class's members
        self.src = re.sub(r'=\s*(class|record|object)\s*;', r'=\1FWDDECL;', self.src)
        self.low = self.src.lower()
        self.exports, self.locals = set(), set()
        self.iface_uses, self.impl_uses = set(), set()
        self.signatures = defaultdict(list)
        self.impls = []
        self.classes = set()
        self.declared_methods = set()
        self.typemembers = defaultdict(set)
        self.parent = {}
        self.pointee = {}
        self.enummembers = defaultdict(set)
        self.vartypes = defaultdict(set)
        self._sections(); self._uses(); self._decls(); self._vartypes()

    def _sections(self):
        m_i = re.search(r'\binterface\b', self.low)
        m_p = re.search(r'^implementation\b', self.low, re.M) or re.search(r'\bimplementation\b', self.low)
        self.i0 = m_i.end() if m_i else 0
        self.p0 = m_p.start() if m_p else len(self.src)
        self.line = lambda pos: self.src.count('\n', 0, pos) + 1

    def _uses(self):
        m = re.search(r'\buses\b([^;]*);', self.src[self.i0:self.p0], re.S | re.I)
        if m: self.iface_uses = self._split_uses(m.group(1))
        m = re.search(r'\buses\b([^;]*);', self.src[self.p0:], re.S | re.I)
        if m: self.impl_uses = self._split_uses(m.group(1))

    @staticmethod
    def _split_uses(blob):
        out = set()
        for part in blob.split(','):
            part = re.sub(r"\bin\s+['\"][^'\"]*['\"]", '', part).strip().lower()
            part = part.split()[0] if part.split() else ''
            if part: out.add(part)
        return out

    def _decls(self):
        src, iface, impl = self.src, self.src[self.i0:self.p0], self.src[self.p0:]
        for m in re.finditer(r'([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:(?!=)', src):
            for nm in re.findall(r'[A-Za-z_]\w*', m.group(1)):
                self.locals.add(nm.lower())
        for m in re.finditer(r'([A-Za-z_]\w*)\s*=(?!=)', src):
            self.locals.add(m.group(1).lower())
        for m in re.finditer(r'\b(procedure|function|constructor|destructor)\s+([A-Za-z_]\w*)', src, re.I):
            self.locals.add(m.group(2).lower())
        for m in re.finditer(r'([A-Za-z_]\w*)\s*=\s*(?:packed\s+)?(class|record|object)\s*(?:\(\s*([A-Za-z_][\w.]*)\s*\))?(.*?)\bend\s*;', src, re.S | re.I):
            cls = m.group(1).lower()
            self.classes.add(cls)
            if m.group(3): self.parent[cls] = m.group(3).lower()
            body = m.group(4)
            mem = self.typemembers[cls]
            for mm in re.finditer(r'([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:(?!=)', body):
                for nm in re.findall(r'[A-Za-z_]\w*', mm.group(1)):
                    self.locals.add(nm.lower()); mem.add(nm.lower())
            for mm in re.finditer(r'\b(?:procedure|function|constructor|destructor)\s+([A-Za-z_]\w*)', body, re.I):
                self.locals.add(mm.group(1).lower()); mem.add(mm.group(1).lower())
                self.declared_methods.add((cls, mm.group(1).lower()))
            for mm in re.finditer(r'\bproperty\s+([A-Za-z_]\w*)', body, re.I):
                mem.add(mm.group(1).lower()); self.locals.add(mm.group(1).lower())
        for m in re.finditer(r'([A-Za-z_]\w*)\s*=\s*\^([A-Za-z_]\w*)', src):
            self.pointee[m.group(1).lower()] = m.group(2).lower()
        for m in re.finditer(r'([A-Za-z_]\w*)\s*=\s*\(([^()]*)\)', src):
            for nm in re.findall(r'[A-Za-z_]\w*', m.group(2)):
                self.locals.add(nm.lower())
        for m in re.finditer(r'([A-Za-z_]\w*)\s*=\s*\(([^()]*)\)', iface):
            en = m.group(1).lower()
            for nm in re.findall(r'[A-Za-z_]\w*', m.group(2)):
                self.exports.add(nm.lower()); self.enummembers[en].add(nm.lower())
        iface_locals = set()
        for m in re.finditer(r'([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:(?!=)', iface):
            for nm in re.findall(r'[A-Za-z_]\w*', m.group(1)):
                iface_locals.add(nm.lower())
        for m in re.finditer(r'([A-Za-z_]\w*)\s*=(?!=)', iface):
            iface_locals.add(m.group(1).lower())
        for m in re.finditer(r'\b(?:procedure|function|constructor|destructor)\s+([A-Za-z_]\w*)', iface, re.I):
            iface_locals.add(m.group(1).lower())
        self.exports = iface_locals
        for m in re.finditer(r'([A-Za-z_]\w*)\s*=\s*\(([^()]*)\)', iface):
            for nm in re.findall(r'[A-Za-z_]\w*', m.group(2)):
                self.exports.add(nm.lower())
        for m in re.finditer(r'\b(?:procedure|function)\s+([A-Za-z_]\w*)\s*\(', iface, re.I):
            name = m.group(1).lower()
            i = m.end(); depth = 1; j = i
            while j < len(iface) and depth:
                if iface[j] == '(': depth += 1
                elif iface[j] == ')': depth -= 1
                j += 1
            params = iface[i:j-1] if depth == 0 else ''
            depth = 0; groups = []; cur = ''
            for ch in params:
                if ch in '([{': depth += 1
                elif ch in ')]}': depth -= 1
                if ch == ';' and depth == 0:
                    groups.append(cur); cur = ''
                else:
                    cur += ch
            groups.append(cur)
            nparams = 0; ndefault = 0
            for g in groups:
                dd = 0; last = None
                for k, ch in enumerate(g):
                    if ch in '([{': dd += 1
                    elif ch in ')]}': dd -= 1
                    elif ch == ':' and dd == 0: last = k
                typed = g[last+1:] if last is not None else ''
                names = re.findall(r'[A-Za-z_]\w*', g[:last] if last is not None else '')
                names = [x for x in names if x.lower() not in ('out', 'const', 'var', 'in')]
                ndefault += typed.count('=')
                nparams += max(1, len(names)) if names else 1
            self.signatures[name].append((nparams - ndefault, nparams, self.line(self.i0 + m.start())))
        for m in re.finditer(r'\b(?:procedure|function|constructor|destructor)\s+([A-Za-z_]\w*)\.([A-Za-z_]\w*)', impl, re.I):
            self.impls.append((m.group(1).lower(), m.group(2).lower(), self.line(self.p0 + m.start())))

    def _vartypes(self):
        src = self.src
        gtab = defaultdict(set)
        heads = [(m.start(), m.group(0)) for m in re.finditer(
            r'^\s*(?:procedure|function|constructor|destructor)\s+[\w.]+', src, re.M | re.I)]
        first_head = heads[0][0] if heads else len(src)
        gseg = src[:first_head]
        for m in re.finditer(r'([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:\s*([A-Za-z_]\w*(?:<[^;]*>)?)', gseg):
            ty = m.group(2).split('<')[0].lower()
            for nm in re.findall(r'[A-Za-z_]\w*', m.group(1)):
                gtab[nm.lower()].add((ty, m.group(2).lower()))
        self.gtab = dict(gtab)
        self.ranges = []
        for idx, (pos, head) in enumerate(heads):
            end = heads[idx+1][0] if idx + 1 < len(heads) else len(src)
            seg = src[pos:end]
            tab = defaultdict(set)
            for m in re.finditer(r'([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s*:\s*([A-Za-z_]\w*(?:<[^;]*>)?)', seg):
                ty = m.group(2).split('<')[0].lower()
                for nm in re.findall(r'[A-Za-z_]\w*', m.group(1)):
                    tab[nm.lower()].add((ty, m.group(2).lower()))
            if re.match(r'\s*function\b', head, re.I):
                hm = re.match(r'\s*function\s+[\w.]+\s*(?:\(([^)]*)\))?\s*:\s*([A-Za-z_]\w*)', head, re.I | re.S)
                if not hm:  # multi-line header: scan forward a bit
                    hm = re.match(r'\s*function\s+[\w.]+[^:;]*:\s*([A-Za-z_]\w*)', src[pos:pos+400], re.I | re.S)
                if hm:
                    rt = (hm.group(2) if hm.groups() and len(hm.groups()) > 1 and hm.group(2) else hm.group(1)).lower()
                    tab['result'].add((rt, rt))
            self.ranges.append((pos, end, dict(tab)))
        self.vartypes = self.gtab

units = {}
for nm, path in UNIT_NAMES.items():
    units[nm] = Unit(nm, path)

export_map = defaultdict(set)
for u in units.values():
    for s in u.exports:
        export_map[s].add(u.name)
typemap = {}
for u in units.values():
    for t, mem in u.typemembers.items():
        typemap.setdefault(t, set()).update(mem)
enummap = {}
for u in units.values():
    for t, mem in u.enummembers.items():
        enummap.setdefault(t, set()).update(mem)
parentmap = {}
for u in units.values():
    parentmap.update(u.parent)
pointeemap = {}
for u in units.values():
    pointeemap.update(u.pointee)

BUILTIN_MEMBERS = {
 'tlist tstrings tstringlist tstream tfilestream tmemorystream tstopwatch tencoding': None,
}
BUILTIN = {
 'tlist': set('count items add insert remove delete clear contains indexof first last sort reverse toarray capacity trimexcess onnotify extract removeitem find locklist unlocklist'.split()),
 'tstrings': set('count items strings names values text add addstrings clear delete indexof indexofname insert loadfromfile savetofile sorted duplicates caseinsensitive objects beginupdate endupdate commatext delimiter delimitedtext quotechar namevalueseparator capacity first last onchange onchanging extract'.split()),
 'tstream': set('position size read write readbuffer writebuffer seek copyfrom readcomponent writecomponent free destroy handle'.split()),
 'tstopwatch': set('elapsed elapsedmilliseconds elapsedticks start stop restart reset startnew istrunning frequency'.split()),
 'tencoding': set('utf8 unicode ascii default getbytes getstring bigendianunicode'.split()),
}
for extra in ('tstringlist',):
    BUILTIN[extra] = BUILTIN['tstrings'] | BUILTIN['tlist']
for extra in ('tfilestream', 'tmemorystream'):
    BUILTIN[extra] = BUILTIN['tstream']

UNIVERSAL = set('create destroy free new classname classtype qualifiedclassname unitname inheritsfrom getinterface fieldaddress methodaddress tostring equals gethashcode afterconstruction beforedestruction dispatch defaulthandler freeinstance newinstance dispose'.split())

STRMEM = set('length substring toupper tolower contains startswith endswith indexof replace split trim isempty iswhitespace tointeger todouble toboolean chars join toupperinvariant tolowerinvariant remove padleft padright lastindexof compareto'.split())

issues = []
seen = set()
def flag(kind, msg):
    key = (kind, msg)
    if key in seen: return
    seen.add(key)
    issues.append(f"[{kind}] {msg}")

# ---- 1. bare identifier resolution ----
for u in units.values():
    avail_units = (u.iface_uses | u.impl_uses) - {''}
    uses_ranges = [(m.start(), m.end()) for m in re.finditer(r'\buses\b[^;]*;', u.src, re.S | re.I)]
    in_uses = lambda p: any(a <= p < b for a, b in uses_ranges)
    known_units = avail_units | {u.name} | set(UNIT_NAMES) | set('system sysutils windows winapi vcl math classes messages mmsystem syncobjs contnrs dateutils strutils variants typinfo shellapi clipbrd menus dialogs controls graphics forms stdctrls extctrls comctrls pngimage jpeg gifimg activex comobj registry inifiles ioutils types uitypes themes styles hash json threading diagnostics character generics collections gdipobj gdipapi gdiputil timeapi psapi imaging'.split())
    toks = [(m.group(0), m.start()) for m in re.finditer(r'[A-Za-z_]\w*', u.src)]
    for idx, (t, pos) in enumerate(toks):
        tl = t.lower()
        prev = toks[idx-1][0].lower() if idx else ''
        prev2 = toks[idx-2][0].lower() if idx > 1 else ''
        if prev == '.': continue
        if prev2 == '.' and prev not in ('in',): continue
        if pos > 0 and (u.src[pos-1].isdigit() or u.src[pos-1] == '.'): continue
        if in_uses(pos): continue
        if tl in RTL or tl in u.locals or tl in known_units: continue
        if tl in export_map:
            provs = export_map[tl]
            if not (provs & (avail_units | {u.name})):
                flag('USES', f"{u.name}.pas:{u.line(pos)} '{t}' comes from {sorted(provs)} — missing from uses")
            continue
        flag('UNKNOWN', f"{u.name}.pas:{u.line(pos)} bare identifier '{t}' declared nowhere")

# ---- 2. dotted member access on resolvable types ----
def ext_ancestor(t, depth=0):
    """True if type's parent chain leaves the project (VCL base etc.)."""
    if depth > 8: return True
    cur = parentmap.get(t)
    while cur and depth < 8:
        if cur not in typemap: return True
        cur = parentmap.get(cur)
        depth += 1
    return False

for u in units.values():
    vtypes = u.vartypes
    for m in re.finditer(r'\b([A-Za-z_]\w*)\s*(?:\.|\^)\s*([A-Za-z_]\w*)', u.src):
        v, mem = m.group(1), m.group(2)
        vl, ml = v.lower(), mem.lower()
        prevtok = u.src[max(0, m.start()-30):m.start()]
        if re.search(r'\b(inherited|procedure|function|property)\s*$', prevtok, re.I): continue
        if vl == 'self': continue
        if vl in enummap and ml in enummap[vl]: continue
        # per-scope var table for this position, falling back to globals
        cands = None
        for (a, b, tab) in u.ranges:
            if a <= m.start() < b:
                if vl in tab: cands = tab[vl]
                elif vl in u.gtab: cands = u.gtab[vl]
                break
        else:
            if vl in u.gtab: cands = u.gtab[vl]
        if not cands: continue
        resolvable = []
        for ty, full in cands:
            t = ty
            if t in pointeemap: t = pointeemap[t]
            if t in typemap or t in BUILTIN or t == 'string' or t.startswith('tlist<'):
                resolvable.append(t)
        if not resolvable: continue      # external type — cannot verify
        ok = False
        confident = True                  # all candidates project-pure (no VCL ancestor)
        for t in resolvable:
            if t in ('string',) or t.startswith('tlist<') or t in BUILTIN:
                confident = False
                if ml in BUILTIN.get(t, set()) or (t == 'string' and ml in STRMEM) \
                   or (t.startswith('tlist<') and ml in BUILTIN['tlist']):
                    ok = True; break
                continue
            chain = set()
            seen_t = set()
            cur = t
            while cur and cur not in seen_t:
                seen_t.add(cur)
                chain |= typemap.get(cur, set())
                cur = parentmap.get(cur, None)
            if ml in chain: ok = True; break
            if ext_ancestor(t): confident = False
        if ok: continue
        if ml in UNIVERSAL: continue
        if any(f.startswith('tlist<') for _, f in cands) and ml in BUILTIN['tlist']: continue
        if not confident: continue       # could be an inherited VCL member
        ln = u.line(m.start())
        flag('MEMBER', f"{u.name}.pas:{ln} '{v}.{mem}' — '{mem}' not in {sorted(set(ty for ty, _ in cands))}")

# ---- 3. method impl vs decl ----
for u in units.values():
    for (c, m, ln) in u.impls:
        if (c, m) not in u.declared_methods:
            if c not in u.classes:
                flag('IMPL', f"{u.name}.pas:{ln} {c}.{m} implemented but class not declared here")
            else:
                flag('IMPL', f"{u.name}.pas:{ln} {c}.{m} implemented but not declared in class")

issues.sort()
byid = defaultdict(list)
final = []
for line in issues:
    m = re.search(r"bare identifier '(\w+)'", line)
    if m:
        byid[m.group(1)].append(line)
    else:
        final.append(line)
for ident, lines in sorted(byid.items(), key=lambda kv: -len(kv[1])):
    final.append(f"[UNKNOWN:*] '{ident}' x{len(lines)} — e.g. {lines[0]}")
print('\n'.join(final) if final else 'CLEAN')
print(f"--- {len(final)} flags")
