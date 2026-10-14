//! Screen saver hook; the saver itself is in dxtui.

use crate::Dxm;

impl Dxm {
    pub fn screen_saver(&mut self) {
        dxtui::saver::screen_saver(&mut self.ui, &self.password);
    }
}
