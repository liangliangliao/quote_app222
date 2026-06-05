
package com.example.quote_app.biz;

import java.util.*;

public final class DedupeUtil {
    private DedupeUtil() {}

    public static String normalize(String s) {
        if (s == null) return null;
        String t = s.toLowerCase(Locale.US);
        t = t.replaceAll("[\\p{Punct}\\p{Cntrl}]+", " ");
        t = t.replaceAll("\\s+", " ").trim();
        return t;
    }

    public static boolean equalsLoose(String a, String b) {
        String x = normalize(a), y = normalize(b);
        if (x == null || y == null) return false;
        return x.equals(y);
    }

    public static double jaccardTrigram(String a, String b) {
        Set<String> A = trigrams(normalize(a));
        Set<String> B = trigrams(normalize(b));
        if (A.isEmpty() && B.isEmpty()) return 1.0;
        Set<String> inter = new HashSet<>(A); inter.retainAll(B);
        Set<String> union = new HashSet<>(A); union.addAll(B);
        return union.isEmpty() ? 0.0 : (1.0 * inter.size() / union.size());
    }

    private static Set<String> trigrams(String s) {
        Set<String> out = new HashSet<>();
        if (s == null) return out;
        String t = "  " + s + "  ";
        for (int i=0;i+2<t.length();i++) out.add(t.substring(i, i+3));
        return out;
    }

    /** return true if candidate duplicates any of existing with similarity >= threshold */
    public static boolean isDuplicate(List<String> existing, String candidate, double threshold) {
        if (candidate == null) return false;
        for (String e : existing) {
            if (equalsLoose(e, candidate)) return true;
            double sim = jaccardTrigram(e, candidate);
            if (sim >= threshold) return true;
        }
        return false;
    }
}
