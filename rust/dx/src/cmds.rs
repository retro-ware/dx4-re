//! Command numbers of menu entries and keys, and the menu bar (English version of the DXMAIN menus).

use dxtui::menubar::{Item, Menu, MenuBar};

pub const HELP: u16 = 1;
pub const ABOUT: u16 = 2;
pub const STATUS: u16 = 3;
pub const ENV: u16 = 4;
pub const CALENDAR: u16 = 5;
pub const STOPWATCH: u16 = 6;
pub const SYSINFO: u16 = 7;
pub const KEYTEST: u16 = 8;
pub const QUIT: u16 = 9;

pub const USER_MENU: u16 = 20;
pub const EDIT_MENU: u16 = 21;

pub const VIEW: u16 = 30;
pub const EDIT: u16 = 31;
pub const HEXEDIT: u16 = 32;
pub const EDIT_NEW: u16 = 33;
pub const ATTRIB: u16 = 34;
pub const TOUCH: u16 = 35;
pub const FIND: u16 = 36;
pub const GREP: u16 = 37;
pub const COMPARE: u16 = 38;
pub const QCD: u16 = 39;
pub const SPLIT: u16 = 40;
pub const JOIN: u16 = 41;
pub const DUPES: u16 = 42;
pub const SYNC: u16 = 43;
pub const COPY: u16 = 44;
pub const RENMOV: u16 = 45;
pub const MKDIR: u16 = 46;
pub const DELETE: u16 = 47;
pub const EXT_VIEW: u16 = 48;
pub const INT_VIEW: u16 = 49;

pub const SWAP: u16 = 60;
pub const DIR_SIZES: u16 = 61;
pub const DRIVES: u16 = 62;
pub const DRIVE_STAT: u16 = 63;
pub const CALC: u16 = 64;
pub const ASCII: u16 = 65;
pub const HEXDEC: u16 = 66;
pub const QUICK: u16 = 67;
pub const NOTES: u16 = 68;
pub const HISTORY: u16 = 69;
pub const CLOCK: u16 = 70;
pub const SYSFILES: u16 = 71;

pub const PACK: u16 = 80;
pub const ARC_VIEW: u16 = 81;
pub const ARC_TEST: u16 = 82;
pub const UNPACK: u16 = 83;
pub const SHELL_SCREEN: u16 = 84;
pub const LAST_CMD: u16 = 85;
pub const FULL_SHELL: u16 = 86;

pub const CONFIG: u16 = 100;
pub const SAVER: u16 = 101;
pub const FILE_COLORS: u16 = 102;
pub const SAVE_AS: u16 = 103;
pub const LOAD_FROM: u16 = 104;
pub const RESET: u16 = 105;
pub const ASSOC: u16 = 106;
pub const QUICKVIEW: u16 = 107;
pub const LONG_NAMES: u16 = 108;
pub const LOAD: u16 = 109;
pub const SAVE: u16 = 110;
pub const HIDDEN: u16 = 111;
pub const VIEW3: u16 = 112;
pub const VIEW5: u16 = 113;
pub const SAVER_NOW: u16 = 114;
pub const LEFT_PLACE: u16 = 115;
pub const RIGHT_PLACE: u16 = 116;
pub const AGAIN: u16 = 117;
pub const MARK_DIRSIZES: u16 = 118;

