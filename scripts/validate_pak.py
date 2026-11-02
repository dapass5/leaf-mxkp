#!/usr/bin/env python3
"""Offline structural checks for the Leaf content-pak contract."""
import json, os, pathlib, stat, sys
root=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'pak')
manifest=json.loads((root/'pak.json').read_text(encoding='utf-8-sig'))
assert manifest['platform']=='mlp1'
assert manifest['min_leaf_version']
provides=manifest['provides']; assert provides['schema']==1
systems={s['id']:s for s in provides['systems']}; cores={c['id']:c for c in provides['cores']}
for sid,s in systems.items():
    assert s['default_core'] in cores, (sid,s['default_core'])
    for key in ('rom_root','image_root','icon_flat'):
        p=s[key]; assert not p.startswith('/') and '..' not in pathlib.PurePosixPath(p).parts
        if key=='icon_flat': assert (root/p).is_file(), p
for cid,c in cores.items():
    assert c['type']=='path'
    p=c['path']; assert not p.startswith('/') and '..' not in pathlib.PurePosixPath(p).parts
    target=root/p; assert target.is_file(), p
    assert (target.stat().st_mode & stat.S_IXUSR) or os.name == 'nt', p
contract=pathlib.Path(__file__).resolve().parent.parent/'build/leaf-contracts/contracts/leaf-content/scripts'
if contract.is_dir():
    sys.path.insert(0,str(contract))
    from content_model import validate_manifest
    reasons=validate_manifest(manifest,str(root.resolve()))
    assert not reasons, f'Leaf reference validator rejected manifest: {sorted(reasons)}'
print(f'valid Leaf pak: {manifest["name"]} ({len(systems)} system, {len(cores)} core)')
