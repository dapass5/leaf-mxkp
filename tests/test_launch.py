import json, os, pathlib, shutil, subprocess, tempfile
repo=pathlib.Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory() as tmp:
    base=pathlib.Path(tmp)
    runtime=base/'pak'; (runtime/'bin').mkdir(parents=True)
    launcher=runtime/'launch.sh'; shutil.copyfile(repo/'pak/emulators/mkxp-z/launch.sh',launcher)
    stub=runtime/'bin/mkxp-z'
    stub.write_text('#!/bin/sh\nprintf "%s\\n" "$PWD" "$XDG_DATA_HOME" "$@" "$MKXPZ_LEAF_GAME_CONFIG" "$MKXPZ_LEAF_FULLSCREEN" "$MKXPZ_LEAF_KEYMAP" > "$MKXPZ_CAPTURE"\n')
    stub.chmod(0o755)
    card=base/'card'
    for p in ('Roms','Saves','User','Logs'): (card/p).mkdir(parents=True)
    game=card/'Roms/MKXPZ/quoted " game'; game.mkdir(parents=True)
    entry=game/'Example.mkxp'; entry.touch()
    env=dict(os.environ,ROMS_PATH=str(card/'Roms'),SAVES_PATH=str(card/'Saves'),USERDATA_PATH=str(card/'User'),LOGS_PATH=str(card/'Logs'),MKXPZ_CAPTURE=str(base/'capture'))
    def run(path): return subprocess.run(['sh',str(launcher),str(path)],env=env,capture_output=True,text=True)
    result=run(entry); assert result.returncode==0,result.stderr
    lines=(base/'capture').read_text().splitlines()
    cfg=json.loads((pathlib.Path(lines[0])/'mkxp.json').read_text())
    assert cfg['gameFolder']==str(game)
    assert cfg['dataPathOrg']=='mkxp-z'
    assert lines[1]==str(card/'Saves')
    assert lines[3]==str(game/'mkxp.json')
    assert lines[4]=='1','Leaf fullscreen policy missing at exec handoff'
    assert lines[5]=='','controller keyboard mapping should be opt-in per game'
    key=cfg['dataPathApp']
    profile=pathlib.Path(lines[0])/'controller.keys'
    profile.write_text('a=Z\n')
    result=run(entry); assert result.returncode==0,result.stderr
    assert (base/'capture').read_text().splitlines()[5]==str(profile)
    moved=base/'remounted'; card.rename(moved)
    for variable,folder in [('ROMS_PATH','Roms'),('SAVES_PATH','Saves'),('USERDATA_PATH','User'),('LOGS_PATH','Logs')]: env[variable]=str(moved/folder)
    entry=moved/entry.relative_to(card)
    result=run(entry); assert result.returncode==0,result.stderr
    lines=(base/'capture').read_text().splitlines()
    cfg=json.loads((pathlib.Path(lines[0])/'mkxp.json').read_text())
    assert cfg['dataPathApp']==key,'save identity changed when card remounted'
    assert lines[3]==str(entry.parent/'mkxp.json'),'game config path did not follow remount'
    assert lines[5]==str(moved/profile.relative_to(card)),'controller profile did not follow remount'
    assert run('relative.mkxp').returncode!=0
    assert run(base).returncode!=0
print('launcher: exec, JSON quoting, SD remount and invalid paths passed')
