//! Help viewer hook (Help.ShowHelp); the help text is built into dxtui.

use dxtui::ui::Ui;
use std::path::Path;

pub fn show_help(ui: &mut Ui, _home: &Path, page: usize) {
    dxtui::help::show_help(ui, page);
}
