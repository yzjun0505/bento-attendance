import puppeteer from 'puppeteer';

(async () => {
  const browser = await puppeteer.launch({ headless: "new" });
  const page = await browser.newPage();

  page.on('console', msg => {
    console.log(`[CONSOLE] ${msg.type()}:`, msg.text());
  });
  
  page.on('pageerror', err => {
    console.log('[PAGE ERROR]', err.toString());
  });

  console.log('Navigating to http://localhost:5176/ ...');
  try {
    await page.goto('http://localhost:5176/', { waitUntil: 'load', timeout: 10000 });
  } catch(e) {
    console.log("Navigation timeout or error", e.message);
  }
  
  await new Promise(r => setTimeout(r, 5000));
  await browser.close();
})();
