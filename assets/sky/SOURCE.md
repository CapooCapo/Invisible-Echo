# Sky asset provenance

## Production star cover

- Asset: `night_starfield_2k.png`, generated equirectangular RGB star-cover texture.
- Generator: `tools/generate_night_sky_stars.py` (deterministic seed `4162026`; generated here with Python `3.14.7` and Pillow `12.3.0`).
- Output SHA-256: `def9e04a3b1f37c5950078c9356732d4de4ec8b102044594a280e270c4e5ec55`.
- License/provenance: project-authored procedural output; no third-party source or runtime dependency. Godot texture import has mipmaps enabled to soften point sampling at distance.
- Production use: additive `ProceduralSkyMaterial.sky_cover` in `scripts/visual/night_school_3d.gd`; the dark navy gradient is authored in that script. The texture is a sparse star field rather than an HDR panorama.

## Retained HDRI candidates

- `kloppenheim_02_puresky_2k.hdr`: **Kloppenheim 02 (Pure Sky)**, authors Greg Zaal (original), Jarod Guest (sky edit). Source: https://polyhaven.com/a/kloppenheim_02_puresky. Direct file: https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/kloppenheim_02_puresky_2k.hdr. CC0; Poly Haven permits use and redistribution in commercial products: https://polyhaven.com/license. Verified against Poly Haven files API MD5 `60bfe04a56522962933359cf4410f32c` (5,563,538 bytes). Retained from earlier work but **not used by the current production sky** because its bright disk remained distracting at low energy.
- `qwantani_night_puresky_2k.hdr`: **Qwantani Night (Pure Sky)**, authors Greg Zaal (photography), Jarod Guest (processing). Source: https://polyhaven.com/a/qwantani_night_puresky. Direct file: https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/2k/qwantani_night_puresky_2k.hdr. CC0. Download verified against Poly Haven files API MD5 `a2ef5b92f49f77b5bad15add5dad4feb` (5,461,210 bytes). **QA comparison candidate only; not used in production**, because its bright cyan-white horizon persisted in same-view captures at low energy.
