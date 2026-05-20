// ==UserScript==
// @name         TikTok Live → Roblox Spawn Queue
// @namespace    live_roblox
// @version      1.0
// @description  Forwards TikTok live chat to your local Roblox queue (no Euler API needed)
// @match        https://www.tiktok.com/*
// @grant        GM_xmlhttpRequest
// @connect      localhost
// ==/UserScript==

(function () {
    'use strict';

    const QUEUE_URL = 'http://localhost:3000/api/queue/add';
    const seen = new Map(); // text -> timestamp
    const DEDUP_MS = 30000;

    function sendToQueue(message) {
        const key = message.trim().toLowerCase();
        if (!key || key.length < 3) return;

        const now = Date.now();
        if (seen.has(key) && now - seen.get(key) < DEDUP_MS) return;
        seen.set(key, now);

        GM_xmlhttpRequest({
            method: 'POST',
            url: QUEUE_URL,
            headers: { 'Content-Type': 'application/json' },
            data: JSON.stringify({ message: message.trim() }),
            onload(res) {
                if (res.status === 200) {
                    console.log('[Roblox Queue]', res.responseText);
                    ping('✓ ' + message.trim().slice(0, 40));
                } else {
                    console.warn('[Roblox Queue] failed', res.status, res.responseText);
                }
            },
            onerror() {
                console.warn('[Roblox Queue] Is node server.js running on port 3000?');
            },
        });
    }

    function ping(text) {
        let el = document.getElementById('roblox-queue-ping');
        if (!el) {
            el = document.createElement('div');
            el.id = 'roblox-queue-ping';
            el.style.cssText = 'position:fixed;bottom:12px;right:12px;z-index:99999;background:#0af;color:#000;padding:8px 12px;border-radius:8px;font:bold 13px system-ui;max-width:280px;pointer-events:none';
            document.body.appendChild(el);
        }
        el.textContent = text;
        clearTimeout(el._t);
        el._t = setTimeout(() => el.remove(), 2500);
    }

    function extractChatText(node) {
        if (!node || node.nodeType !== 1) return '';
        const text = (node.innerText || node.textContent || '').trim();
        if (!text || text.length > 120) return '';
        // Skip UI chrome / timestamps-only lines
        if (/^(LIVE|Follow|Share|\d+:\d+)/i.test(text) && text.length < 20) return '';
        return text;
    }

    function scanMessage(node) {
        const text = extractChatText(node);
        if (text) sendToQueue(text);
    }

    function hookChat() {
        const selectors = [
            '[data-e2e="chat-message"]',
            '[class*="ChatMessage"]',
            '[class*="chat-message"]',
            '[class*="webcast-chatroom"] [class*="item"]',
        ];

        const observer = new MutationObserver(mutations => {
            for (const m of mutations) {
                for (const node of m.addedNodes) {
                    if (node.nodeType !== 1) continue;
                    for (const sel of selectors) {
                        if (node.matches?.(sel)) scanMessage(node);
                        node.querySelectorAll?.(sel).forEach(scanMessage);
                    }
                    // Fallback: small new text blocks in chat area
                    if (node.innerText && node.innerText.length < 80 && node.innerText.length > 2) {
                        const parent = node.closest('[class*="chat"], [class*="Chat"]');
                        if (parent) scanMessage(node);
                    }
                }
            }
        });

        observer.observe(document.body, { childList: true, subtree: true });
        ping('Roblox queue bridge ON');
        console.log('[Roblox Queue] Bridge active →', QUEUE_URL);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', hookChat);
    } else {
        hookChat();
    }
})();
