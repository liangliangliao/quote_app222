
package com.example.quote_app.biz;

import android.util.Base64;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

/** Minimal OpenAI client using HttpURLConnection (no extra deps). */
public final class OpenAiClient {
    private OpenAiClient() {}

        public static String chatComplete(String baseUrl, String apiKey, String model, String prompt) {
        HttpURLConnection conn = null;
        try {
            String endpoint = baseUrl.endsWith("/") ? (baseUrl + "chat/completions") : (baseUrl + "/chat/completions");
            URL url = new URL(endpoint);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("POST");
            conn.setConnectTimeout(15000);
            conn.setReadTimeout(30000);
            conn.setDoOutput(true);
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8");
            if (apiKey != null && !apiKey.isEmpty()) {
                conn.setRequestProperty("Authorization", "Bearer " + apiKey);
            }
            JSONObject body = new JSONObject();
            body.put("model", (model != null && !model.isEmpty()) ? model : "gpt-5");
            JSONArray messages = new JSONArray();
            JSONObject user = new JSONObject();
            user.put("role", "user");
            user.put("content", prompt);
            messages.put(user);
            body.put("messages", messages);

            byte[] out = body.toString().getBytes(StandardCharsets.UTF_8);
            conn.setFixedLengthStreamingMode(out.length);
            try (DataOutputStream os = new DataOutputStream(conn.getOutputStream())) {
                os.write(out);
                os.flush();
            }

            int code = conn.getResponseCode();
            if (code / 100 != 2) {
                StringBuilder esb = new StringBuilder();
                try (BufferedReader er = new BufferedReader(new InputStreamReader(conn.getErrorStream(), StandardCharsets.UTF_8))) {
                    String line;
                    while (er != null && (line = er.readLine()) != null) esb.append(line);
                } catch (Exception ignored) {}
                throw new RuntimeException("HTTP " + code + (esb.length()>0 ? (": " + esb) : ""));
            }

            StringBuilder sb = new StringBuilder();
            try (BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = br.readLine()) != null) sb.append(line);
            }

            JSONObject resp = new JSONObject(sb.toString());
            JSONArray choices = resp.optJSONArray("choices");
            if (choices != null && choices.length() > 0) {
                JSONObject first = choices.optJSONObject(0);
                if (first != null) {
                    JSONObject msg = first.optJSONObject("message");
                    if (msg != null) return msg.optString("content", null);
                }
            }
            return null;
        } catch (Exception e) {
            throw new RuntimeException(e);
        } finally {
            if (conn != null) try { conn.disconnect(); } catch (Throwable ignored) {}
        }
}

}
