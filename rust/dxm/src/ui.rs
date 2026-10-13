//! Drawing. Layout follows the original 80×25 screen (group bar on top, 3×7 grid of program buttons,
//! key hints at the bottom); colours follow its cyan/grey scheme.

use crate::app::*;
use crate::menu::ITEMS;
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Paragraph};
use ratatui::Frame;

const BAR: Style = Style::new().fg(Color::Black).bg(Color::Cyan);
const DESK: Style = Style::new().fg(Color::Black).bg(Color::Gray);
const BUTTON: Style = Style::new().fg(Color::White).bg(Color::DarkGray);
const FOCUS: Style = Style::new().fg(Color::Yellow).bg(Color::Black).add_modifier(Modifier::BOLD);
const DIALOG: Style = Style::new().fg(Color::LightCyan).bg(Color::Blue);
const SELECT: Style = Style::new().fg(Color::Black).bg(Color::Green);
const HOT: Style = Style::new().fg(Color::Red);

fn centered(area: Rect, w: u16, h: u16) -> Rect {
    let w = w.min(area.width);
    let h = h.min(area.height);
    Rect::new(area.x + (area.width - w) / 2, area.y + (area.height - h) / 2, w, h)
}

/// Text with the letter after '~' (or at `hot`) in the hotkey colour.
fn hot_line(text: &str, base: Style) -> Line<'static> {
    let mut spans = vec![];
    let mut chars = text.chars();
    let mut plain = String::new();
    while let Some(c) = chars.next() {
        if c == '~' {
            if let Some(h) = chars.next() {
                spans.push(Span::styled(std::mem::take(&mut plain), base));
                spans.push(Span::styled(h.to_string(), base.patch(HOT)));
            }
        } else {
            plain.push(c);
        }
    }
    spans.push(Span::styled(plain, base));
    Line::from(spans)
}

/// Marks the first occurrence of the hotkey letter.
fn menu_line(text: &str, key: char, base: Style) -> Line<'static> {
    match text.char_indices().find(|(_, c)| crate::menu::locase(*c) == key) {
        Some((i, c)) => Line::from(vec![
            Span::styled(text[..i].to_string(), base),
            Span::styled(c.to_string(), base.patch(HOT)),
            Span::styled(text[i + c.len_utf8()..].to_string(), base),
        ]),
        None => Line::styled(text.to_string(), base),
    }
}

fn dialog(f: &mut Frame, area: Rect, title: &str) -> Rect {
    f.render_widget(Clear, area);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .title(title.to_string())
        .style(DIALOG);
    let inner = block.inner(area);
    f.render_widget(block, area);
    inner
}

fn list(f: &mut Frame, area: Rect, lines: &[String], sel: usize, sel_style: Style) {
    let top = sel.saturating_sub(area.height as usize - 1);
    let out: Vec<Line> = lines
        .iter()
        .enumerate()
        .skip(top)
        .take(area.height as usize)
        .map(|(i, l)| Line::styled(l.clone(), if i == sel { sel_style } else { DIALOG }))
        .collect();
    f.render_widget(Paragraph::new(out), area);
}

fn field_line(label: &str, fld: &Field, focused: bool) -> Line<'static> {
    let mut text = fld.text.clone();
    if focused {
        let b = text.char_indices().nth(fld.pos).map_or(text.len(), |(i, _)| i);
        text.insert(b, '▏');
    }
    Line::from(vec![
        Span::styled(format!("{label:<8}"), DIALOG),
        Span::styled(format!(" {text:<w$}", w = fld.max + 1), if focused { FOCUS } else { BUTTON }),
    ])
}

