//! Local time without a date library (localtime_r).

fn local() -> libc::tm {
    let t = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map_or(0, |d| d.as_secs()) as libc::time_t;
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    unsafe { libc::localtime_r(&t, &mut tm) };
    tm
}

/// (hour, minute, second)
pub fn now_hms() -> (u32, u32, u32) {
    let t = local();
    (t.tm_hour as u32, t.tm_min as u32, t.tm_sec as u32)
}

/// (year, month, day, weekday 0 = Sunday)
pub fn today() -> (u32, u32, u32, u32) {
    let t = local();
    ((t.tm_year + 1900) as u32, (t.tm_mon + 1) as u32, t.tm_mday as u32, t.tm_wday as u32)
}

/// Local (year, month, day, hour, minute, second) of a file time.
pub fn local_of(t: std::time::SystemTime) -> (u32, u32, u32, u32, u32, u32) {
    let s = t.duration_since(std::time::UNIX_EPOCH).map_or(0, |d| d.as_secs()) as libc::time_t;
    let mut tm: libc::tm = unsafe { std::mem::zeroed() };
    unsafe { libc::localtime_r(&s, &mut tm) };
    ((tm.tm_year + 1900) as u32, (tm.tm_mon + 1) as u32, tm.tm_mday as u32, tm.tm_hour as u32, tm.tm_min as u32,
        tm.tm_sec as u32)
}
