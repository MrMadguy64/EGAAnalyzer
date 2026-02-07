# EGAAnalyzer
EGA VPT dump analyzer

Quick and dirty. That's why Lazarus is called RAD - because it's for rapid development! It has taken only one 1 day to make this project.

Supports both binary and text dumps. Text dump should contain hex values, separated by spaces. Like 00 0F A2, etc. Binary data requires begin and end offests to be specified. They can be any Pascal-specific numbers. I.e. hex values can be specified via $ symbol ($10 for example). Amount of video modes inside file is calculated as Size/0x40.

Uses .cfg files as source of configuration in order to aviod constantly filling it in manually. Use edit or browse button to specify config file.

Config file should contain >= 8 lines.

1) Instruction: TEXTABS, TEXTREL, BINABS, BINREL - text or binary dump, absolute or relative (to config) path.
2) Path to file - either absolute or relative to config's path
3) Dump start offset - for binary data only, can be any Pascal number, $00 for hex values for example.
4) Dump end offset - for binary data only, offset of next byte after end of data, so End-Start=Size.
5) List of 4 dot clocks in Hz. Used to calculate estimated horizotal and vertical frequences.