pub fn menu_bar() -> MenuBar {
    let i = Item::new;
    let s = Item::sep;
    let menus = vec![
        Menu {
            title: "~Info".into(),
            items: vec![
                i("~Help", "F1", HELP),
                i("~About", "", ABOUT),
                i("~Program status", "", STATUS),
                i("~Environment", "", ENV),
                i("~Calendar", "", CALENDAR),
                i("~Stopwatches", "", STOPWATCH),
                i("S~ystem info", "", SYSINFO),
                i("~Key test", "", KEYTEST),
                s(),
                i("~Quit", "Alt-X/F10", QUIT),
            ],
        },
        Menu {
            title: "~Menu".into(),
            items: vec![i("~User menu", "F2", USER_MENU), i("~Edit entries", "Shift-F1", EDIT_MENU)],
        },
        Menu {
            title: "~File".into(),
            items: vec![
                i("~View", "F3", VIEW),
                i("~Edit", "F4", EDIT),
                i("~Hex editor", "F9", HEXEDIT),
                i("Edit ~new file", "Alt-F4", EDIT_NEW),
                s(),
                i("~Attributes", "Ctrl-F1", ATTRIB),
                i("~Time and date", "Ctrl-F2", TOUCH),
                s(),
                i("~Find files", "Alt-F7", FIND),
                i("Search te~xt in marked", "Alt-F8", GREP),
                i("~Compare directories", "Alt-F9", COMPARE),
                i("~Quick change dir", "Alt-F10", QCD),
                i("~Duplicate files", "", DUPES),
                i("S~ynchronize dirs", "", SYNC),
                s(),
                i("~Split", "Ctrl-F3", SPLIT),
                i("~Join", "Ctrl-F4", JOIN),
            ],
        },
        Menu {
            title: "~Options".into(),
            items: vec![
                i("Swap ~panels", "Alt-T", SWAP),
                i("Directory ~sizes", "Alt-V", DIR_SIZES),
                i("~Drive overview", "Alt-L", DRIVES),
                i("Drive s~tatistics", "Alt-S", DRIVE_STAT),
                s(),
                i("~Calculator", "Alt-R", CALC),
                i("~ASCII table", "Alt-A", ASCII),
                i("~Hex-dec-bin", "Alt-H", HEXDEC),
                i("~Quick menu", "Alt-C", QUICK),
                i("~Notes", "Alt-N", NOTES),
                i("Command ~history", "Alt-B", HISTORY),
                i("Time and dat~e", "Alt-Z", CLOCK),
                i("Edit s~ystem files", "Shift-F3", SYSFILES),
            ],
        },
        Menu {
            title: "~Pack+Shell".into(),
            items: vec![
                i("~Pack", "Ctrl-F5", PACK),
                i("~View archive", "Ctrl-F9", ARC_VIEW),
                i("~Test archive", "Ctrl-F8", ARC_TEST),
                i("~Unpack", "Ctrl-F10", UNPACK),
                s(),
                i("Shell ~screen", "Alt-F5", SHELL_SCREEN),
                i("~Last command", "Backspace", LAST_CMD),
                i("~Full screen shell", "Ctrl-O", FULL_SHELL),
            ],
        },
        Menu {
            title: "S~ettings".into(),
            items: vec![
                i("~Configuration", "Shift-F7", CONFIG),
                i("~Screen saver", "Shift-F8", SAVER),
                i("~File colours", "", FILE_COLORS),
                s(),
                i("~Long names on/off", "Alt-1", LONG_NAMES),
                i("~Quickview on/off", "Alt-2", QUICKVIEW),
                i("~Hidden files on/off", "Shift-F4", HIDDEN),
                i("~Point-and-shoot", "Shift-F2", ASSOC),
                s(),
                i("L~oad", "Shift-F9", LOAD),
                i("S~ave", "Shift-F10", SAVE),
                i("Load ~from...", "", LOAD_FROM),
                i("Save ~as...", "", SAVE_AS),
                i("~Reset", "", RESET),
            ],
        },
    ];
    let mut b = MenuBar::new(menus, 3);
    b.fg = 0;
    b.bg = 3;
    b.hot_fg = 4;
    b
}

/// Labels of the function key bar for no modifier / Shift / Ctrl / Alt.
pub const FKEYS: [[&str; 10]; 4] = [
    ["Help", "Menu", "View", "Edit", "Copy", "RenMv", "MkDir", "Delete", "HexEd", "Quit"],
    ["Entry", "Assoc", "SysEd", "Hiddn", "DSize", "", "Conf", "Saver", "Load", "Save"],
    ["Attr", "Touch", "Split", "Join", "Pack", "", "", "Test", "AView", "Unpak"],
    ["Left", "Right", "ExtVw", "NewEd", "Shell", "Again", "Find", "Grep", "Comp", "QCD"],
];

/// Command of function key n (1..=10) for modifier set `m` (0 none, 1 shift, 2 ctrl, 3 alt).
pub fn fkey_cmd(m: usize, n: usize) -> u16 {
    const T: [[u16; 10]; 4] = [
        [HELP, USER_MENU, VIEW, EDIT, COPY, RENMOV, MKDIR, DELETE, HEXEDIT, QUIT],
        [EDIT_MENU, ASSOC, SYSFILES, HIDDEN, MARK_DIRSIZES, 0, CONFIG, SAVER, LOAD, SAVE],
        [ATTRIB, TOUCH, SPLIT, JOIN, PACK, 0, 0, ARC_TEST, ARC_VIEW, UNPACK],
        [LEFT_PLACE, RIGHT_PLACE, EXT_VIEW, EDIT_NEW, SHELL_SCREEN, AGAIN, FIND, GREP, COMPARE, QCD],
    ];
    T[m][n - 1]
}
