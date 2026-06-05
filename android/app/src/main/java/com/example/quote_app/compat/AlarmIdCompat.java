
package com.example.quote_app.compat;

import java.nio.charset.StandardCharsets;
import java.util.zip.CRC32;

public final class AlarmIdCompat {
    private AlarmIdCompat() {}
    public static int alarmId(String uid, long triggerAtMillis) {
        String s = uid + "@" + triggerAtMillis;
        byte[] bytes = s.getBytes(StandardCharsets.UTF_8);
        CRC32 c = new CRC32();
        c.update(bytes, 0, bytes.length);
        long v = c.getValue() ^ 0xFFFFFFFFL;
        return (int)(v & 0x7FFFFFFFL);
    }
}
