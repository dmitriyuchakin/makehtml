# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['docx2html.py'],
    pathex=[],
    binaries=[],
    datas=[],
    hiddenimports=['docx', 'docx.shared', 'docx.oxml', 'docx.text', 'docx.table', 'lxml', 'lxml.etree', 'lxml._elementpath'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='docx2html',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