pub fn draw(f: &mut Frame, app: &mut App) {
    let full = f.area();
    let area = centered(full, 80, 25);
    f.render_widget(Block::default().style(DESK), full);
    app.hit_items.clear();
    app.hit_bar.clear();

    // Group bar; "Verwaltung" (admin) sits at the right like in the original.
    let bar = Rect::new(area.x, area.y, area.width, 1);
    f.render_widget(Block::default().style(BAR), bar);
    let mut x = area.x + 3;
    for (g, group) in app.menu.groups.iter().enumerate() {
        let label = format!(" {} ", group.name);
        let w = group.label().chars().count() as u16 + 2;
        if x + w > area.x + 66 {
            break; // the bar is full; PgUp/PgDn still reach the remaining groups
        }
        let r = Rect::new(x, area.y, w, 1);
        let style = if g == app.group { BAR.bg(Color::Green) } else { BAR };
        f.render_widget(Paragraph::new(hot_line(&label, style)), r);
        app.hit_bar.push((r, Some(g)));
        x += w;
    }
    let admin = Rect::new(area.x + 66, area.y, 12, 1);
    f.render_widget(Paragraph::new(hot_line(" ~Verwaltung ", BAR)), admin);
    app.hit_bar.push((admin, None));

    // Button grid inside a frame.
    let frame = Rect::new(area.x + 3, area.y + 1, 74.min(area.width.saturating_sub(3)), 23.min(area.height - 1));
    f.render_widget(
        Block::default().borders(Borders::ALL).border_type(BorderType::Double).style(DESK.fg(Color::White)),
        frame,
    );
    for row in 0..ROWS {
        let y = area.y + 3 + row as u16 * 3;
        if y < area.y + area.height {
            f.render_widget(Paragraph::new(format!("F{}", row + 1)).style(DESK), Rect::new(area.x, y, 2, 1));
        }
    }
    if !app.menu.groups.is_empty() {
        for i in 0..ITEMS {
            let (col, row) = (i / ROWS, i % ROWS);
            let r = Rect::new(area.x + 5 + col as u16 * 24, area.y + 2 + row as u16 * 3, 20, 3);
            if r.bottom() > area.bottom() || r.right() > area.right() {
                continue;
            }
            let it = app.item(i);
            let style = if i == app.cur { FOCUS } else { BUTTON };
            let block = Block::default().borders(Borders::ALL).border_type(BorderType::Rounded).style(style);
            f.render_widget(
                Paragraph::new(it.name.clone()).alignment(ratatui::layout::Alignment::Center).block(block),
                r,
            );
            app.hit_items.push((r, i));
        }
    }

    let hints = Rect::new(area.x, area.y + area.height - 1, area.width, 1);
    f.render_widget(
        Paragraph::new(" ◄◄ ►► Gruppe   F1..F7 / Alt- / Strg- = Start   Einfg = Neu   F9 = Verwaltung   Esc")
            .style(BAR),
        hints,
    );

    for p in &app.popups {
        draw_popup(f, area, app, p);
    }
}

