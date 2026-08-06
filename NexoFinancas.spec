# -*- mode: python ; coding: utf-8 -*-
from pathlib import Path

root = Path(SPEC).resolve().parent
a = Analysis(
    [str(root / "desktop.py")],
    pathex=[str(root)],
    binaries=[],
    datas=[(str(root / "templates"), "templates"), (str(root / "static"), "static"), (str(root / "schema.sql"), ".")],
    hiddenimports=[], hookspath=[], hooksconfig={}, runtime_hooks=[], excludes=["gunicorn"], noarchive=False, optimize=1,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz, a.scripts, a.binaries, a.datas, [], name="NexoFinancas", debug=False,
    bootloader_ignore_signals=False, strip=False, upx=True, console=False,
    disable_windowed_traceback=False, argv_emulation=False, target_arch=None,
    codesign_identity=None, entitlements_file=None,
    icon=str(root / "native" / "windows" / "runner" / "resources" / "app_icon.ico"),
)
