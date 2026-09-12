package com.example.quote_app.schedule;

import java.util.Calendar;
import java.util.TimeZone;

/** Calendar-day recurrence preserves local wall time across DST, unlike +24h. */
public final class ReminderCalendar {
    public static long next(long now, int hour, int minute, int weekday, TimeZone zone) {
        if (hour < 0 || hour > 23 || minute < 0 || minute > 59 || weekday < 0 || weekday > 7)
            throw new IllegalArgumentException("Invalid reminder time");
        Calendar next = Calendar.getInstance(zone);
        next.setTimeInMillis(now);
        next.set(Calendar.HOUR_OF_DAY, hour);
        next.set(Calendar.MINUTE, minute);
        next.set(Calendar.SECOND, 0);
        next.set(Calendar.MILLISECOND, 0);
        int day = weekday == 7 ? Calendar.SUNDAY : weekday + 1;
        while (next.getTimeInMillis() <= now || (weekday != 0 && next.get(Calendar.DAY_OF_WEEK) != day))
            next.add(Calendar.DAY_OF_YEAR, 1);
        return next.getTimeInMillis();
    }
}
