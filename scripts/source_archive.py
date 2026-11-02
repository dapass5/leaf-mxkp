"""Archive exact fetched sources and this pak's build and runtime changes."""
from pathlib import Path
import tarfile, io
root=Path(__file__).resolve().parent.parent
out=root/'build/dist/mkxp-z-corresponding-source.tar.gz'
out.parent.mkdir(exist_ok=True,parents=True)
def keep(info):
    parts=Path(info.name).parts
    if any(part in parts for part in ('.git','__pycache__','packagecache','sdl2_image','SDL_ttf-release-2.0.18')): return None
    return info
with tarfile.open(out,'w:gz',compresslevel=3) as tar:
    for name in ('Makefile','README.md','.gitattributes','docker','docs','scripts','patches','pak','tests'):
        tar.add(root/name,arcname='mkxp-z-leaf/'+name,filter=keep)
    tar.add(root/'build/mkxp-z-src',arcname='mkxp-z-leaf/build/mkxp-z-src',filter=keep)
    revision=b'f02d586624dc53de373889cc16d9b1516da0a3a5\n'
    marker=tarfile.TarInfo('mkxp-z-leaf/build/mkxp-z-src/leaf-source-commit')
    marker.size=len(revision)
    tar.addfile(marker,io.BytesIO(revision))
print(out)
