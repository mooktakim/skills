//! Calendar dates as day numbers, with no time zone database: notes carry
//! plain YYYY-MM-DD dates, and log entries are named by their UTC date.

use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

/// Days since 1970-01-01 for a proleptic Gregorian date (Howard Hinnant's
/// days_from_civil).
pub fn days_from_civil(year: i64, month: u32, day: u32) -> i64 {
    let y = if month <= 2 { year - 1 } else { year };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let m = month as i64;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + day as i64 - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

/// The date of a day number, as (year, month, day).
pub fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let month = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (if month <= 2 { yoe + era * 400 + 1 } else { yoe + era * 400 }, month, day)
}

/// The day number of a strict YYYY-MM-DD date that exists in the calendar.
pub fn parse(text: &str) -> Option<i64> {
    let b = text.as_bytes();
    if b.len() != 10 || b[4] != b'-' || b[7] != b'-' {
        return None;
    }
    let digits = |s: &str| s.bytes().all(|c| c.is_ascii_digit()).then(|| s.parse::<u32>().ok()).flatten();
    let (year, month, day) = (digits(&text[0..4])?, digits(&text[5..7])?, digits(&text[8..10])?);
    let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    let days_in_month = match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if leap => 29,
        2 => 28,
        _ => return None,
    };
    if day == 0 || day > days_in_month {
        return None;
    }
    Some(days_from_civil(year as i64, month, day))
}

/// The UTC date of a Unix time as YYYY/MM/DD.
pub fn utc_path(epoch: i64) -> String {
    let (y, m, d) = civil_from_days(epoch.div_euclid(86_400));
    format!("{:04}/{:02}/{:02}", y, m, d)
}

/// Today's day number in the local time zone, from `date`; the UTC date when
/// `date` cannot be run.
pub fn today() -> i64 {
    if let Ok(out) = Command::new("date").arg("+%Y-%m-%d").output() {
        if let Some(day) = parse(String::from_utf8_lossy(&out.stdout).trim()) {
            return day;
        }
    }
    let secs = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0);
    secs.div_euclid(86_400)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn day_numbers_round_trip() {
        assert_eq!(days_from_civil(1970, 1, 1), 0);
        assert_eq!(parse("2026-08-07"), Some(1_786_060_800 / 86_400));
        for days in [-1000, 0, 59, 60, 11_016, 20_675, 60_000] {
            let (y, m, d) = civil_from_days(days);
            assert_eq!(days_from_civil(y, m, d), days);
        }
    }

    #[test]
    fn only_real_strict_dates_parse() {
        assert!(parse("2024-02-29").is_some());
        assert!(parse("2026-02-29").is_none());
        assert!(parse("2026-13-01").is_none());
        assert!(parse("2026-1-01").is_none());
        assert!(parse("last week").is_none());
    }

    #[test]
    fn utc_paths() {
        assert_eq!(utc_path(1_792_022_399), "2026/10/14");
        assert_eq!(utc_path(1_792_022_400), "2026/10/15");
    }
}
