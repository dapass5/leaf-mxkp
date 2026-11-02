"""Fail on wrong architecture, host build paths, or unresolved SDK libraries."""
import json, os, pathlib, re, subprocess, sys
binary=pathlib.Path(sys.argv[1])
readelf=os.environ.get('READELF','aarch64-buildroot-linux-gnu-readelf')
sysroot=pathlib.Path(os.environ['SYSROOT'])
def read(flag,p): return subprocess.check_output([readelf,flag,str(p)],text=True)
header=read('-h',binary)
assert 'AArch64' in header,'not an AArch64 ELF'
assert '/lib/ld-linux-aarch64.so.1' in read('-l',binary),'unexpected ELF interpreter'
report={'architecture':'AArch64','glibc_ceiling':'2.38','dependencies':{}}
queue=[binary]; seen=set()
while queue:
    path=queue.pop()
    if path.name in seen: continue
    seen.add(path.name)
    dynamic=read('-d',path)
    for value in re.findall(r'\((?:RUNPATH|RPATH)\).*?\[(.*?)\]',dynamic):
        assert not any(p.startswith('/') for p in value.split(':')),(path,value)
    needed=re.findall(r'\(NEEDED\).*?\[(.*?)\]',dynamic)
    versions=re.findall(r'GLIBC_([0-9.]+)',read('-V',path))
    assert all(tuple(map(int,v.split('.')))<=(2,38) for v in versions),(path,versions)
    report['dependencies'][path.name]=needed
    for lib in needed:
        matches=[sysroot/'lib'/lib,sysroot/'usr/lib'/lib]
        found=next((p for p in matches if p.is_file()),None)
        assert found is not None,f'{path.name}: missing SDK runtime library {lib}'
        queue.append(found)
print(json.dumps(report,indent=2))
