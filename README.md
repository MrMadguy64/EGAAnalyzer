# EGAAnalyzer
EGA VPT dump analyzer

Quick and dirty. That's why Lazarus is called RAD - because it's for rapid development! It has taken only one 1 day to make this project.

Supports both binary and text dumps. Text dump should contain hex values, separated by spaces. Like 00 0F A2, etc. Binary data requires begin and end offests to be specified. They can be any Pascal-specific numbers. I.e. hex values can be specified via $ symbol ($10 for example). Amount of video modes inside file is calculated as Size/0x40.

Uses .cfg files as source of configuration in order to aviod constantly filling it in manually. Use edit or browse button to specify config file.

Config file should contain >= 8 lines.

1) Instruction: TEXTABS, TEXTREL, BINABS, BINREL - text or binary dump, absolute or relative (to config) path.
2) Path to file - either absolute or relative to config's path
3) Dump start offset - for binary data only, can be any Pascal string, $00 for hex values for example.
4) Dump end offset - for binary data only, offset of next byte after end of data, so End-Start=Size.
5) List of 4 dot clocks in Hz. Used to calculate estimated horizotal and vertical frequences.

**License:**

Software can be used for free for personal non-commercial purpose only. Any purpose, that involves explicit or implicit revenue, including indirect one (in case of budget or government organizations, educational purposes, etc.) - is allowed only after buying commercial license.

Any form of reverse-engineering is forbidden, including but not limited to debugging, decompiling, disassembling.

**License philosophy:**

Programmers should be professionals, not just enthusiasts, who have to provide unrelated services in order to earn money. If one uses my work to earn money - then he should share part of his revenue with me. If you earn money via clogging nails, then why do you think hammer should be free for you? Buy it! I've put my effort into making tool for you to earn money. And it's like law of energy conservation. Every drop of sweat should pay off. It's not fair, if some tool is used to earn billions of dollars, while it's author should be enthusiast, who can count on sporadic donations only. This includes new threat - AI. For now it isn't well regulated. Free projects can be used for AI training, that can be treated as commercial educational purposes, as goal of such training - is to earn profits then, while devaluing initial author's effort.

**Warranty disclaimer:** 

You use this software at your own risk. It's provided "as is" without any express or implied warranty of any kind, including warranties of merchantability or fitness for any particular purpose. Author isn't liable for any direct, indirect, incidental, special, exemplary, or consequential damage, caused by using this software.