fn draw_popup(f: &mut Frame, area: Rect, app: &App, p: &Popup) {
    match p {
        Popup::Message(a, b) => {
            let w = a.chars().count().max(b.chars().count()) as u16 + 6;
            let inner = dialog(f, centered(area, w, 6), "");
            f.render_widget(
                Paragraph::new(vec![Line::from(a.clone()), Line::from(b.clone()), Line::from(""), Line::from("[ OK ]")])
                    .alignment(ratatui::layout::Alignment::Center),
                inner,
            );
        }
        Popup::Admin { sel } => {
            let inner = dialog(f, Rect::new(area.x + 61, area.y + 1, 17, 13), "");
            let lines: Vec<Line> = ADMIN
                .iter()
                .zip(ADMIN_HEADINGS)
                .enumerate()
                .map(|(i, (e, h))| match e {
                    Some((t, k)) => menu_line(t, *k, if i == *sel { SELECT } else { DIALOG }),
                    None => Line::styled(h, DIALOG),
                })
                .collect();
            f.render_widget(Paragraph::new(lines), inner);
        }
        Popup::ItemMenu { item, sel } => {
            let inner = dialog(f, item_popup(area, *item, 15, 8), "");
            let lines: Vec<Line> = ITEM_MENU
                .iter()
                .enumerate()
                .map(|(i, (t, k))| menu_line(t, *k, if i == *sel { SELECT } else { DIALOG }))
                .collect();
            f.render_widget(Paragraph::new(lines), inner);
        }
        Popup::Separator { item, sel } => {
            let inner = dialog(f, item_popup(area, *item, 18, 8), " Trenner ");
            let lines: Vec<String> = SEPARATORS.iter().map(|c| c.to_string().repeat(16)).collect();
            list(f, inner, &lines, *sel, SELECT);
        }
        Popup::Swap { from, target } => {
            let msg = format!("    Eintrag '{}' vertauschen: Zielschalter wählen, Return = Tauschen", app.item(*from).name);
            f.render_widget(Paragraph::new(msg).style(BAR.fg(Color::Yellow)), Rect::new(area.x, area.y, area.width, 1));
            if let Some((r, _)) = app.hit_items.iter().find(|(_, i)| i == target) {
                f.render_widget(Block::default().borders(Borders::ALL).border_type(BorderType::Thick).style(SELECT), *r);
            }
        }
        Popup::Confirm { text, yes, .. } => {
            let inner = dialog(f, centered(area, text.chars().count() as u16 + 8, 5), "");
            let b = |t: &str, on: bool| Span::styled(t.to_string(), if on { FOCUS } else { BUTTON });
            f.render_widget(
                Paragraph::new(vec![
                    Line::from(text.clone()),
                    Line::from(""),
                    Line::from(vec![b("   Ja   ", *yes), Span::raw("   "), b("  Nein  ", !*yes)]),
                ])
                .alignment(ratatui::layout::Alignment::Center),
                inner,
            );
        }
        Popup::AddGroup { field } => {
            let inner = dialog(f, centered(area, 55, 8), " Hinzufügen eines neuen Menüpunktes ");
            f.render_widget(
                Paragraph::new(vec![
                    Line::from(""),
                    field_line("Neuer Menüpunkt:", field, true),
                    Line::from(""),
                    Line::from("  Eine Tilde vor einem Buchstaben gleich Hotkey!"),
                    Line::from(vec![Span::raw("  Bsp.: Eingabe von \"~Test\" ergibt im Menü ==> "), Span::styled("T", HOT), Span::raw("est")]),
                ]),
                inner,
            );
        }
        Popup::GroupList { mode, sel } => {
            let title = match mode {
                GroupListMode::Delete => " Gruppe löschen ",
                GroupListMode::Rename => " Gruppe umbenennen ",
            };
            let inner = dialog(f, centered(area, 28, 17), title);
            let lines: Vec<String> = app.menu.groups.iter().map(|g| format!(" {}", g.label())).collect();
            list(f, inner, &lines, *sel, SELECT);
        }
        Popup::RenameGroup { field, .. } => {
            let inner = dialog(f, centered(area, 36, 3), " Neuer Name ");
            f.render_widget(Paragraph::new(field_line("", field, true)), inner);
        }
        Popup::SortGroups { cur, grabbed } => {
            let inner = dialog(f, centered(area, 24, 19), " Gruppen sortieren ");
            let lines: Vec<String> = app.menu.groups.iter().map(|g| format!(" {}", g.label())).collect();
            list(f, inner, &lines, *cur, if *grabbed { FOCUS } else { SELECT });
            sort_hint(f, area);
        }
        Popup::SortItems { cur, grabbed } => {
            let inner = dialog(f, centered(area, 24, 23), " Sortieren ");
            let lines: Vec<String> = (0..ITEMS).map(|i| format!(" {}", app.item(i).name)).collect();
            list(f, inner, &lines, *cur, if *grabbed { FOCUS } else { SELECT });
            sort_hint(f, area);
        }
        Popup::EditItem { name, prog, chdir, focus, .. } => {
            let inner = dialog(f, centered(area, 92.min(area.width), 8), " Eintrag bearbeiten ");
            let check = format!("[{}] Verzeichniswechsel", if *chdir { 'X' } else { ' ' });
            f.render_widget(
                Paragraph::new(vec![
                    Line::from(""),
                    field_line("Name", name, *focus == 0),
                    Line::from(""),
                    field_line("Datei", prog, *focus == 1),
                    Line::from(""),
                    Line::styled(format!("         {check}"), if *focus == 2 { FOCUS } else { DIALOG }),
                ]),
                inner,
            );
            f.render_widget(
                Paragraph::new(" Tab = Feld   Leertaste = Ankreuzen   Return = OK   Esc = Abbruch").style(BAR),
                Rect::new(area.x, area.y + area.height - 1, area.width, 1),
            );
        }
        Popup::EditGroup { sel } => {
            let g = &app.menu.groups[app.group];
            let inner = dialog(f, Rect::new(area.x + 3, area.y + 1, 74, 23), &format!(" Benutzermenüverwaltung  Aktuelle Gruppe: {} ", g.label()));
            let lines: Vec<String> = g
                .items
                .iter()
                .enumerate()
                .map(|(i, it)| format!(" {:2}. {:<18}  {}", i + 1, it.name, it.prog))
                .collect();
            list(f, Rect::new(inner.x, inner.y + 1, inner.width, inner.height - 2), &lines, *sel, SELECT);
            f.render_widget(
                Paragraph::new(menu_line(
                    "   Einfügen (Einfg)    Umbenennen (Return)    Löschen (Entf)    Fertig (Esc)",
                    'e',
                    DIALOG,
                )),
                Rect::new(inner.x, inner.y + inner.height - 1, inner.width, 1),
            );
        }
        Popup::Pick { picker, .. } => {
            let inner = dialog(f, centered(area, 46, 20), " Programm wählen ");
            f.render_widget(
                Paragraph::new(picker.dir.display().to_string()).style(DIALOG.fg(Color::Yellow)),
                Rect::new(inner.x, inner.y, inner.width, 1),
            );
            let lines: Vec<String> = picker
                .entries
                .iter()
                .map(|e| if e.dir { format!(" [{}]", e.name) } else { format!(" {}", e.name) })
                .collect();
            list(f, Rect::new(inner.x, inner.y + 1, inner.width, inner.height - 2), &lines, picker.sel, SELECT);
            f.render_widget(
                Paragraph::new("Angezeigt wird: *.exe;*.bat;*.com und Programme").style(DIALOG),
                Rect::new(inner.x, inner.y + inner.height - 1, inner.width, 1),
            );
        }
        Popup::PlaceFile { item, path, name, chdir } => {
            let inner = dialog(f, centered(area, 60, 10), " Eintragen oder Einfügen der Datei ");
            f.render_widget(
                Paragraph::new(vec![
                    Line::styled(path.clone(), DIALOG.fg(Color::Yellow)),
                    Line::from(format!("in das Benutzermenü an Stelle {} unter dem", item + 1)),
                    Line::from(""),
                    field_line("Namen:", name, true),
                    Line::from(format!("         [{}] Verzeichniswechsel (Alt-V)", if *chdir { 'X' } else { ' ' })),
                    Line::from(""),
                    Line::from("  Einfg = Einfügen   Return = Eintragen   Esc = Abbrechen"),
                ]),
                inner,
            );
        }
    }
}

