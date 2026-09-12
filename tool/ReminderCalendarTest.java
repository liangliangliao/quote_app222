import com.example.quote_app.schedule.ReminderCalendar;
import java.time.*;
import java.util.TimeZone;

public class ReminderCalendarTest {
    static void check(String now, int h, int m, int day, String zone, String expected) {
        long at = ReminderCalendar.next(Instant.parse(now).toEpochMilli(), h, m, day, TimeZone.getTimeZone(zone));
        if (!Instant.ofEpochMilli(at).equals(Instant.parse(expected))) throw new AssertionError(now + " -> " + Instant.ofEpochMilli(at));
    }
    public static void main(String[] args) {
        check("2026-09-11T07:59:30Z",8,0,0,"UTC","2026-09-11T08:00:00Z");
        check("2026-09-11T08:00:00Z",8,0,0,"UTC","2026-09-12T08:00:00Z");
        check("2026-09-11T22:00:00Z",21,0,7,"UTC","2026-09-13T21:00:00Z");
        check("2026-09-13T21:00:00Z",21,0,7,"UTC","2026-09-20T21:00:00Z");
        check("2026-03-07T13:00:00Z",8,0,0,"America/New_York","2026-03-08T12:00:00Z");
        check("2026-10-31T12:00:00Z",8,0,0,"America/New_York","2026-11-01T13:00:00Z");
        System.out.println("6 native recurrence checks passed");
    }
}
