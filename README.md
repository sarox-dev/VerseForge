# VerseForge

VerseForge is an unfinished desktop music companion built with Godot and Python, exploring music information, lyrics and audio visualization. I worked on it for about a year without AI assistance. I eventually stopped developing it because I came to believe there was no demand for this particular product; I also did not market it or reach its intended audience, so that belief was not validated by a marketing test. This repository preserves the project as a portfolio of what I attempted to build.

## Opening the project

Open `VerseForge/project.godot` in Godot 4.5. This is an archived development snapshot, not a finished or maintained release. The original Python backend uses Windows-specific media APIs and starts from Godot using `python` from PATH. Its dependencies include `websockets`, `pydantic`, `winsdk`, `pygetwindow`, `pystray`, `Pillow`, `soundcard`, `numpy`, and `scipy`; compatible versions have not been verified. FFmpeg and FFprobe are expected as Windows executables for video functionality. A lyrics database is not included, so lyrics lookup will not have the original data.

The project may require additional assets or configuration to run correctly; it has not been verified in Godot in this snapshot. Linux support is not established.

## Assets and licensing

Some included fonts, sounds, and theme assets may belong to third parties. Their origins and redistribution terms have not yet been verified. Review them before publishing or distributing this repository. No open-source license has yet been chosen for the project's own code.