fn sort_hint(f: &mut Frame, area: Rect) {
    f.render_widget(
        Paragraph::new("       <Return> = Auswahl/Setzen  <Cursor> = Verschieben  <Esc> = Ende").style(FOCUS),
        Rect::new(area.x, area.y + area.height - 1, area.width, 1),
    );
}

/// The entry menu opens next to the button it belongs to.
fn item_popup(area: Rect, item: usize, w: u16, h: u16) -> Rect {
    let (col, row) = (item / ROWS, item % ROWS);
    let x = area.x + 8 + col as u16 * 24;
    let y = (area.y + 4 + row as u16 * 3).min(area.y + area.height.saturating_sub(h));
    Rect::new(x, y, w, h).intersection(area)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::MenuPos;
    use crate::menu::{Group, Item, Menu};
    use ratatui::backend::TestBackend;
    use ratatui::Terminal;

    pub fn screen(app: &mut App) -> String {
        let mut t = Terminal::new(TestBackend::new(80, 25)).unwrap();
        t.draw(|f| draw(f, app)).unwrap();
        let b = t.backend().buffer();
        (0..25).map(|y| (0..80).map(|x| b[(x, y)].symbol()).collect::<String>() + "\n").collect()
    }

    #[test]
    fn main_screen() {
        let mut m = Menu::default();
        m.groups.push(Group::new("~Spiele"));
        m.groups.push(Group::new("~Tools"));
        m.groups[0].items[0] = Item::for_program("C:\\GAMES\\TETRIS.EXE");
        m.groups[0].items[8] = Item::separator('─');
        let dir = std::env::temp_dir();
        let mut app = App::new(Some(m), MenuPos { group: 0, item: 0 }, dir.join("x.dat"), dir);
        let s = screen(&mut app);
        println!("{s}");
        assert!(s.contains("Spiele") && s.contains("Verwaltung") && s.contains("TETRIS"));
        app.popups.push(Popup::Admin { sel: 1 });
        println!("{}", screen(&mut app));
    }
}
