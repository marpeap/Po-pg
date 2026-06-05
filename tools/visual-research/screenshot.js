#!/usr/bin/env node
/**
 * Visual research tool — captures screenshots of URLs for game design reference.
 * Usage: node screenshot.js <url> <output_filename> [selector_to_wait_for]
 * Usage: node screenshot.js --fullpage <url> <output_filename>
 * Output: tools/visual-research/captures/<filename>.png
 */
const { chromium } = require('/home/marpeap/.npm-global/lib/node_modules/@playwright/cli/node_modules/playwright');
const path = require('path');
const fs = require('fs');

const args = process.argv.slice(2);
const fullPage = args[0] === '--fullpage';
if (fullPage) args.shift();

const [url, outName, waitSelector] = args;
if (!url || !outName) {
    console.error('Usage: node screenshot.js [--fullpage] <url> <output_name> [wait_selector]');
    process.exit(1);
}

const outDir = path.join(__dirname, 'captures');
fs.mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, outName.endsWith('.png') ? outName : outName + '.png');

(async () => {
    const browser = await chromium.launch({
        headless: true,
        executablePath: '/home/marpeap/.cache/ms-playwright/chromium-1217/chrome-linux64/chrome'
    });
    const ctx = await browser.newContext({
        viewport: { width: 1280, height: 800 },
        userAgent: 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120 Safari/537.36'
    });
    const page = await ctx.newPage();
    try {
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
        if (waitSelector) {
            await page.waitForSelector(waitSelector, { timeout: 8000 }).catch(() => {});
        }
        await page.waitForTimeout(2000);
        await page.screenshot({ path: outPath, fullPage });
        console.log('SAVED:' + outPath);
    } catch (e) {
        console.error('ERROR:' + e.message);
        process.exit(1);
    } finally {
        await browser.close();
    }
})();
