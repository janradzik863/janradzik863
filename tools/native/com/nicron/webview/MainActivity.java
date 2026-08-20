package com.nicron.webview;

import android.app.Activity;
import android.os.Bundle;
import android.view.ViewGroup;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.webkit.JavascriptInterface;
import android.net.Uri;
import android.graphics.Color;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Iterator;

public class MainActivity extends Activity {
    private WebView web;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        web = new WebView(this);
        web.setBackgroundColor(Color.parseColor("#0E0E12"));
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setDatabaseEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(true);
        s.setAllowFileAccessFromFileURLs(true);
        s.setAllowUniversalAccessFromFileURLs(true);
        s.setJavaScriptCanOpenWindowsAutomatically(true);
        s.setMediaPlaybackRequiresUserGesture(false);
        s.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        s.setCacheMode(WebSettings.LOAD_DEFAULT);
        s.setUserAgentString(s.getUserAgentString() + " CzarneWilki/0.5");
        web.setWebChromeClient(new WebChromeClient());
        web.setWebViewClient(new WebViewClient() {
            @Override
            public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest req) {
                try {
                    Uri uri = req.getUrl();
                    String host = uri.getHost() == null ? "" : uri.getHost();
                    if ("appassets.androidplatform.net".equals(host)) {
                        String path = uri.getPath();
                        if (path == null || path.equals("/") || path.isEmpty()) path = "/index.html";
                        if (path.startsWith("/")) path = path.substring(1);
                        InputStream in = getAssets().open("www/" + path);
                        return new WebResourceResponse(mime(path), "utf-8", in);
                    }
                } catch (Exception ignored) {
                    return new WebResourceResponse(
                        "text/plain", "utf-8",
                        new ByteArrayInputStream("missing".getBytes(StandardCharsets.UTF_8))
                    );
                }
                return super.shouldInterceptRequest(view, req);
            }
        });
        web.addJavascriptInterface(new Bridge(), "CwNative");
        setContentView(web, new ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ));
        web.loadUrl("https://appassets.androidplatform.net/index.html");
    }

    @Override
    public void onBackPressed() {
        if (web != null && web.canGoBack()) web.goBack();
        else super.onBackPressed();
    }

    private static String mime(String path) {
        String p = path.toLowerCase();
        if (p.endsWith(".html")) return "text/html";
        if (p.endsWith(".js")) return "application/javascript";
        if (p.endsWith(".css")) return "text/css";
        if (p.endsWith(".png")) return "image/png";
        if (p.endsWith(".jpg") || p.endsWith(".jpeg")) return "image/jpeg";
        if (p.endsWith(".json")) return "application/json";
        if (p.endsWith(".svg")) return "image/svg+xml";
        if (p.endsWith(".webp")) return "image/webp";
        return "application/octet-stream";
    }

    public static class Bridge {
        @JavascriptInterface
        public String ping() {
            return "ok";
        }

        @JavascriptInterface
        public String http(String method, String url, String headersJson, String body) {
            HttpURLConnection c = null;
            try {
                c = (HttpURLConnection) new URL(url).openConnection();
                c.setInstanceFollowRedirects(true);
                c.setConnectTimeout(20000);
                c.setReadTimeout(180000);
                c.setRequestMethod(method == null ? "GET" : method.toUpperCase());
                c.setRequestProperty("Accept", "application/json, text/plain, */*");
                if (headersJson != null && headersJson.length() > 2) {
                    JSONObject h = new JSONObject(headersJson);
                    Iterator<String> keys = h.keys();
                    while (keys.hasNext()) {
                        String k = keys.next();
                        c.setRequestProperty(k, h.optString(k, ""));
                    }
                }
                if (body != null && body.length() > 0
                    && !"GET".equalsIgnoreCase(method)
                    && !"HEAD".equalsIgnoreCase(method)) {
                    byte[] data = body.getBytes(StandardCharsets.UTF_8);
                    c.setDoOutput(true);
                    if (c.getRequestProperty("Content-Type") == null) {
                        c.setRequestProperty("Content-Type", "application/json; charset=utf-8");
                    }
                    c.setFixedLengthStreamingMode(data.length);
                    OutputStream os = c.getOutputStream();
                    os.write(data);
                    os.close();
                }
                int code = c.getResponseCode();
                InputStream in = code >= 400 ? c.getErrorStream() : c.getInputStream();
                String resp = readAll(in);
                JSONObject out = new JSONObject();
                out.put("code", code);
                out.put("body", resp);
                return out.toString();
            } catch (Exception e) {
                try {
                    JSONObject out = new JSONObject();
                    out.put("code", 0);
                    out.put("error", String.valueOf(e.getMessage()));
                    return out.toString();
                } catch (Exception e2) {
                    return "{\"code\":0,\"error\":\"native-http-failed\"}";
                }
            } finally {
                if (c != null) c.disconnect();
            }
        }

        private static String readAll(InputStream in) throws Exception {
            if (in == null) return "";
            BufferedReader br = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line).append('\n');
            }
            br.close();
            return sb.toString();
        }
    }
}
